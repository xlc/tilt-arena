// ArenaScene keeps SpriteKit lifecycle orchestration while enemy ownership, weapon planning,
// and reusable UI rendering live in focused collaborators.
// swiftlint:disable file_length
import QuartzCore
import SpriteKit
import UIKit

@MainActor
protocol ArenaSceneOrientationDelegate: AnyObject {
    func arenaSceneRequestsRunOrientationLock(
        _ scene: ArenaScene,
        preferredOrientation: TiltScreenOrientation
    ) -> TiltScreenOrientation
    func arenaSceneRequestsOrientationUnlock(_ scene: ArenaScene)
}

@MainActor
protocol ArenaSceneDiagnosticsDelegate: AnyObject {
    func arenaSceneRequestsDiagnosticsPresentation(
        _ scene: ArenaScene,
        snapshot: DiagnosticGameplaySnapshot
    )
}

@MainActor
protocol ArenaSceneGameCenterDelegate: AnyObject {
    func arenaSceneGameCenterMenuStatus(_ scene: ArenaScene) -> GameCenterMenuStatus
    func arenaSceneRequestsClassicLeaderboard(_ scene: ArenaScene) -> GameCenterLeaderboardPresentationResult
}

final class ArenaScene: SKScene {
    weak var orientationDelegate: ArenaSceneOrientationDelegate?
    weak var diagnosticsDelegate: ArenaSceneDiagnosticsDelegate?
    weak var gameCenterDelegate: ArenaSceneGameCenterDelegate?
    var theme: ArenaTheme {
        localOptions.themeKind.theme
    }
    private let tiltSettingsStore: TiltSettingsStore
    private let runProfileStore: RunProfileStore
    private let localOptionsStore: ArenaLocalOptionsStore
    private let gameTuningStore: GameTuningStore
    private let gameCenterReporter: any GameCenterRunReporting
    private let appLogger = AppDiagnostics.logger(.app)
    private let sceneLogger = AppDiagnostics.logger(.scene)
    private let inputLogger = AppDiagnostics.logger(.input)
    private let runLogger = AppDiagnostics.logger(.run)
    private let spawnLogger = AppDiagnostics.logger(.spawn)
    private let weaponLogger = AppDiagnostics.logger(.weapon)
    private let profileLogger = AppDiagnostics.logger(.profile)
    private let performanceLogger = AppDiagnostics.logger(.performance)
    private let hapticsController = ArenaHapticsController()
    private let audioController = ArenaAudioController()
    private var arenaRoot = SKNode()
    private let gameplayRoot = SKCropNode()
    private let gameplayOverlayRoot = SKNode()
    private let weaponEffectsRoot = SKNode()
    private let uiRenderer = ArenaUIRenderer()
    private var uiRoot: SKNode {
        uiRenderer.root
    }
    private var runScoreLabel: SKLabelNode?
    private var runBestLabel: SKLabelNode?
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    private let keyboardInputController = KeyboardInputController()
    private var gameTuning = GameTuningConfiguration.defaults
    var movementController = PlayerMovementController()
    private var runController = ClassicRunController()
    private var runProfile = RunProfile()
    private var localOptions = ArenaLocalOptions()
    private var navigationState = ArenaNavigationState()
    private var uiState: ArenaUISceneState {
        navigationState.current
    }
    private var runSession = ArenaRunSessionState()
    private var readyHoldController = ReadyStartHoldController()
    private var readyStartPoint = CGPoint.zero
    private var readyProgressRing: SKShapeNode?
    private var readyStatusLabel: SKLabelNode?
    private var spawnDirector = EnemySpawnDirector()
    private var pickupSpawnConfiguration = PickupSpawnConfiguration()
    private var pickupPlanner = PickupSpawnPlanner()
    private let weaponRuntime = ArenaWeaponRuntime()
    var weaponResolver: StartingWeaponResolver {
        weaponRuntime.resolver
    }
    var weaponEffectTiming: WeaponEffectTiming {
        weaponRuntime.effectTiming
    }
    private let enemyRegistry = ArenaEnemyRegistry()
    private var enemies: [ArenaEnemy] {
        enemyRegistry.enemies
    }
    private let pickupRegistry = ArenaPickupRegistry()
    private var pickups: [WeaponPickup] {
        pickupRegistry.pickups
    }
    private var playerNode: PlayerCraftNode?
    private var playerTrailNode: PlayerTrailNode?
    private var activeWeapons = ArenaActiveWeaponState()
    private var razorShieldNode: SKShapeNode?
    private lazy var flameTrailEffectNode = FlameTrailEffectNode(theme: theme)
    var gravityWellEffectNode: SKNode?
    private var timeDilationAuraNode: SKNode?
    var powerWaveChargeNode: SKNode?
#if DEBUG
    var inputOverrideForTesting: CGVector?
    private let debugStatsLabel = SKLabelNode(fontNamed: "Menlo")
    private var debugStatsElapsed: TimeInterval = 0
    private var debugStatsFrameCount = 0
#endif
    private var diagnosticAccumulator = ArenaDiagnosticAccumulator()
    private var balanceAccumulator = ArenaBalanceAccumulator()
    private var balanceStartingUnlockCount = 0
    private var balanceExperimentalTuning = false
    private let uiMargin: CGFloat = 24
    private var calibrationPreviewMovementController = PlayerMovementController()
    private var calibrationPreviewPlayerNode: PlayerCraftNode?
    private var calibrationPreviewTrailNode: PlayerTrailNode?
    private var tiltReadoutValueLabels: [SKLabelNode] = []
    private var tiltReadoutUpdateTime: TimeInterval = 0
    private var runTiltScreenOrientation: TiltScreenOrientation?
    private var lastKnownTiltScreenOrientation: TiltScreenOrientation = .landscapeLeft
    private var lastUpdateTime: TimeInterval?

    override init(size: CGSize) {
        tiltSettingsStore = TiltSettingsStore()
        runProfileStore = RunProfileStore()
        localOptionsStore = ArenaLocalOptionsStore()
        gameTuningStore = GameTuningStore()
        gameCenterReporter = NoopGameCenterClient()
        super.init(size: size)
        configureSceneDefaults()
    }

    init(
        size: CGSize,
        tiltSettingsStore: TiltSettingsStore = TiltSettingsStore(),
        runProfileStore: RunProfileStore = RunProfileStore(),
        localOptionsStore: ArenaLocalOptionsStore = ArenaLocalOptionsStore(),
        gameTuningStore: GameTuningStore = GameTuningStore(),
        gameCenterReporter: any GameCenterRunReporting = NoopGameCenterClient()
    ) {
        self.tiltSettingsStore = tiltSettingsStore
        self.runProfileStore = runProfileStore
        self.localOptionsStore = localOptionsStore
        self.gameTuningStore = gameTuningStore
        self.gameCenterReporter = gameCenterReporter
        super.init(size: size)
        configureSceneDefaults()
    }

    private func configureSceneDefaults() {
        #if DEBUG
        gameTuning = gameTuningStore.tuning
        #endif
        applyGameTuning()
        anchorPoint = .zero
        backgroundColor = theme.backgroundColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ArenaScene does not support storyboard initialization.")
    }

    override func didMove(to view: SKView) {
        runProfile = runProfileStore.profile
        localOptions = localOptionsStore.options
        syncAudioOption()
        syncHapticsOption()
        backgroundColor = theme.backgroundColor
        rebuildArena()
        configureWeaponEffectsRoot()
        if flameTrailEffectNode.parent == nil { addGameplayNode(flameTrailEffectNode) }
        configureUIRoot()
        configureDebugStats()
        placePlayer(resetPosition: true)
        rebuildUI()
        tiltInputController.start()
        sceneLogger.notice("scene.presented", metadata: [
            "width": "\(size.width.rounded())",
            "height": "\(size.height.rounded())"
        ])
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
        let shouldResetPosition = playerNode == nil || uiState == .home
        placePlayer(resetPosition: shouldResetPosition, resetTrail: shouldResetPosition)
        if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }
        layoutDebugStats()
        rebuildUI()
        sceneLogger.debug("scene.resized", metadata: [
            "width": "\(size.width.rounded())",
            "height": "\(size.height.rounded())"
        ])
    }

    override func willMove(from view: SKView) {
        orientationDelegate?.arenaSceneRequestsOrientationUnlock(self)
        audioController.stopMusic()
        tiltInputController.stop()
        lastUpdateTime = nil
        sceneLogger.notice("scene.removed")
    }

    override func update(_ currentTime: TimeInterval) {
        guard currentTime.isFinite else {
            reportInvalidFrameTime(reason: "nonfinite_current_time")
            lastUpdateTime = nil
            return
        }

        guard let lastUpdateTime, lastUpdateTime.isFinite else {
            self.lastUpdateTime = currentTime
            return
        }

        self.lastUpdateTime = currentTime
        let elapsedTime = currentTime - lastUpdateTime
        guard elapsedTime.isFinite else {
            reportInvalidFrameTime(reason: "nonfinite_elapsed_time")
            return
        }

        let positiveElapsedTime = max(0, elapsedTime)
        if diagnosticAccumulator.consumeFrameTimeRecovery() {
            performanceLogger.info("performance.frame_time_recovered")
        }
        updateDiagnosticHealth(elapsedTime: positiveElapsedTime)
        updatePostRunTransition(deltaTime: positiveElapsedTime)

        let deltaTime = min(1.0 / 15.0, positiveElapsedTime)
        guard deltaTime > 0 else {
            return
        }

        updateDebugStats(deltaTime: deltaTime)

        switch uiState {
        case .calibrationPreview:
            updateCalibrationPreview(deltaTime: deltaTime)
        case .preRun:
            updatePreRun(deltaTime: deltaTime)
        case .activeGameplay:
            updateGameplay(deltaTime: deltaTime)
        case .options:
            updateTiltReadoutDisplay(deltaTime: deltaTime)
        case .home, .modeSelect, .awards, .weaponCodex, .developerTuning, .pause, .postRun:
            break
        }
    }

    func recalibrateTiltControls() {
        tiltInputController.recalibrateToCurrentAttitude(orientation: currentTiltScreenOrientation)
        inputLogger.notice("input.calibrated", metadata: [
            "orientation": "\(currentTiltScreenOrientation.rawValue)"
        ])
        if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }
        rebuildUI()
    }

    func refreshSafeAreaLayout() {
        rebuildArena()
        let shouldResetPosition = playerNode == nil || uiState == .home
        placePlayer(resetPosition: shouldResetPosition, resetTrail: shouldResetPosition)
        if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }
        layoutDebugStats()
        rebuildUI()
    }

    func refreshGameCenterMenuStatus() {
        guard uiState == .home || uiState == .postRun else {
            return
        }

        rebuildUI()
    }

    func pauseActiveRunIfNeeded() {
        if uiState == .preRun {
            readyHoldController.reset()
            show(.home)
        } else {
            pauseRun()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else {
            return
        }

        if uiState == .activeGameplay {
            pauseRun()
            return
        }

        for touch in touches {
            let location = touch.location(in: self)
            if let target = uiRenderer.hitTargets.reversed().first(where: { $0.frame.contains(location) }) {
                perform(target.action)
                return
            }
        }
    }

}

// MARK: - Gameplay orchestration

extension ArenaScene {
    private func rebuildArena() {
        arenaRoot.removeFromParent()
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(
            size: ArenaGeometry.logicalGameplayBounds.size,
            arenaRect: currentGameplayBounds
        )
        addGameplayNode(arenaRoot)
    }

    func addGameplayNode(_ node: SKNode) {
        configureGameplayTransform()
        gameplayRoot.addChild(node)
    }

    private func configureGameplayTransform() {
        let layout = currentLandscapeLayout()
        if gameplayRoot.parent == nil { addChild(gameplayRoot) }
        if gameplayRoot.maskNode == nil {
            let mask = SKShapeNode(rect: currentGameplayBounds)
            mask.fillColor = .white
            mask.strokeColor = .clear
            gameplayRoot.maskNode = mask
        }
        for root in [gameplayRoot as SKNode, gameplayOverlayRoot] {
            root.position = layout.gameplayWorldFrame.origin
            root.setScale(layout.gameplayWorldScale)
        }
    }

    private func addGameplayOverlayNode(_ node: SKNode) {
        configureGameplayTransform()
        if gameplayOverlayRoot.parent == nil { uiRoot.addChild(gameplayOverlayRoot) }
        gameplayOverlayRoot.addChild(node)
    }

    private func configureUIRoot() {
        guard uiRoot.parent == nil else {
            return
        }

        uiRoot.zPosition = 70
        addChild(uiRoot)
    }

    private func configureWeaponEffectsRoot() {
        guard weaponEffectsRoot.parent == nil else {
            return
        }

        weaponEffectsRoot.zPosition = 0
        weaponEffectsRoot.isPaused = false
        addGameplayNode(weaponEffectsRoot)
    }

    func addWeaponEffectNode(_ node: SKNode) {
        configureWeaponEffectsRoot()
        weaponEffectsRoot.addChild(node)
    }

    private func setWeaponEffectPlaybackPaused(_ isPaused: Bool) {
        configureWeaponEffectsRoot()
        weaponEffectsRoot.isPaused = isPaused
    }

    private func clearWeaponEffectNodes(paused: Bool = false) {
        configureWeaponEffectsRoot()
        weaponEffectsRoot.removeAllActions()
        weaponEffectsRoot.removeAllChildren()
        weaponEffectsRoot.isPaused = paused
    }

    private func placePlayer(resetPosition: Bool, resetTrail: Bool = true) {
        ensurePlayerNodes()

        let state = resetPosition
            ? movementController.reset(in: currentGameplayBounds)
            : movementController.clampToArena(currentGameplayBounds)

        applyPlayerState(state, resetTrail: resetTrail)
    }

    private func ensurePlayerNodes() {
        if playerTrailNode == nil {
            let trailNode = PlayerTrailNode(theme: theme)
            addGameplayNode(trailNode)
            playerTrailNode = trailNode
        }

        if playerNode == nil {
            let craftNode = PlayerCraftNode(
                theme: theme,
                visualRadius: movementController.configuration.visualRadius
            )
            addGameplayNode(craftNode)
            playerNode = craftNode
        }
    }

    private func applyPlayerState(_ state: PlayerMovementState, resetTrail: Bool) {
        let speedFraction = state.velocity.length / max(
            1,
            movementController.configuration.maximumSpeed(in: currentGameplayBounds)
        )
        playerNode?.apply(state: state, speedFraction: speedFraction)

        if resetTrail {
            playerTrailNode?.reset(to: state.position)
        } else {
            playerTrailNode?.record(position: state.position, speedFraction: speedFraction)
        }
    }

    private func configureDebugStats() {
        #if DEBUG
        debugStatsLabel.fontSize = 12
        debugStatsLabel.fontColor = theme.borderColor
        debugStatsLabel.zPosition = 95
        debugStatsLabel.horizontalAlignmentMode = .left
        debugStatsLabel.verticalAlignmentMode = .bottom
        debugStatsLabel.text = "0 fps"

        if debugStatsLabel.parent == nil {
            addChild(debugStatsLabel)
        }

        layoutDebugStats()
        #endif
    }

    private func layoutDebugStats() {
        #if DEBUG
        let controls = currentLandscapeLayout().controlRect
        debugStatsLabel.position = CGPoint(x: controls.minX, y: controls.minY)
        #endif
    }

    private func updateDebugStats(deltaTime: TimeInterval) {
        #if DEBUG
        debugStatsElapsed += deltaTime
        debugStatsFrameCount += 1

        guard debugStatsElapsed >= 0.25 else {
            return
        }

        let framesPerSecond = Double(debugStatsFrameCount) / debugStatsElapsed
        let nodeCount = debugNodeCount(in: self)
        debugStatsLabel.text = "nodes:\(nodeCount)  \(framesPerSecond.rounded()) fps"
        debugStatsElapsed = 0
        debugStatsFrameCount = 0
        #endif
    }

    private func updateDiagnosticHealth(elapsedTime: TimeInterval) {
        guard let heartbeat = diagnosticAccumulator.recordFrame(duration: elapsedTime) else {
            return
        }

        performanceLogger.info("performance.heartbeat", metadata: [
            "enemies": "\(enemies.count)",
            "fps": "\(heartbeat.framesPerSecond.rounded())",
            "freezeWaves": "\(activeWeapons.freezeBurstWaves.count)",
            "longFrames": "\(heartbeat.longFrameCount)",
            "maxFrameMs": "\((heartbeat.maximumFrameInterval * 1_000).rounded())",
            "pendingNova": "\(activeWeapons.pendingNovaBombClears.count)",
            "pickups": "\(pickups.count)",
            "shockwaves": "\(activeWeapons.shockwaveWaves.count)",
            "spawnCorrections": "\(heartbeat.spawnRuntimeCorrectionCount)",
            "spawnedEnemies": "\(heartbeat.spawnedEnemyCount)",
            "state": "\(uiState.diagnosticName)",
            "thermal": "\(ProcessInfo.processInfo.thermalState.diagnosticName)",
            "weaponEffects": "\(weaponEffectsRoot.children.count)"
        ])
        if heartbeat.spawnRuntimeCorrectionCount > 0 {
            spawnLogger.warning("spawn.runtime_values_corrected", metadata: [
                "corrections": "\(heartbeat.spawnRuntimeCorrectionCount)",
                "survivalTime": "\(runController.survivalTime)"
            ])
        }
    }

    private func reportInvalidFrameTime(reason: String) {
        guard diagnosticAccumulator.markInvalidFrameTimeReported() else {
            return
        }
        performanceLogger.warning("performance.frame_time_invalid", metadata: [
            "reason": "\(reason)",
            "state": "\(uiState.diagnosticName)"
        ])
    }

    #if DEBUG
    private func debugNodeCount(in node: SKNode) -> Int {
        node.children.reduce(1) { count, child in
            count + debugNodeCount(in: child)
        }
    }
    #endif

    private func currentLandscapeLayout() -> ArenaLandscapeUILayout {
        ArenaLandscapeUILayout(
            sceneSize: size,
            safeAreaInsets: view?.safeAreaInsets ?? .zero,
            margin: uiMargin
        )
    }

    var currentGameplayBounds: CGRect {
        ArenaGeometry.logicalGameplayBounds
    }

    var currentPlayableRect: CGRect {
        movementController.configuration.playableRect(in: currentGameplayBounds)
    }

    private var currentTiltScreenOrientation: TiltScreenOrientation {
        if let runTiltScreenOrientation {
            return runTiltScreenOrientation
        }

        if let windowOrientation = currentWindowTiltScreenOrientation {
            lastKnownTiltScreenOrientation = windowOrientation
            return windowOrientation
        }

        return lastKnownTiltScreenOrientation
    }

    private var currentWindowTiltScreenOrientation: TiltScreenOrientation? {
        TiltScreenOrientation(interfaceOrientation: view?.window?.windowScene?.interfaceOrientation)
    }

    private func updatePreRun(deltaTime: TimeInterval) {
        if !readyHoldController.isRetry {
            let input = movementInput(deltaTime: deltaTime)
            let state = movementController.update(input: input, deltaTime: deltaTime, arenaBounds: currentGameplayBounds)
            applyPlayerState(state, resetTrail: false)
        }

        let holdState = readyHoldController.update(
            playerPosition: movementController.state.position,
            startPoint: readyStartPoint,
            deltaTime: deltaTime
        )
        updateReadyProgressDisplay(holdState)

        if holdState.didComplete {
            startRun()
        }
    }

    private func updateGameplay(deltaTime: TimeInterval) {
        guard runController.phase == .active else {
            return
        }

        let previousPlayerPosition = movementController.state.position
        let input = movementInput(deltaTime: deltaTime)
        activeWeapons.aimDirection.record(input: input)
        let state = updatePlayerMovement(input: input, deltaTime: deltaTime)
        applyPlayerState(state, resetTrail: false)
        updateActiveRun(
            deltaTime: deltaTime,
            playerPosition: state.position,
            previousPlayerPosition: previousPlayerPosition
        )
    }

    private func updatePlayerMovement(input: CGVector, deltaTime: TimeInterval) -> PlayerMovementState {
        guard activeWeapons.flameTrailProtection.speedBoostTimeRemaining > 0 else {
            return movementController.update(
                input: input,
                deltaTime: deltaTime,
                arenaBounds: currentGameplayBounds
            )
        }

        return movementController.updateWithFixedSpeed(
            input: input,
            deltaTime: deltaTime,
            arenaBounds: currentGameplayBounds,
            speedMultiplier: activeWeapons.flameTrail.configuration.speedMultiplier
        )
    }

    private func updateCalibrationPreview(deltaTime: TimeInterval) {
        let input = movementInput(deltaTime: deltaTime)
        let previewBounds = currentCalibrationPreviewBounds
        let state = calibrationPreviewMovementController.update(
            input: input,
            deltaTime: deltaTime,
            arenaBounds: previewBounds
        )

        applyCalibrationPreviewState(state, resetTrail: false)
        updateTiltReadoutDisplay(deltaTime: deltaTime)
    }

    private func movementInput(deltaTime: TimeInterval) -> CGVector {
        #if DEBUG
        if let inputOverrideForTesting { return inputOverrideForTesting }
        #endif
        let tiltInput = tiltInputController.update(
            deltaTime: deltaTime,
            orientation: currentTiltScreenOrientation
        )
        let keyboardInput = keyboardInputController.movementInput()

        return keyboardInput.isActive ? keyboardInput.vector : tiltInput
    }

    private func enterCalibrationPreview() {
        navigationState.prepareCalibrationPresentation()
        tiltInputController.resetSmoothedInput()
        resetCalibrationPreviewPosition()
        show(.calibrationPreview)
    }

    private func resetCalibrationPreviewPosition() {
        calibrationPreviewMovementController.configuration = movementController.configuration
        let state = calibrationPreviewMovementController.reset(in: currentCalibrationPreviewBounds)
        applyCalibrationPreviewState(state, resetTrail: true)
    }

    private func applyCalibrationPreviewState(_ state: PlayerMovementState, resetTrail: Bool) {
        let speedFraction = state.velocity.length / max(
            1,
            calibrationPreviewMovementController.configuration.maximumSpeed(in: currentCalibrationPreviewBounds)
        )
        calibrationPreviewPlayerNode?.apply(state: state, speedFraction: speedFraction)

        if resetTrail {
            calibrationPreviewTrailNode?.reset(to: state.position)
        } else {
            calibrationPreviewTrailNode?.record(position: state.position, speedFraction: speedFraction)
        }
    }

    private func preparePreRun(isRetry: Bool = false) {
        runController = ClassicRunController(configuration: runController.configuration)
        runSession.preparePreRun()
        resetGameplayObjects()
        readyHoldController.reset()
        if isRetry {
            readyHoldController.beginRetry()
            tiltInputController.resetSmoothedInput()
        }
        placePlayer(resetPosition: true)
        readyStartPoint = movementController.state.position
        resetPlayerFeedback()
        show(.preRun)
        runLogger.notice("run.prepared", metadata: [
            "mode": "\(runSession.selectedMode.rawValue)"
        ])
    }

    private func startRun(sequenceSeed: Int? = nil) {
        readyHoldController.reset()
        resetActiveRun(sequenceSeed: sequenceSeed)
        runController.start(context: ArenaRunContext(
            mode: runSession.selectedMode,
            sequenceSeed: weaponRuntime.initialSeed
        ))
        audioController.resetEventLimiter()
        audioController.startMusic()
        hapticsController.prepare()
        show(.activeGameplay)
        runLogger.notice("run.started", metadata: [
            "run_id": "\(balanceAccumulator.runID)",
            "mode": "\(runSession.selectedMode.rawValue)",
            "seed": "\(weaponRuntime.initialSeed)"
        ])
    }

    private func pauseRun() {
        guard runController.phase == .active else {
            return
        }

        runController.pause()
        audioController.pauseMusic()
        tiltInputController.resetSmoothedInput()
        setWeaponEffectPlaybackPaused(true)
        show(.pause)
        runLogger.info("run.paused", metadata: [
            "score": "\(runController.score)",
            "survivalTime": "\(runController.survivalTime)"
        ])
    }

    private func resumeRun() {
        tiltInputController.resetSmoothedInput()
        runController.resume()
        setWeaponEffectPlaybackPaused(false)
        audioController.startMusic()
        show(.activeGameplay)
        runLogger.info("run.resumed", metadata: [
            "score": "\(runController.score)",
            "survivalTime": "\(runController.survivalTime)"
        ])
    }

    private func finishRun(playFeedback: Bool = true, collision: DeathCollisionSnapshot? = nil) {
        guard
            !runSession.isResolvingDeath,
            runController.phase == .active || runController.phase == .paused
        else {
            return
        }

        runSession.beginRunCompletion(
            previousBestScore: selectedModeRecord.bestScore,
            collision: collision,
            transitionDuration: playFeedback ? 0.22 : nil
        )
        runController.endRun()
        clearWeaponEffectNodes(paused: true)
        activeWeapons.finishRun()
        updatePlayerCollisionProtection()
        powerWaveChargeNode = nil
        timeDilationAuraNode = nil
        audioController.stopMusic()
        let isNewBest = (runController.finalizedSummary?.score ?? runController.score) > runSession.previousBestScore
        persistFinalRunIfNeeded()
        if playFeedback {
            playAudio(.death)
            playDeathFeedback()
            playHaptic(.death)
        }
        if isNewBest {
            playAudio(.newBest)
            playHaptic(.newBest)
        }
        if !playFeedback {
            completePostRunTransition()
        }
        logFinishedRun(isNewBest: isNewBest)
    }

    private func updatePostRunTransition(deltaTime: TimeInterval) {
        if runSession.advancePostRunTransition(by: deltaTime) {
            completePostRunTransition()
        }
    }

    private func completePostRunTransition() {
        runSession.completePostRunTransition()
        guard runController.phase == .gameOver else {
            return
        }

        show(.postRun)
    }

    private func resetActiveRun(sequenceSeed: Int? = nil) {
        runSession.prepareNewRun()
        resetGameplayObjects(sequenceSeed: sequenceSeed)
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
    }

    private func resetGameplayObjects(sequenceSeed: Int? = nil) {
        balanceAccumulator = ArenaBalanceAccumulator()
        balanceStartingUnlockCount = runSession.selectedMode == .daily ? WeaponKind.allCases.count : runProfile.unlockedWeapons.count
        balanceExperimentalTuning = gameTuning != .defaults
        runSession.resetGameplayTransition()
        applySelectedModeTuning()
        let runSequenceSeed = sequenceSeed
            ?? ArenaModeRules.sequenceSeed(for: runSession.selectedMode)
            ?? Int.random(in: 0...Int.max)
        weaponRuntime.prepareRun(sequenceSeed: runSequenceSeed)
        enemyRegistry.reset()
        spawnDirector.reset(sequenceSeed: runSequenceSeed)

        pickupRegistry.reset()
        pickupPlanner.reset(
            configuration: pickupSpawnConfiguration,
            sequenceSeed: runSequenceSeed
        )
        clearWeaponEffectNodes(paused: false)
        deactivateRazorShield()
        activeWeapons.reset()
        flameTrailEffectNode.reset()
        deactivateGravityWell()
        deactivateTimeDilationAura()
        deactivatePowerWaveChargeEffect()
    }

    private func applyGameTuning(rebuildPlayerVisuals: Bool = false) {
        movementController.configuration = gameTuning.playerMovement
        calibrationPreviewMovementController.configuration = gameTuning.playerMovement
        var runConfiguration = gameTuning.run
        runConfiguration.playerVisualRadius = gameTuning.playerMovement.visualRadius
        runController.configuration = runConfiguration
        readyHoldController.configuration = gameTuning.readyStart
        weaponRuntime.configure(
            weaponConfiguration: gameTuning.startingWeapons,
            effectTiming: gameTuning.weaponEffectTiming
        )
        activeWeapons.configure(flameTrail: gameTuning.flameTrail)
        runSession.deathReplayTrace.duration = gameTuning.feedback.deathReplayDuration
        applySelectedModeTuning()

        if rebuildPlayerVisuals {
            playerNode?.removeFromParent()
            playerNode = nil
            calibrationPreviewPlayerNode?.removeFromParent()
            calibrationPreviewPlayerNode = nil
        }

        if playerNode != nil {
            placePlayer(resetPosition: false, resetTrail: false)
        }

        if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }

        if let razorShieldNode {
            let remainingShieldTime = activeWeapons.razorShield.timeRemaining
            razorShieldNode.removeFromParent()
            self.razorShieldNode = nil
            if remainingShieldTime > 0 {
                let node = SKShapeNode(circleOfRadius: razorShieldConfiguration.razorShieldRadius)
                node.zPosition = 19
                styleRazorShieldNode(node)
                node.position = movementController.state.position
                node.isHidden = false
                addWeaponEffectNode(node)
                self.razorShieldNode = node
            }
        }
    }

    private func applySelectedModeTuning() {
        let modeTuning = gameTuning.modeTuning(for: runSession.selectedMode)
        var tunedPickupConfiguration = modeTuning.pickupSpawnConfiguration
        if runSession.selectedMode != .daily {
            tunedPickupConfiguration.weaponKindCycle = ArenaProgressionRules.filteredWeaponCycle(
                tunedPickupConfiguration.weaponKindCycle,
                profile: runProfile
            )
        }

        spawnDirector.configuration = modeTuning.enemySpawnConfiguration
        pickupSpawnConfiguration = tunedPickupConfiguration.sanitizedForRuntime()
    }

    private func resetPlayerFeedback() {
        playerNode?.removeAllActions()
        playerNode?.alpha = 1
        playerNode?.setScale(1)
        playerNode?.applyCollisionProtection(false, theme: theme)
    }

    private func applyThemeChange() {
        backgroundColor = theme.backgroundColor
        configureDebugStats()
        rebuildArena()
        refreshGameplayNodesForTheme()
        rebuildUI()
    }

    private func refreshGameplayNodesForTheme() {
        playerNode?.applyTheme(theme)
        playerTrailNode?.applyTheme(theme)
        flameTrailEffectNode.applyTheme(theme)
        enemyRegistry.applyTheme(theme)
        refreshPickupNodesForTheme()
        refreshActiveWeaponEffectNodesForTheme()
    }

    private func refreshPickupNodesForTheme() {
        pickupRegistry.applyTheme(theme)
    }

    private func refreshActiveWeaponEffectNodesForTheme() {
        if let razorShieldNode {
            styleRazorShieldNode(razorShieldNode)
        }

        if let gravityWellState = activeWeapons.gravityWell {
            playGravityWellEffect(
                at: gravityWellState.center,
                radius: gravityWellState.pullRadius,
                clearRadius: gravityWellState.clearRadius,
                duration: gravityWellState.totalTimeRemaining
            )
        }

        if activeWeapons.powerWave.isCharging {
            playPowerWaveChargeEffect(
                at: movementController.state.position,
                direction: activeWeapons.aimDirection.resolvedDirection(),
                duration: activeWeapons.powerWave.chargeTimeRemaining
            )
        }

        if activeWeapons.timeDilation.timeRemaining > 0 {
            timeDilationAuraNode?.removeFromParent()
            timeDilationAuraNode = playTimeDilationAuraEffect(
                at: movementController.state.position,
                radius: timeDilationConfiguration.timeDilationRadius,
                duration: activeWeapons.timeDilation.timeRemaining
            )
        }
    }

    private func updateActiveRun(
        deltaTime: TimeInterval,
        playerPosition initialPlayerPosition: CGPoint,
        previousPlayerPosition: CGPoint
    ) {
        guard runController.phase == .active else { return }
        var playerPosition = initialPlayerPosition
        let wasPlayerCollisionProtected = isPlayerCollisionProtected
        balanceAccumulator.recordExposure(deltaTime: deltaTime, weapons: activeWeapons, enemies: enemies)

        runController.update(deltaTime: deltaTime)
        runSession.deathReplayTrace.record(time: runController.survivalTime, position: playerPosition)
        spawnEnemiesIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        advancePickupCharges(deltaTime: deltaTime)
        spawnPickupIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        updateFlameTrailTimers(deltaTime: deltaTime)
        updatePostWeaponSafety(deltaTime: deltaTime)
        updatePendingNovaBombClears(deltaTime: deltaTime)
        playerPosition = collectPickups(playerPosition: playerPosition)
        let previousDamageableEnemyPositions = damageableEnemyPositionsByID()
        let gravityOrigins = activeWeapons.gravityWell == nil ? [:] : Dictionary(
            uniqueKeysWithValues: enemies.map { ($0.id, $0.position) }
        )
        advanceEnemies(deltaTime: deltaTime, playerPosition: playerPosition)
        updateTimeDilationAura(deltaTime: deltaTime, playerPosition: playerPosition)
        updateGravityWell(deltaTime: deltaTime, previousPositions: gravityOrigins)
        updateShockwaveWaves(deltaTime: deltaTime)
        updateFreezeBurstWaves(deltaTime: deltaTime)
        updatePowerWave(deltaTime: deltaTime, playerPosition: playerPosition)
        removeExpiredEnemies()
        cullExitedLinearPatternEnemies()
        updateRazorShield(deltaTime: deltaTime, playerPosition: playerPosition)
        shatterFrozenContactEnemies(playerPosition: playerPosition)
        updateFlameTrail(deltaTime: deltaTime, playerPosition: playerPosition)
        detectPlayerCollision(
            playerPosition: playerPosition,
            previousPlayerPosition: previousPlayerPosition,
            previousDamageableEnemyPositions: previousDamageableEnemyPositions,
            allowsSweptCollision: !wasPlayerCollisionProtected
        )
        updateRunHUD()
        updatePlayerComboEffect()
    }

    private func spawnEnemiesIfNeeded(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let frame = spawnDirector.update(
            deltaTime: deltaTime,
            survivalTime: runController.survivalTime,
            activeEnemies: enemies,
            playableRect: currentPlayableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupRegistry.collisionCircles
        )

        balanceAccumulator.recordGates(frame.capacityGates, deltaTime: deltaTime)
        diagnosticAccumulator.recordSpawnCorrections(count: frame.runtimeCorrectionCount)

        removeEnemyTelegraphs(ids: frame.telegraphIDsToRemove)
        showEnemyTelegraphs(frame.telegraphsToShow)
        addSpawnedEnemies(frame.newEnemies)
    }

    private func addSpawnedEnemies(_ spawnedEnemies: [ArenaEnemy]) {
        balanceAccumulator.recordSpawns(spawnedEnemies)
        diagnosticAccumulator.recordSpawn(count: spawnedEnemies.count)

        enemyRegistry.add(spawnedEnemies, to: gameplayRoot, theme: theme)
        balanceAccumulator.recordPopulation(active: enemies.count, pending: spawnDirector.pendingEnemyCount)
    }

    private func showEnemyTelegraphs(_ telegraphs: [EnemyTelegraph]) {
        enemyRegistry.showTelegraphs(telegraphs, in: gameplayRoot, theme: theme)
    }

    private func removeEnemyTelegraphs(ids telegraphIDs: Set<Int>) {
        enemyRegistry.removeTelegraphs(ids: telegraphIDs)
    }

    private func spawnPickupIfNeeded(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let enemyCircles = enemies.map(\.collisionCircle)

        let spawnedPickups = pickupPlanner.update(
            deltaTime: deltaTime,
            phase: runController.phase,
            activePickupCount: pickupRegistry.count,
            playableRect: currentPlayableRect,
            playerPosition: playerPosition,
            enemyCircles: enemyCircles,
            pickupCircles: pickupRegistry.collisionCircles,
            configuration: pickupSpawnConfiguration
        )

        guard !spawnedPickups.isEmpty else {
            return
        }

        let acceptedPickups = pickupRegistry.add(spawnedPickups, to: gameplayRoot, theme: theme)
        for pickup in acceptedPickups {
            weaponLogger.info("pickup.spawned", metadata: [
                "id": "\(pickup.id)",
                "kind": "\(pickup.kind.rawValue)",
                "tier": "\(pickup.chargeTier.metadataValue)"
            ])
        }
    }

    private func advancePickupCharges(deltaTime: TimeInterval) {
        let chargedPickups = pickupRegistry.advanceCharges(
            deltaTime: deltaTime,
            configuration: pickupSpawnConfiguration
        )
        for pickup in chargedPickups {
            weaponLogger.info("pickup.charged", metadata: [
                "id": "\(pickup.id)",
                "kind": "\(pickup.kind.rawValue)",
                "tier": "\(pickup.chargeTier.metadataValue)"
            ])
        }
    }

    private func advanceEnemies(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let runSpeedMultiplier = spawnDirector.configuration.enemySurvivalSpeedMultiplier(
            at: runController.survivalTime
        )
        let playerMaximumSpeed = movementController.configuration.maximumSpeed(in: currentGameplayBounds)

        enemyRegistry.updateAll { [self] enemy in
            let maximumEnemySpeed = spawnDirector.configuration.maximumSpeed(
                for: enemy.behavior.kind,
                playerMaximumSpeed: playerMaximumSpeed
            )
            let slowMultiplier = activeWeapons.timeDilation.enemySpeedMultiplier(
                for: enemy,
                playerPosition: playerPosition
            )
            enemy.advance(
                toward: playerPosition,
                deltaTime: deltaTime,
                externalSpeedMultiplier: runSpeedMultiplier * slowMultiplier,
                maximumSpeed: maximumEnemySpeed * slowMultiplier
            )
        }
    }

    private func cullExitedLinearPatternEnemies() {
        let cullingRect = currentPlayableRect.insetBy(
            dx: -spawnDirector.configuration.cullingOutset,
            dy: -spawnDirector.configuration.cullingOutset
        )
        let exitedEnemies = enemies.filter { $0.isLinearPatternEnemy && !cullingRect.contains($0.position) }
        let exitedEnemyIDs = Set(exitedEnemies.map(\.id))

        guard !exitedEnemyIDs.isEmpty else {
            return
        }

        enemyRegistry.remove(ids: exitedEnemyIDs, presentation: .immediate)
    }

    private func removeExpiredEnemies() {
        let expiredEnemyIDs = Set(enemies.filter(\.isExpired).map(\.id))

        guard !expiredEnemyIDs.isEmpty else {
            return
        }

        enemyRegistry.remove(ids: expiredEnemyIDs, presentation: .immediate)
    }

    private func collectPickups(playerPosition: CGPoint) -> CGPoint {
        var currentPlayerPosition = playerPosition
        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: movementController.configuration.visualRadius
        )
        let collectedPickups = pickups.filter { playerCircle.intersects($0.collisionCircle) }

        guard !collectedPickups.isEmpty else {
            return currentPlayerPosition
        }

        for pickup in collectedPickups {
            let didCreditPickup = runController.recordItemPickup(pickupID: pickup.id)
            if didCreditPickup {
                reportGameCenterAchievementEvent(.weaponOrbCollected)
            }
            playAudio(.pickup)
            playHaptic(.pickup)
            weaponLogger.notice("pickup.collected", metadata: [
                "id": "\(pickup.id)",
                "kind": "\(pickup.kind.rawValue)",
                "tier": "\(pickup.chargeTier.metadataValue)"
            ])

            playPickupCollectionPop(for: pickup)
            removePickup(id: pickup.id)
            applyWeapon(pickup, playerPosition: currentPlayerPosition)
            currentPlayerPosition = movementController.state.position
        }

        return currentPlayerPosition
    }

    private func removePickup(id: Int) {
        pickupRegistry.remove(id: id)
    }

    private func applyWeapon(_ pickup: WeaponPickup, playerPosition: CGPoint) {
        activeWeapons.postWeaponSafety.grant(duration: gameTuning.feedback.pickupCollectionGrace)
        let plan = weaponRuntime.activationPlan(
            for: pickup,
            playerPosition: playerPosition,
            enemies: enemies
        )
        let chargedConfiguration = plan.configuration
        let application = plan.application
        let activation = balanceAccumulator.recordPickup(pickup, at: runController.survivalTime)
        var log = application.log

        if let directionalDestroyedCount = performWeaponApplicationEffect(
            application.effect,
            from: playerPosition,
            configuration: chargedConfiguration,
            chargeTier: pickup.chargeTier,
            activation: activation
        ) {
            log.destroyedCount = directionalDestroyedCount
        }
        playChargedWeaponActivationEffect(
            kind: pickup.kind,
            at: playerPosition,
            chargeTier: pickup.chargeTier
        )
        updatePlayerCollisionProtection()

        let logicalTargetCount = max(log.destroyedCount, log.frozenCount, log.gravityTargetCount)
        weaponLogger.notice("weapon.resolved", metadata: [
            "kind": "\(pickup.kind.rawValue)",
            "tier": "\(pickup.chargeTier.metadataValue)",
            "destroyed": "\(log.destroyedCount)",
            "frozen": "\(log.frozenCount)",
            "gravityTargets": "\(log.gravityTargetCount)",
            "visualTargetLimit": "\(WeaponImpactPlan.maximumVisualTargetCount)",
            "visualsCapped": "\(logicalTargetCount > WeaponImpactPlan.maximumVisualTargetCount)"
        ])
    }

    private func performWeaponApplicationEffect(
        _ effect: WeaponApplication.Effect,
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        chargeTier: WeaponPickupChargeTier,
        activation: WeaponActivation
    ) -> Int? {
        switch effect {
        case .timeDilationAura:
            activateTimeDilationAura(at: playerPosition, configuration: configuration)
            return nil
        case .ricochetLance:
            let destroyedCount = fireRicochetLance(from: playerPosition, configuration: configuration, activation: activation)
            return destroyedCount
        default:
            performWeaponActivationEffect(
                effect,
                from: playerPosition,
                configuration: configuration,
                chargeTier: chargeTier,
                activation: activation
            )
            return nil
        }
    }

    private func performWeaponActivationEffect(
        _ effect: WeaponApplication.Effect,
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        chargeTier: WeaponPickupChargeTier,
        activation: WeaponActivation
    ) {
        switch effect {
        case .shockwaveWave:
            activateShockwaveWave(at: playerPosition, configuration: configuration, activation: activation)
        case .seekerSwarm(let enemyIDs):
            playSeekerSwarm(
                enemyIDs: enemyIDs,
                from: playerPosition,
                configuration: configuration,
                activation: activation
            )
        case .razorShield:
            activateRazorShield(at: playerPosition, configuration: configuration, activation: activation)
        case .freezeBurstWave:
            activateFreezeBurstWave(at: playerPosition, configuration: configuration, activation: activation)
        case .gravityWell:
            activateGravityWell(at: playerPosition, configuration: configuration, activation: activation)
        case .chainLightning(let enemyIDs):
            playChainLightning(enemyIDs: enemyIDs, from: playerPosition, configuration: configuration, activation: activation)
        case .flameTrail:
            activateFlameTrail(at: playerPosition, chargeTier: chargeTier, activation: activation)
        case .timeDilationAura, .ricochetLance:
            break
        case .powerWave:
            activatePowerWave(at: playerPosition, configuration: configuration, activation: activation)
        case .novaBomb(let enemyIDs):
            playNovaBomb(enemyIDs: enemyIDs, activation: activation)
        }
    }

    private func playSeekerSwarm(
        enemyIDs: Set<Int>,
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .seekerSwarm)
    ) {
        let resolver = StartingWeaponResolver(configuration: configuration)
        let targets = impactTargets(forEnemyIDs: enemyIDs)
            .sorted { lhs, rhs in
                ArenaGeometry.squaredDistance(from: lhs.position, to: playerPosition)
                    < ArenaGeometry.squaredDistance(from: rhs.position, to: playerPosition)
            }
        let lastImpact = playSeekerSwarmEffect(
            from: playerPosition,
            to: targets,
            configuration: configuration,
            targetPosition: { [weak self] enemyID in
                self?.position(forEnemyID: enemyID)
            },
            onImpact: { [weak self] target in
                self?.resolveSeekerExplosion(at: target, resolver: resolver, activation: activation)
            }
        )
        grantProjectileSafety(for: .seekerSwarm, lastImpact: lastImpact)
    }

    private func position(forEnemyID enemyID: Int) -> CGPoint? {
        enemyRegistry.enemy(id: enemyID)?.position
    }

    private func resolveSeekerExplosion(
        at target: WeaponImpactTarget, resolver: StartingWeaponResolver,
        activation: WeaponActivation = WeaponActivation(kind: .seekerSwarm)
    ) {
        destroyEnemies(
            ids: resolver.seekerExplosionTargets(center: target.position, enemies: enemies),
            weaponKind: .seekerSwarm,
            activation: activation
        )
    }

    private func playChainLightning(
        enemyIDs: [Int],
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .chainLightning)
    ) {
        let targets = impactTargets(forEnemyIDs: enemyIDs)
        let lastImpact = playChainLightningEffect(
            from: playerPosition,
            through: targets,
            configuration: configuration,
            onImpact: { [weak self] enemyIDs in
                self?.destroyEnemies(ids: enemyIDs, weaponKind: .chainLightning, activation: activation)
            }
        )
        grantProjectileSafety(for: .chainLightning, lastImpact: lastImpact)
    }

    private func playNovaBomb(
        enemyIDs: Set<Int>, activation: WeaponActivation = WeaponActivation(kind: .novaBomb)
    ) {
        grantPostWeaponSafety(
            for: .novaBomb,
            minimumDuration: weaponEffectTiming.maximumWaveTravelDuration
        )
        let targets = impactTargets(forEnemyIDs: enemyIDs)
        let delay = playNovaBombEffect(targets: targets)

        guard !enemyIDs.isEmpty else {
            return
        }
        guard delay > 0 else {
            destroyEnemies(ids: enemyIDs, weaponKind: .novaBomb, activation: activation)
            return
        }

        activeWeapons.pendingNovaBombClears.append(ArenaPendingNovaBombClear(
            activation: activation,
            enemyIDs: enemyIDs,
            timeRemaining: delay
        ))
    }

    private func updatePendingNovaBombClears(deltaTime: TimeInterval) {
        guard !activeWeapons.pendingNovaBombClears.isEmpty else {
            return
        }

        let clampedDelta = max(0, deltaTime)
        for index in activeWeapons.pendingNovaBombClears.indices {
            activeWeapons.pendingNovaBombClears[index].timeRemaining = max(
                0,
                activeWeapons.pendingNovaBombClears[index].timeRemaining - clampedDelta
            )
        }

        let completedClears = activeWeapons.pendingNovaBombClears.filter { $0.timeRemaining == 0 }
        activeWeapons.pendingNovaBombClears.removeAll { $0.timeRemaining == 0 }
        for clear in completedClears {
            destroyEnemies(ids: clear.enemyIDs, weaponKind: .novaBomb, activation: clear.activation)
            grantPostWeaponSafety(for: .novaBomb)
        }
    }

    private func impactTargets(forEnemyIDs enemyIDs: Set<Int>) -> [WeaponImpactTarget] {
        enemies.compactMap { enemy in
            enemyIDs.contains(enemy.id) ? WeaponImpactTarget(id: enemy.id, position: enemy.position) : nil
        }
    }

    private func impactTargets(forEnemyIDs enemyIDs: [Int]) -> [WeaponImpactTarget] {
        let enemiesByID = indexedEnemiesByID()
        return enemyIDs.compactMap { enemyID in
            guard let enemy = enemiesByID[enemyID] else {
                return nil
            }

            return WeaponImpactTarget(id: enemy.id, position: enemy.position)
        }
    }

    private func damageableEnemyPositionsByID() -> [Int: CGPoint] {
        enemyRegistry.damageablePositionsByID()
    }

    private func indexedEnemiesByID() -> [Int: ArenaEnemy] {
        enemyRegistry.indexedEnemiesByID()
    }

    @discardableResult
    private func destroyEnemies(
        ids enemyIDs: Set<Int>,
        weaponKind: WeaponKind?,
        activation: WeaponActivation? = nil
    ) -> Set<Int> {
        guard runController.phase == .active, !enemyIDs.isEmpty else {
            return []
        }
        let destroyedEnemies = enemies.filter { enemyIDs.contains($0.id) }
        guard !destroyedEnemies.isEmpty else {
            return []
        }

        let enemyIDs = Set(destroyedEnemies.map(\.id))
        let clearPositions = destroyedEnemies.map(\.position)
        let splitChildren = splitterChildren(from: destroyedEnemies, destroyedBy: weaponKind)
        let previousComboMultiplier = runController.comboMultiplier
        let wasQualified = activation?.hasQualifiedClear ?? false
        let previousActivationKills = activation?.killCount ?? 0
        let weaponComboEvent = runController.recordEnemyKills(
            count: enemyIDs.count, weaponKind: weaponKind, activation: activation
        )
        if let activation { balanceAccumulator.recordKills(activation, previousCount: previousActivationKills) }
        let newlyQualified = !wasQualified && (activation?.hasQualifiedClear ?? false)
        let achievementClearCount = activation.map { newlyQualified ? $0.killCount : 1 } ?? enemyIDs.count
        reportGameCenterAchievementEvent(.enemyClear(
            count: achievementClearCount, weaponKind: weaponKind, maxCombo: runController.maxCombo
        ))
        playEnemyClearHaptics(killCount: enemyIDs.count, previousComboMultiplier: previousComboMultiplier)
        playEnemyClearAudio(killCount: enemyIDs.count, previousComboMultiplier: previousComboMultiplier)
        if let weaponComboEvent {
            balanceAccumulator.recordCombo(weaponComboEvent)
            recordWeaponComboFeedback(
                weaponComboEvent,
                previousComboMultiplier: previousComboMultiplier,
                clearPositions: clearPositions
            )
        }
        if weaponKind == .freezeBurst {
            playFrozenShatterEffect(at: clearPositions, color: theme.playerColor)
        } else {
            playEnemyClearBursts(
                at: clearPositions,
                weaponKind: weaponKind,
                comboMultiplier: runController.comboMultiplier
            )
        }
        if enemyIDs.count >= gameTuning.feedback.multiKillShakeThreshold {
            playScreenShake(
                amplitude: gameTuning.feedback.multiKillShakeAmplitude,
                duration: gameTuning.feedback.multiKillShakeDuration
            )
        }
        removeEnemies(ids: enemyIDs)
        addSplitterChildren(splitChildren)
        return enemyIDs
    }

    private func splitterChildren(
        from destroyedEnemies: [ArenaEnemy],
        destroyedBy weaponKind: WeaponKind?
    ) -> [ArenaEnemy] {
        switch weaponKind {
        case .gravityWell, .novaBomb, .freezeBurst:
            return []
        default:
            break
        }

        let playerPosition = movementController.state.position
        return destroyedEnemies.flatMap { enemy in
            spawnDirector.splitChildren(
                for: enemy,
                playableRect: currentPlayableRect,
                playerPosition: playerPosition
            )
        }
    }

    private func addSplitterChildren(_ children: [ArenaEnemy]) {
        let maxActiveEnemies = spawnDirector.configuration.tuning(at: runController.survivalTime).maxActiveEnemies
        let availableSlots = max(0, maxActiveEnemies - enemies.count)
        let childrenToAdd = Array(children.prefix(availableSlots))

        guard !childrenToAdd.isEmpty else {
            return
        }

        spawnLogger.info("enemy.split", metadata: [
            "children": "\(childrenToAdd.count)"
        ])
        addSpawnedEnemies(childrenToAdd)
    }

    private func reportGameCenterAchievementEvent(_ event: GameCenterAchievementEvent) {
        gameCenterReporter.reportAchievementEvent(event)
    }

    private func removeEnemies(ids enemyIDs: Set<Int>) {
        enemyRegistry.remove(ids: enemyIDs, presentation: .defeated)
    }

    private func activateRazorShield(
        at playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .razorShield)
    ) {
        let resolvedConfiguration = activeWeapons.razorShield.activate(with: configuration, activation: activation)

        razorShieldNode?.removeFromParent()
        razorShieldNode = nil

        guard activeWeapons.razorShield.timeRemaining > 0 else {
            triggerRazorShieldExpiryExplosion(at: playerPosition)
            deactivateRazorShield(emitHaptic: true)
            grantPostWeaponSafety(for: .razorShield)
            return
        }

        let node = SKShapeNode(circleOfRadius: resolvedConfiguration.razorShieldRadius)
        node.zPosition = 19
        styleRazorShieldNode(node)
        addWeaponEffectNode(node)
        razorShieldNode = node

        razorShieldNode?.position = playerPosition
        razorShieldNode?.isHidden = false
    }

    private var razorShieldConfiguration: StartingWeaponConfiguration {
        activeWeapons.razorShield.resolvedConfiguration(fallback: weaponResolver.configuration)
    }

    private func styleRazorShieldNode(_ node: SKShapeNode) {
        let configuration = razorShieldConfiguration
        node.strokeColor = theme.pickupBlue.withAlphaComponent(0.72)
        node.fillColor = theme.pickupBlue.withAlphaComponent(0.05)
        node.lineWidth = 2
        node.glowWidth = 1.25
        node.removeAllChildren()
        node.removeAction(forKey: "razor.spin")
        node.removeAction(forKey: "razor.warning")
        node.alpha = 1
        node.setScale(1)

        for index in 0..<3 {
            let angle = CGFloat(index) * (2 * .pi / 3)
            let blade = SKShapeNode(path: razorShieldBladePath(radius: configuration.razorShieldRadius))
            blade.zRotation = angle
            blade.strokeColor = theme.playerColor.withAlphaComponent(0.68)
            blade.lineWidth = 1.4
            blade.lineCap = .round
            blade.glowWidth = 0.8
            node.addChild(blade)
        }

        node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.72)), withKey: "razor.spin")
    }

    private func razorShieldBladePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: -.pi / 8,
            endAngle: .pi / 4,
            clockwise: false
        )
        return path
    }

    private func updateRazorShield(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard activeWeapons.razorShield.timeRemaining > 0 else {
            deactivateRazorShield()
            return
        }

        razorShieldNode?.position = playerPosition

        let resolver = StartingWeaponResolver(configuration: razorShieldConfiguration)
        let targetIDs = resolver.shieldTargets(
            playerPosition: playerPosition,
            enemies: enemies
        )
        let targets = impactTargets(forEnemyIDs: targetIDs)
        destroyEnemies(ids: targetIDs, weaponKind: .razorShield, activation: activeWeapons.razorShield.activation)
        playRazorShieldImpactEffect(from: playerPosition, targets: targets)

        activeWeapons.razorShield.advance(by: deltaTime)
        playRazorShieldWarningIfNeeded()

        if activeWeapons.razorShield.timeRemaining == 0 {
            triggerRazorShieldExpiryExplosion(at: playerPosition)
            deactivateRazorShield(emitHaptic: true)
            grantPostWeaponSafety(for: .razorShield)
        }
    }

    private func triggerRazorShieldExpiryExplosion(at playerPosition: CGPoint) {
        let configuration = razorShieldConfiguration
        let activation = activeWeapons.razorShield.activation
        let resolver = StartingWeaponResolver(configuration: configuration)
        let targetIDs = resolver.shieldExplosionTargets(
            playerPosition: playerPosition,
            enemies: enemies
        )
        let targets = impactTargets(forEnemyIDs: targetIDs)
        playRazorShieldExplosionEffect(
            at: playerPosition,
            startRadius: configuration.razorShieldRadius,
            explosionRadius: configuration.razorShieldExplosionRadius,
            targets: targets
        ) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .razorShield, activation: activation)
        }
    }

    private func deactivateRazorShield(emitHaptic: Bool = false) {
        let hadActiveShield = activeWeapons.razorShield.isActive || razorShieldNode != nil
        activeWeapons.razorShield.clear()
        razorShieldNode?.removeFromParent()
        razorShieldNode = nil

        if emitHaptic, hadActiveShield, runController.phase == .active {
            playAudio(.shieldExpired)
            playHaptic(.shieldExpired)
        }
    }

    private func playRazorShieldWarningIfNeeded() {
        guard activeWeapons.razorShield.claimWarningIfNeeded(
            leadTime: gameTuning.feedback.razorShieldWarningLeadTime,
            isRunActive: runController.phase == .active
        ) else {
            return
        }

        playAudio(.shieldWarning)
        playHaptic(.shieldWarning)
        let pulse = SKAction.sequence([
            .group([.fadeAlpha(to: 0.48, duration: 0.06), .scale(to: 1.12, duration: 0.06)]),
            .group([.fadeAlpha(to: 1, duration: 0.08), .scale(to: 1, duration: 0.08)])
        ])
        razorShieldNode?.run(.repeat(pulse, count: 3), withKey: "razor.warning")
    }

    private func updateFlameTrail(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let frame = activeWeapons.flameTrail.update(
            deltaTime: deltaTime,
            playerPosition: playerPosition,
            enemies: enemies
        )
        let targets = impactTargets(forEnemyIDs: frame.burnedEnemyIDs)
        var remainingIDs = frame.burnedEnemyIDs
        for segment in frame.segments {
            guard let activation = segment.activation, let ids = frame.killsByActivation[activation] else { continue }
            let claimedIDs = ids.intersection(remainingIDs)
            destroyEnemies(ids: claimedIDs, weaponKind: .flameTrail, activation: activation)
            remainingIDs.subtract(claimedIDs)
        }
        destroyEnemies(ids: remainingIDs, weaponKind: .flameTrail)
        playFlameTrailImpactEffect(at: targets)
        flameTrailEffectNode.apply(segments: frame.segments)
    }

    private func activateFlameTrail(
        at playerPosition: CGPoint, chargeTier: WeaponPickupChargeTier = .base,
        activation: WeaponActivation = WeaponActivation(kind: .flameTrail)
    ) {
        activeWeapons.flameTrail.configuration = gameTuning.flameTrail.applying(chargeTier: chargeTier)
        activeWeapons.flameTrail.activate(at: playerPosition, activation: activation)
        activeWeapons.flameTrailProtection.activate(
            configuration: activeWeapons.flameTrail.configuration,
            postWeaponSafetyDuration: gameTuning.feedback.postWeaponSafetyDuration
        )
        flameTrailEffectNode.apply(segments: activeWeapons.flameTrail.segments)
    }

    private func updateFlameTrailTimers(deltaTime: TimeInterval) {
        activeWeapons.flameTrailProtection.advance(by: deltaTime)
    }

    private var isFlameTrailInvulnerable: Bool {
        activeWeapons.flameTrailProtection.isInvulnerable
    }

    private func grantProjectileSafety(for kind: WeaponKind, lastImpact: TimeInterval) {
        grantPostWeaponSafety(
            for: kind,
            minimumDuration: lastImpact + WeaponRuntimeSafetyLimits.duration(gameTuning.feedback.postWeaponSafetyDuration)
        )
    }

    private func grantPostWeaponSafety(
        for weaponKind: WeaponKind,
        minimumDuration: TimeInterval = 0
    ) {
        let duration = WeaponRuntimeSafetyLimits.duration(
            max(
                0,
                gameTuning.feedback.postWeaponSafetyDuration,
                minimumDuration
            )
        )
        guard duration > 0, runController.phase == .active else {
            return
        }

        activeWeapons.postWeaponSafety.grant(duration: duration)
        updatePlayerCollisionProtection()
        weaponLogger.debug("weapon.postSafety", metadata: [
            "kind": "\(weaponKind.rawValue)",
            "duration": "\(duration)"
        ])
    }

    private func updatePostWeaponSafety(deltaTime: TimeInterval) {
        activeWeapons.postWeaponSafety.advance(by: deltaTime)
    }

    private var isPostWeaponSafe: Bool {
        activeWeapons.postWeaponSafety.isActive
    }

    private var isPlayerCollisionProtected: Bool {
        isFlameTrailInvulnerable || isPostWeaponSafe
    }

    private func activateTimeDilationAura(
        at playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        let resolvedConfiguration = activeWeapons.timeDilation.activate(with: configuration)

        guard activeWeapons.timeDilation.timeRemaining > 0 else {
            pushTimeDilationEnemies(from: playerPosition)
            deactivateTimeDilationAura()
            grantPostWeaponSafety(for: .warpDash)
            return
        }

        timeDilationAuraNode?.removeFromParent()
        timeDilationAuraNode = playTimeDilationAuraEffect(
            at: playerPosition,
            radius: resolvedConfiguration.timeDilationRadius,
            duration: activeWeapons.timeDilation.timeRemaining
        )
        pushTimeDilationEnemies(from: playerPosition)
    }

    private var timeDilationConfiguration: StartingWeaponConfiguration {
        activeWeapons.timeDilation.resolvedConfiguration(fallback: weaponResolver.configuration)
    }

    private func pushTimeDilationEnemies(from playerPosition: CGPoint) {
        let configuration = timeDilationConfiguration
        let pushRadius = max(0, configuration.timeDilationPushRadius)
        let maximumPushDistance = max(0, configuration.timeDilationMaximumPushDistance)

        guard pushRadius > 0, maximumPushDistance > 0 else {
            return
        }

        enemyRegistry.updateAll { enemy in
            let distance = hypot(
                enemy.position.x - playerPosition.x,
                enemy.position.y - playerPosition.y
            )

            if distance <= pushRadius {
                let strength = 1 - min(1, max(0, distance / pushRadius))
                enemy.pushAway(from: playerPosition, distance: maximumPushDistance * strength)
            }
        }
    }

    private func updateTimeDilationAura(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard activeWeapons.timeDilation.timeRemaining > 0 else {
            return
        }

        timeDilationAuraNode?.position = playerPosition

        if activeWeapons.timeDilation.advance(by: deltaTime) {
            timeDilationAuraNode?.removeFromParent()
            timeDilationAuraNode = nil
            grantPostWeaponSafety(for: .warpDash)
        }
    }

    private func deactivateTimeDilationAura() {
        activeWeapons.timeDilation.clear()
        timeDilationAuraNode?.removeFromParent()
        timeDilationAuraNode = nil
    }

    private func fireRicochetLance(
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .ricochetLance)
    ) -> Int {
        let result = RicochetLancePath.resolve(
            origin: playerPosition,
            direction: activeWeapons.aimDirection.resolvedDirection(),
            playableRect: currentPlayableRect,
            enemies: enemies,
            configuration: configuration
        )
        let targets = impactTargets(forEnemyIDs: result.destroyedEnemyIDs)
        let lastImpact = playRicochetLanceEffect(
            segments: result.segments,
            targets: targets,
            configuration: configuration
        ) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .ricochetLance, activation: activation)
        }

        grantProjectileSafety(for: .ricochetLance, lastImpact: lastImpact)
        return targets.count
    }

    private func detectPlayerCollision(
        playerPosition: CGPoint,
        previousPlayerPosition: CGPoint? = nil,
        previousDamageableEnemyPositions: [Int: CGPoint] = [:],
        allowsSweptCollision: Bool = true
    ) {
        guard !isPlayerCollisionProtected else {
            return
        }

        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )
        let motion = PlayerCollisionMotion(
            playerCircle: playerCircle,
            playerStart: previousPlayerPosition ?? playerPosition,
            previousDamageableEnemyPositions: previousDamageableEnemyPositions,
            allowsSweptCollision: allowsSweptCollision
        )
        let collision = enemies.compactMap { collisionCandidate(for: $0, motion: motion) }
            .min { $0.impactTime < $1.impactTime }

        guard let collision else {
            return
        }

        balanceAccumulator.deathRole = collision.enemyKind
        runLogger.notice("run.player_collision", metadata: [
            "allowsSwept": "\(allowsSweptCollision)",
            "enemies": "\(enemies.count)",
            "enemyID": "\(collision.enemyID)",
            "enemyKind": "\(collision.enemyKind.rawValue)",
            "impactTime": "\(collision.impactTime)",
            "pickups": "\(pickups.count)",
            "score": "\(runController.score)",
            "survivalTime": "\(runController.survivalTime)",
            "weaponEffects": "\(weaponEffectsRoot.children.count)"
        ])
        finishRun(
            collision: collision.snapshot
        )
    }

    private func collisionCandidate(
        for enemy: ArenaEnemy,
        motion: PlayerCollisionMotion
    ) -> PlayerCollisionCandidate? {
        guard enemy.canDamagePlayer else {
            return nil
        }

        let enemyStart = motion.previousDamageableEnemyPositions[enemy.id]
        let impactTime: CGFloat?
        if motion.allowsSweptCollision,
           let enemyStart {
            impactTime = motion.playerCircle.firstIntersectionTimeDuringMovement(
                from: motion.playerStart,
                with: enemy.collisionCircle,
                movingFrom: enemyStart
            )
        } else {
            impactTime = motion.playerCircle.intersects(enemy.collisionCircle) ? 1 : nil
        }

        guard let impactTime else {
            return nil
        }

        return PlayerCollisionCandidate(
            impactTime: impactTime,
            enemyID: enemy.id,
            enemyKind: enemy.behavior.kind,
            snapshot: DeathCollisionSnapshot(
                playerPosition: Self.interpolatedPosition(
                    from: motion.playerStart,
                    to: motion.playerCircle.center,
                    time: impactTime
                ),
                enemyPosition: Self.interpolatedPosition(
                    from: enemyStart ?? enemy.position,
                    to: enemy.position,
                    time: impactTime
                ),
                enemyRadius: enemy.radius
            )
        )
    }

    private static func interpolatedPosition(from start: CGPoint, to end: CGPoint, time: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * time,
            y: start.y + (end.y - start.y) * time
        )
    }

    private func playDeathFeedback() {
        playScreenShake(
            amplitude: gameTuning.feedback.deathShakeAmplitude,
            duration: gameTuning.feedback.deathShakeDuration
        )
        let pulse = SKAction.group([
            .scale(to: 1.45, duration: 0.08),
            .fadeAlpha(to: 0.35, duration: 0.08)
        ])
        let settle = SKAction.scale(to: 1.0, duration: 0.08)

        playerNode?.run(.sequence([pulse, settle]))
    }

    private func syncAudioOption() {
        audioController.isEnabled = localOptions.audioEnabled
    }

    private func syncHapticsOption() {
        hapticsController.isEnabled = localOptions.hapticsEnabled
    }

    private func playAudio(_ event: ArenaAudioEvent) {
        audioController.play(event, at: runController.survivalTime)
    }

    private func playHaptic(_ event: ArenaHapticEvent) {
        hapticsController.play(event)
    }

    private func playEnemyClearHaptics(killCount: Int, previousComboMultiplier: Int) {
        playHaptic(.enemyClear(count: killCount))

        let currentComboMultiplier = runController.comboMultiplier
        if currentComboMultiplier > previousComboMultiplier {
            playHaptic(.comboMilestone(multiplier: currentComboMultiplier))
        }
    }

    private func playEnemyClearAudio(killCount: Int, previousComboMultiplier: Int) {
        playAudio(.enemyClear(count: killCount))

        let currentComboMultiplier = runController.comboMultiplier
        if currentComboMultiplier > previousComboMultiplier {
            playAudio(.comboMilestone)
        }
    }

    private func playScreenShake(amplitude: CGFloat, duration: TimeInterval) {
        guard amplitude > 0, duration > 0 else {
            return
        }

        let xAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        xAnimation.values = [0, amplitude, -amplitude * 0.7, amplitude * 0.35, 0]
        xAnimation.duration = duration

        let yAnimation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        yAnimation.values = [0, -amplitude * 0.45, amplitude * 0.3, -amplitude * 0.2, 0]
        yAnimation.duration = duration

        let group = CAAnimationGroup()
        group.animations = [xAnimation, yAnimation]
        group.duration = duration
        view?.layer.add(group, forKey: "arena.screenShake")
    }

    private func formatSurvivalTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }

    private var selectedModeRecord: RunRecord {
        let hasActiveContext = uiState == .activeGameplay || uiState == .pause || uiState == .postRun
        return runProfile.competitiveRecord(
            for: runSession.selectedMode,
            seed: hasActiveContext ? runController.context.sequenceSeed : nil
        )
    }

    private func updateRunHUD() {
        runScoreLabel?.text = "SCORE \(runController.score)  \(formatSurvivalTime(runController.survivalTime))"
        runBestLabel?.text = "\(runSession.selectedMode == .daily ? "DAILY BEST" : "BEST") \(selectedModeRecord.bestScore)"
    }

    private func updatePlayerComboEffect() {
        updatePlayerCollisionProtection()
        let showsComboEffect = uiState == .activeGameplay || uiState == .pause
        let weaponPrimer = showsComboEffect ? runController.weaponComboPrimer : nil
        let comboProgress = showsComboEffect
            ? normalizedEffectProgress(
                remaining: runController.comboTimeRemaining,
                duration: runController.configuration.comboWindow
            )
            : 0
        playerNode?.applyComboEffect(
            comboProgress: comboProgress,
            comboMultiplier: runController.comboMultiplier,
            weaponPrimerProgress: normalizedEffectProgress(
                remaining: weaponPrimer?.timeRemaining ?? 0,
                duration: runController.configuration.weaponComboWindow
            ),
            weaponPrimerFamily: weaponPrimer?.family,
            theme: theme,
            isPaused: uiState == .pause
        )
    }

    private func updatePlayerCollisionProtection() {
        let showsGameplay = uiState == .activeGameplay || uiState == .pause
        playerNode?.applyCollisionProtection(showsGameplay && isPlayerCollisionProtected, theme: theme)
    }

    private func normalizedEffectProgress(
        remaining: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0 else {
            return 0
        }

        return CGFloat(min(1, max(0, remaining / duration)))
    }

    private func persistFinalRunIfNeeded() {
        guard runSession.needsFinalRunPersistence, let summary = runController.finalizedSummary else {
            return
        }

        let result = runProfileStore.record(summary)
        runProfile = result.profile
        if summary.score == Int.max
            || runProfile.totalRuns == Int.max
            || runProfile.totalEnemiesDestroyed == Int.max {
            profileLogger.critical("profile.counter_saturated", metadata: [
                "score": "\(summary.score)",
                "totalEnemies": "\(runProfile.totalEnemiesDestroyed)",
                "totalRuns": "\(runProfile.totalRuns)"
            ])
        }
        runSession.recordProgression(result)
        gameCenterReporter.submitRunScore(summary)
        gameCenterReporter.reportAchievementEvent(.runFinished(summary))
    }

}

// MARK: - UI state and actions

private extension ArenaScene {
    func show(_ state: ArenaUISceneState) {
        if uiState == .preRun, state != .preRun, state != .activeGameplay {
            readyHoldController.reset()
        }
        let transition = navigationState.transition(to: state)
        if transition.previous != transition.current {
            sceneLogger.info("scene.state_changed", metadata: [
                "from": "\(transition.previous.diagnosticName)",
                "runPhase": "\(runController.phase.diagnosticName)",
                "to": "\(transition.current.diagnosticName)"
            ])
        }
        syncOrientationLock()
        rebuildUI()
    }

    func syncOrientationLock() {
        if shouldLockCurrentOrientation {
            let preferredOrientation = currentWindowTiltScreenOrientation
                ?? runTiltScreenOrientation
                ?? lastKnownTiltScreenOrientation
            let lockedOrientation = orientationDelegate?.arenaSceneRequestsRunOrientationLock(
                self,
                preferredOrientation: preferredOrientation
            ) ?? preferredOrientation
            runTiltScreenOrientation = lockedOrientation
            lastKnownTiltScreenOrientation = lockedOrientation
        } else {
            runTiltScreenOrientation = nil
            orientationDelegate?.arenaSceneRequestsOrientationUnlock(self)
        }
    }

    var shouldLockCurrentOrientation: Bool {
        navigationState.shouldLockCurrentOrientation
    }

    func rebuildUI() {
        gameplayOverlayRoot.removeAllChildren()
        uiRenderer.begin(theme: theme, sceneSize: size)
        runScoreLabel = nil
        runBestLabel = nil
        calibrationPreviewPlayerNode = nil
        calibrationPreviewTrailNode = nil
        tiltReadoutValueLabels.removeAll()
        tiltReadoutUpdateTime = 0
        readyProgressRing = nil
        readyStatusLabel = nil
        updatePersistentGameplayNodeVisibility()

        renderCurrentUI()

        updatePlayerComboEffect()
    }

    func renderCurrentUI() {
        guard !renderMenuUI() else {
            return
        }

        renderRunUI()
    }

    func renderMenuUI() -> Bool {
        switch uiState {
        case .home:
            renderHome()
        case .modeSelect:
            uiRenderer.renderModeSelect(
                rows: ArenaMenuContent.modeRows(profile: runProfile, selectedMode: runSession.selectedMode),
                selectedMode: runSession.selectedMode,
                layout: currentLandscapeLayout()
            )
        case .awards:
            uiRenderer.renderAwards(
                rows: ArenaMenuContent.awardRows(profile: runProfile),
                unlockText: ArenaMenuContent.activeUnlockText(profile: runProfile),
                layout: currentLandscapeLayout()
            )
        case .weaponCodex:
            uiRenderer.renderWeaponCodex(
                rows: ArenaMenuContent.weaponCodexRows(profile: runProfile),
                layout: currentLandscapeLayout()
            )
        case .options:
            uiRenderer.renderOptions(
                settings: tiltSettingsStore.settings,
                options: localOptions,
                resetDataArmed: navigationState.isResetDataArmed,
                layout: currentLandscapeLayout()
            )
        case .developerTuning:
            renderDeveloperTuning()
        case .calibrationPreview:
            renderCalibrationPreview()
        default:
            return false
        }

        return true
    }

    func renderRunUI() {
        switch uiState {
        case .preRun:
            renderPreRun()
        case .activeGameplay:
            renderRunHUD(in: currentLandscapeLayout())
        case .pause:
            let summary = "SCORE \(runController.score)   \(formatSurvivalTime(runController.survivalTime))"
                + "   BEST \(selectedModeRecord.bestScore)"
            uiRenderer.renderPause(runSummary: summary, layout: currentLandscapeLayout())
        case .postRun:
            renderPostRun()
        default:
            break
        }
    }

    func renderRunHUD(in layout: ArenaLandscapeUILayout) {
        let frames = runHUDFrames(in: layout)
        guard frames.leading.height >= 7, frames.trailing.height >= 7 else {
            return
        }
        let scoreFontSize = min(11, max(7, frames.leading.height - 7))
        let bestFontSize = min(10, max(7, frames.trailing.height - 7))

        let scoreLabel = uiRenderer.makeLabel(
            "",
            at: CGPoint(x: frames.leading.minX + 10, y: frames.leading.midY),
            fontSize: scoreFontSize,
            color: theme.playerColor.withAlphaComponent(0.94),
            alignment: .left
        )
        scoreLabel.fontName = "Menlo-Bold"
        uiRoot.addChild(scoreLabel)
        runScoreLabel = scoreLabel

        let bestLabel = uiRenderer.makeLabel(
            "",
            at: CGPoint(x: frames.trailing.maxX - 10, y: frames.trailing.midY),
            fontSize: bestFontSize,
            color: theme.playerColor.withAlphaComponent(0.82),
            alignment: .right
        )
        uiRoot.addChild(bestLabel)
        runBestLabel = bestLabel
        updateRunHUD()
    }

    func runHUDFrames(
        in layout: ArenaLandscapeUILayout
    ) -> (leading: CGRect, trailing: CGRect) {
        let arenaBorderFrame = layout.gameplayWorldFrame.insetBy(
            dx: ArenaGeometry.arenaBorderInset * layout.gameplayWorldScale,
            dy: ArenaGeometry.arenaBorderInset * layout.gameplayWorldScale
        )
        let playableTop = layout.gameplayWorldFrame.minY + currentPlayableRect.maxY * layout.gameplayWorldScale
        let marginBottom = max(playableTop, arenaBorderFrame.maxY)
        let safeTop = max(
            marginBottom,
            size.height - max(0, layout.safeAreaInsets.top)
        )
        let availableHeight = max(0, safeTop - marginBottom)
        let height = min(20, max(0, availableHeight - 4))
        let y = marginBottom + (availableHeight - height) / 2
        let trailingWidth = min(126, layout.safeRect.width * 0.3)

        return (
            CGRect(
                x: layout.safeRect.minX - 6,
                y: y,
                width: min(190, layout.safeRect.width * 0.42),
                height: height
            ),
            CGRect(
                x: layout.safeRect.maxX - trailingWidth + 6,
                y: y,
                width: trailingWidth,
                height: height
            )
        )
    }

    func updatePersistentGameplayNodeVisibility() {
        let isVisible: Bool
        switch uiState {
        case .home, .preRun, .activeGameplay, .pause, .postRun:
            isVisible = true
        case .modeSelect, .awards, .weaponCodex, .options, .developerTuning, .calibrationPreview:
            isVisible = false
        }

        playerNode?.isHidden = !isVisible
        playerTrailNode?.isHidden = !isVisible
        flameTrailEffectNode.isHidden = !isVisible
    }

    func updateTiltReadoutDisplay(deltaTime: TimeInterval) {
        tiltReadoutUpdateTime += deltaTime
        guard tiltReadoutUpdateTime >= 0.12 else {
            return
        }

        updateTiltReadoutDisplay()
    }

    func updateTiltReadoutDisplay() {
        guard !tiltReadoutValueLabels.isEmpty else {
            return
        }

        tiltReadoutUpdateTime = 0
        let orientation = currentTiltScreenOrientation
        let rows = TiltReadoutFormatter.gameplayRows(
            for: tiltInputController.readout(orientation: orientation),
            fallbackOrientation: orientation
        )

        for (label, row) in zip(tiltReadoutValueLabels, rows) {
            label.text = row.value
        }
    }

    func renderHome() {
        let layout = currentLandscapeLayout()
        let bottomButtonSize = CGSize(width: 88, height: 44)
        let identityFrame = CGRect(
            x: layout.safeRect.minX,
            y: layout.safeRect.maxY - 118,
            width: min(178, layout.safeRect.width * 0.36),
            height: 108
        )
        uiRenderer.addHomeIdentity(
            mode: runSession.selectedMode,
            bestScore: selectedModeRecord.bestScore,
            statusMessage: currentGameCenterStatusMessage(),
            in: identityFrame
        )
        addPreviewThreats(in: currentGameplayBounds)
        uiRenderer.addHomePlayButton(layout: layout, bottomButtonSize: bottomButtonSize)
        uiRenderer.addHomeNavigationButtons(layout: layout, buttonSize: bottomButtonSize)
        #if DEBUG
        uiRenderer.addButton(
            "DEV",
            frame: CGRect(x: layout.safeRect.maxX - 70, y: layout.safeRect.maxY - 42, width: 70, height: 34),
            action: .openDeveloperTuning,
            style: .secondary
        )
        #endif
    }

    func renderDeveloperTuning() {
        uiRenderer.renderDeveloperTuning(
            menu: currentDeveloperTuningMenu(),
            tuning: gameTuning,
            layout: currentLandscapeLayout()
        )
    }

    func currentDeveloperTuningMenu() -> ArenaDeveloperTuningMenu {
        let contentFrame = uiRenderer.menuContentFrame(layout: currentLandscapeLayout())
        let layout = ArenaDeveloperTuningLayout(contentFrame: contentFrame)
        return navigationState.developerTuning.menu(tuning: gameTuning, pageSize: layout.pageSize)
    }

    func renderCalibrationPreview() {
        let layout = currentLandscapeLayout()
        addCalibrationPreviewWorld(layout: layout)

        let controlsFrame = calibrationControlsFrame(layout: layout)
        uiRenderer.addPanel(
            frame: controlsFrame,
            fill: theme.panelFillColor.withAlphaComponent(0.98)
        )
        addCalibrationHeader(in: controlsFrame)
        renderCalibrationControls(in: controlsFrame)
        let previewBounds = currentCalibrationPreviewBounds
        uiRenderer.addLabel(
            "LIVE TILT",
            at: CGPoint(x: previewBounds.maxX - 20, y: previewBounds.maxY - 24),
            fontSize: 10,
            color: theme.playerAccentColor,
            alignment: .right
        )
        uiRenderer.addLabel(
            "MOVE DEVICE TO TEST",
            at: CGPoint(x: previewBounds.maxX - 20, y: previewBounds.maxY - 42),
            fontSize: 9,
            color: theme.playerColor.withAlphaComponent(0.82),
            alignment: .right
        )
        uiRenderer.addSmallLabel(
            calibrationText,
            at: CGPoint(x: previewBounds.maxX - 20, y: previewBounds.minY + 20),
            color: theme.borderColor,
            alignment: .right
        )
    }

    func addCalibrationPreviewWorld(layout: ArenaLandscapeUILayout) {
        let worldNode = SKNode()
        worldNode.zPosition = ArenaUIZPosition.preview
        uiRoot.addChild(worldNode)

        let previewArena = ArenaThemeRenderer(theme: theme).makeArenaBackground(
            size: size,
            arenaRect: layout.gameplayRect
        )
        previewArena.zPosition = ArenaUIZPosition.preview
        worldNode.addChild(previewArena)
        worldNode.addChild(makeCalibrationRadarGuide(in: currentCalibrationPreviewBounds))

        let previewTrail = PlayerTrailNode(theme: theme)
        previewTrail.zPosition = ArenaUIZPosition.content
        worldNode.addChild(previewTrail)
        calibrationPreviewTrailNode = previewTrail

        let previewPlayer = PlayerCraftNode(
            theme: theme,
            visualRadius: calibrationPreviewMovementController.configuration.visualRadius
        )
        previewPlayer.zPosition = ArenaUIZPosition.progress
        worldNode.addChild(previewPlayer)
        calibrationPreviewPlayerNode = previewPlayer

        let state = calibrationPreviewMovementController.clampToArena(currentCalibrationPreviewBounds)
        applyCalibrationPreviewState(state, resetTrail: true)
    }

    var currentCalibrationPreviewBounds: CGRect {
        let layout = currentLandscapeLayout()
        let controlsFrame = calibrationControlsFrame(layout: layout)
        let minX = controlsFrame.maxX + 14
        return CGRect(
            x: minX,
            y: layout.gameplayRect.minY,
            width: max(0, layout.gameplayRect.maxX - minX),
            height: layout.gameplayRect.height
        )
    }

    func makeCalibrationRadarGuide(in bounds: CGRect) -> SKNode {
        let root = SKNode()
        root.zPosition = ArenaUIZPosition.preview
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) * 0.37

        for scale in [CGFloat(0.34), 0.68, 1] {
            let ring = SKShapeNode(circleOfRadius: radius * scale)
            ring.position = center
            ring.strokeColor = theme.playerAccentColor.withAlphaComponent(scale == 1 ? 0.54 : 0.22)
            ring.fillColor = .clear
            ring.lineWidth = scale == 1 ? 1.4 : 0.7
            root.addChild(ring)
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x - radius - 10, y: center.y))
        path.addLine(to: CGPoint(x: center.x + radius + 10, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - radius - 10))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius + 10))
        let crosshair = SKShapeNode(path: path)
        crosshair.strokeColor = theme.borderColor.withAlphaComponent(0.42)
        crosshair.lineWidth = 0.8
        root.addChild(crosshair)

        let neutral = SKShapeNode(circleOfRadius: 6)
        neutral.position = center
        neutral.fillColor = theme.pickupAmber.withAlphaComponent(0.16)
        neutral.strokeColor = theme.pickupAmber.withAlphaComponent(0.86)
        neutral.lineWidth = 1.5
        root.addChild(neutral)
        return root
    }

    func calibrationControlsFrame(layout: ArenaLandscapeUILayout) -> CGRect {
        let controlsWidth = min(226, max(202, layout.safeRect.width * 0.4))
        let controlsHeight = max(0, min(216, layout.safeRect.height - 20))
        return CGRect(
            x: layout.safeRect.minX + 10,
            y: layout.safeRect.maxY - controlsHeight - 10,
            width: controlsWidth,
            height: controlsHeight
        )
    }

    func addCalibrationHeader(in frame: CGRect) {
        uiRenderer.addBackButton(
            frame: CGRect(
                x: frame.minX + 12,
                y: frame.maxY - 46,
                width: 42,
                height: 34
            )
        )
        uiRenderer.addTitle(
            "CALIBRATE",
            at: CGPoint(x: frame.minX + 66, y: frame.maxY - 29)
        )
    }

    func renderCalibrationControls(in frame: CGRect) {
        let settings = tiltSettingsStore.settings
        let inset: CGFloat = 12
        uiRenderer.addButton(
            "SET NEUTRAL",
            frame: CGRect(x: frame.minX + inset, y: frame.maxY - 92, width: frame.width - inset * 2, height: 36),
            action: .calibrate,
            style: .primary,
            glyph: .radar,
            fontSize: 12
        )
        uiRenderer.addTiltSettingsControls(settings: settings, in: frame, style: .calibration)

        renderTiltReadout(in: CGRect(
            x: frame.minX + inset,
            y: frame.minY + 2,
            width: frame.width - inset * 2,
            height: 16
        ))
    }

    func renderTiltReadout(in frame: CGRect) {
        tiltReadoutValueLabels.removeAll()
        let rows = TiltReadoutFormatter.gameplayRows(
            for: nil,
            fallbackOrientation: currentTiltScreenOrientation
        )
        let columnWidth = frame.width / CGFloat(max(1, rows.count))

        for (index, row) in rows.enumerated() {
            let columnMinX = frame.minX + CGFloat(index) * columnWidth
            let title = row.title == "ORIENTATION" ? "ORIENT" : "INPUT"
            uiRenderer.addLabel(
                title,
                at: CGPoint(x: columnMinX, y: frame.midY),
                fontSize: 8,
                color: theme.borderColor,
                alignment: .left
            )
            let valueLabel = uiRenderer.makeLabel(
                row.value,
                at: CGPoint(x: columnMinX + columnWidth - 4, y: frame.midY),
                fontSize: 8,
                color: theme.playerAccentColor,
                alignment: .right
            )
            tiltReadoutValueLabels.append(valueLabel)
            uiRoot.addChild(valueLabel)
        }

        updateTiltReadoutDisplay()
    }

    func renderPreRun() {
        let layout = currentLandscapeLayout()
        renderRunHUD(in: layout)
        uiRenderer.addButton(
            "CAL",
            frame: CGRect(x: layout.safeRect.maxX - 112, y: layout.safeRect.maxY - 78, width: 48, height: 34),
            action: .openCalibrationPreview,
            style: .secondary
        )
        uiRenderer.addButton(
            "OPT",
            frame: CGRect(x: layout.safeRect.maxX - 54, y: layout.safeRect.maxY - 78, width: 54, height: 34),
            action: .openOptions,
            style: .secondary
        )
        addReadyStartCircle(at: readyStartPoint)
        addStatusLabel(
            readyHoldController.isRetry ? "RESTARTING" : "HOLD TO START",
            frame: CGRect(x: layout.safeRect.midX - 82, y: layout.safeRect.minY, width: 164, height: 28),
            color: theme.playerAccentColor
        )
        addStatusLabel(
            runSession.selectedMode.displayName,
            frame: CGRect(x: layout.safeRect.minX, y: layout.safeRect.minY, width: 112, height: 28),
            color: theme.playerAccentColor,
            glyph: .radar
        )
        addStatusLabel(
            calibrationText,
            frame: CGRect(x: layout.safeRect.maxX - 170, y: layout.safeRect.minY, width: 170, height: 28),
            color: theme.borderColor
        )
        updateReadyProgressDisplay(readyHoldController.state)
    }

    func addStatusLabel(
        _ text: String,
        frame: CGRect,
        color: SKColor,
        glyph: ArenaControlGlyph? = nil
    ) {
        if let glyph {
            uiRenderer.addControlGlyph(
                glyph,
                at: CGPoint(x: frame.minX + 14, y: frame.midY),
                radius: 6,
                color: color
            )
        }
        uiRenderer.addLabel(
            text,
            at: CGPoint(x: frame.midX + (glyph == nil ? 0 : 7), y: frame.midY),
            fontSize: 10,
            color: color,
            alignment: .center
        )
    }

    func renderPostRun() {
        let layout = currentLandscapeLayout()
        uiRenderer.addScrim(alpha: 0.72)
        uiRenderer.addCornerAccents(
            frame: layout.safeRect,
            color: theme.playerAccentColor.withAlphaComponent(0.72)
        )
        let summary = runController.finalizedSummary

        renderPostRunScore(summary: summary, layout: layout)
        addDeathReplayTrace()
        addDeathClarityMarker(
            snapshot: runSession.lastDeathCollisionSnapshot,
            fallbackPosition: movementController.state.position
        )
        let highlights = Array(ArenaMenuContent.postRunHighlights(
            summary: summary,
            profile: runProfile,
            previousBestScore: runSession.previousBestScore,
            progressionResult: runSession.progressionResult
        ).dropFirst())
        uiRenderer.addPostRunHighlights(highlights, frame: postRunHighlightsFrame(layout: layout))
        uiRenderer.addPostRunButtons(layout: layout)
    }

    func postRunHighlightsFrame(layout: ArenaLandscapeUILayout) -> CGRect {
        let baseFrame = layout.rightColumnFrame(width: 230)
        let topY = layout.safeRect.maxY - 32
        let bottomY = layout.lowerRightButtonFrame.maxY + 12
        return CGRect(
            x: baseFrame.minX,
            y: min(bottomY, topY),
            width: baseFrame.width,
            height: max(0, topY - bottomY)
        )
    }

    func renderPostRunScore(summary: RunSummary?, layout: ArenaLandscapeUILayout) {
        uiRenderer.addLabel(
            "RUN OVER",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 34),
            fontSize: 28,
            color: theme.enemyColor,
            alignment: .left
        )
        uiRenderer.addLabel(
            "\(summary?.score ?? runController.score)",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 88),
            fontSize: 48,
            color: theme.playerColor,
            alignment: .left
        )
        uiRenderer.addLabel(
            summary?.score ?? 0 > runSession.previousBestScore ? "NEW BEST" : "BEST \(selectedModeRecord.bestScore)",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 126),
            fontSize: 11,
            color: theme.playerAccentColor,
            alignment: .left
        )
        renderGameCenterStatusMessage(
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 146),
            alignment: .left
        )
    }

    func renderGameCenterStatusMessage(
        at position: CGPoint,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        uiRenderer.addGameCenterStatusMessage(
            currentGameCenterStatusMessage(),
            at: position,
            alignment: alignment
        )
    }

    func perform(_ action: ArenaControlAction) {
        switch action {
        case .play,
                .playAgain,
                .openModes,
                .openAwards,
                .openWeaponCodex,
                .openOptions,
                .openDeveloperTuning,
                .openCalibrationPreview,
                .home,
                .back:
            performNavigationAction(action)
        case .selectMode, .resume, .calibrate, .endRun:
            performRunControlAction(action)
        case .openDiagnostics:
            openDiagnostics()
        case .openClassicLeaderboard:
            requestClassicLeaderboard()
        case .sensitivityDown, .sensitivityUp, .preset, .toggleAudio, .toggleHaptics, .selectTheme, .resetData:
            performOptionsAction(action)
        case .developerTuningPreviousPage,
                .developerTuningNextPage,
                .selectTuningGroup,
                .selectTuningSubgroup,
                .toggleDeveloperTuningChangedOnly,
                .adjustTuningParameter,
                .copyTuningParameters,
                .resetTuningParameters:
            performDeveloperTuningAction(action)
        }
    }

    func requestClassicLeaderboard() {
        let result = gameCenterDelegate?.arenaSceneRequestsClassicLeaderboard(self)
            ?? .unavailable(.unsupported)
        switch result {
        case .presented:
            navigationState.gameCenterStatusMessage = nil
        case let .unavailable(reason):
            navigationState.gameCenterStatusMessage = reason.gameplayStatusMessage
            rebuildUI()
        }
    }

    func currentGameCenterStatusMessage() -> String? {
        guard uiState == .home || uiState == .postRun else {
            return nil
        }

        return navigationState.gameCenterStatusMessage
            ?? gameCenterDelegate?.arenaSceneGameCenterMenuStatus(self).menuMessage
    }

    func performNavigationAction(_ action: ArenaControlAction) {
        switch action {
        case .play where selectedModeIsAvailable:
            preparePreRun()
        case .playAgain where uiState == .postRun:
            preparePreRun(isRetry: true)
        case .openModes, .openAwards, .openWeaponCodex:
            openMenu(action)
        case .openOptions:
            navigationState.prepareOptionsPresentation()
            show(.options)
        case .openDeveloperTuning:
            navigationState.prepareDeveloperTuningPresentation()
            show(.developerTuning)
        case .openCalibrationPreview:
            enterCalibrationPreview()
        case .home:
            resetMenuPreviewIfNeeded()
            show(.home)
        case .back:
            performBackNavigation()
        default:
            break
        }
    }

    func openMenu(_ action: ArenaControlAction) {
        switch action {
        case .openModes:
            resetMenuPreviewIfNeeded()
            show(.modeSelect)
        case .openAwards:
            show(.awards)
        case .openWeaponCodex:
            show(.weaponCodex)
        default:
            break
        }
    }

    func performBackNavigation() {
        if uiState == .calibrationPreview {
            tiltInputController.resetSmoothedInput()
        }
        show(navigationState.prepareBackNavigation())
    }

    func performRunControlAction(_ action: ArenaControlAction) {
        switch action {
        case let .selectMode(mode):
            guard modeRowsByKind[mode]?.isAvailable == true else {
                runLogger.warning("run.mode_selection_rejected", metadata: [
                    "mode": "\(mode.rawValue)",
                    "reason": "unavailable"
                ])
                return
            }

            runSession.selectMode(mode)
            runLogger.info("run.mode_selected", metadata: [
                "mode": "\(mode.rawValue)"
            ])
            rebuildUI()
        case .resume:
            resumeRun()
        case .calibrate:
            recalibrateTiltControls()
        case .endRun:
            finishRun(playFeedback: false)
        default:
            break
        }
    }

    func performOptionsAction(_ action: ArenaControlAction) {
        switch action {
        case .sensitivityDown:
            updateSensitivity(by: -0.1)
        case .sensitivityUp:
            updateSensitivity(by: 0.1)
        case let .preset(preset):
            tiltSettingsStore.selectPreset(preset)
            tiltInputController.resetSmoothedInput()
            if uiState == .calibrationPreview {
                resetCalibrationPreviewPosition()
            }
            rebuildUI()
        case .toggleAudio, .toggleHaptics:
            performLocalOptionToggle(action)
        case .selectTheme, .resetData:
            performLocalDataAction(action)
        default:
            break
        }
    }

    func performDeveloperTuningAction(_ action: ArenaControlAction) {
        switch action {
        case .developerTuningPreviousPage:
            navigationState.developerTuning.moveToPreviousPage()
            rebuildUI()
        case .developerTuningNextPage:
            advanceDeveloperTuningPage()
        case let .selectTuningGroup(group):
            navigationState.developerTuning.selectGroup(group)
            rebuildUI()
        case let .selectTuningSubgroup(subgroup):
            navigationState.developerTuning.selectSubgroup(subgroup)
            rebuildUI()
        case .toggleDeveloperTuningChangedOnly:
            navigationState.developerTuning.toggleChangedOnly()
            rebuildUI()
        case let .adjustTuningParameter(parameterID, direction):
            adjustDeveloperTuningParameter(id: parameterID, direction: direction)
        case .copyTuningParameters:
            copyChangedTuningParameters()
        case .resetTuningParameters:
            resetTuningParameters()
        default:
            break
        }
    }

    func advanceDeveloperTuningPage() {
        let menu = currentDeveloperTuningMenu()
        navigationState.developerTuning.moveToNextPage(lastPageIndex: menu.pageCount - 1)
        rebuildUI()
    }

    func adjustDeveloperTuningParameter(id parameterID: String, direction: GameTuningAdjustmentDirection) {
        let oldPlayerRadius = gameTuning.playerMovement.visualRadius
        gameTuning.adjustParameter(id: parameterID, direction: direction)
        gameTuningStore.tuning = gameTuning
        let didChangePlayerRadius = oldPlayerRadius != gameTuning.playerMovement.visualRadius
        applyGameTuning(rebuildPlayerVisuals: didChangePlayerRadius)
        navigationState.developerTuning.confirmation = nil
        rebuildArena()
        rebuildUI()
    }

    func copyChangedTuningParameters() {
        let changedCount = gameTuning.changedParameters().count
        UIPasteboard.general.string = gameTuning.sourceSnapshot(changedOnly: true)
        navigationState.developerTuning.confirmation = "COPIED \(changedCount)"
        appLogger.info("dev.tuning_copied", metadata: [
            "parameters": "\(changedCount)"
        ])
        rebuildUI()
    }

    func resetTuningParameters() {
        gameTuningStore.reset()
        gameTuning = .defaults
        navigationState.developerTuning.reset(confirmation: "RESET")
        applyGameTuning(rebuildPlayerVisuals: true)
        rebuildArena()
        rebuildUI()
        appLogger.notice("dev.tuning_reset")
    }

    func performLocalOptionToggle(_ action: ArenaControlAction) {
        switch action {
        case .toggleAudio:
            localOptions.audioEnabled.toggle()
            localOptionsStore.options = localOptions
            syncAudioOption()
            appLogger.info("options.audio_changed", metadata: [
                "enabled": "\(localOptions.audioEnabled)"
            ])
            rebuildUI()
        case .toggleHaptics:
            localOptions.hapticsEnabled.toggle()
            localOptionsStore.options = localOptions
            syncHapticsOption()
            appLogger.info("options.haptics_changed", metadata: [
                "enabled": "\(localOptions.hapticsEnabled)"
            ])
            rebuildUI()
        default:
            break
        }
    }

    func performLocalDataAction(_ action: ArenaControlAction) {
        switch action {
        case let .selectTheme(themeKind):
            guard localOptions.themeKind != themeKind else {
                return
            }

            localOptions.themeKind = themeKind
            localOptionsStore.options = localOptions
            appLogger.notice("options.theme_changed", metadata: [
                "theme": "\(themeKind.rawValue)"
            ])
            applyThemeChange()
        case .resetData:
            resetLocalDataOrArmConfirmation()
        default:
            break
        }
    }

    func updateSensitivity(by delta: Double) {
        tiltSettingsStore.updateSensitivity(tiltSettingsStore.settings.clampedSensitivity + delta)
        tiltInputController.resetSmoothedInput()
        rebuildUI()
    }

    func openDiagnostics() {
        appLogger.info("diagnostics.presentation_requested")
        diagnosticsDelegate?.arenaSceneRequestsDiagnosticsPresentation(self, snapshot: diagnosticSnapshot())
    }

    func resetMenuPreviewIfNeeded() {
        guard uiState == .postRun || runController.phase == .gameOver else {
            return
        }

        runController = ClassicRunController(configuration: runController.configuration)
        resetGameplayObjects()
        readyHoldController.reset()
        runSession.clearDeathPresentation()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
    }

    var selectedModeIsAvailable: Bool {
        modeRowsByKind[runSession.selectedMode]?.isAvailable == true
    }

    var modeRowsByKind: [ArenaModeKind: ArenaModeRow] {
        Dictionary(
            uniqueKeysWithValues: ArenaMenuContent
                .modeRows(profile: runProfile, selectedMode: runSession.selectedMode)
                .map { ($0.kind, $0) }
        )
    }

    var calibrationText: String {
        "\(uiRenderer.presetDisplayTitle(tiltSettingsStore.settings.calibration.preset)) CALIBRATION"
    }

    func resetLocalDataOrArmConfirmation() {
        guard navigationState.isResetDataArmed else {
            navigationState.isResetDataArmed = true
            rebuildUI()
            return
        }

        runProfileStore.reset()
        tiltSettingsStore.reset()
        localOptionsStore.reset()
        runProfile = RunProfile()
        localOptions = .defaults
        syncAudioOption()
        syncHapticsOption()
        runSession.resetProfileSelection()
        navigationState.isResetDataArmed = false
        profileLogger.warning("profile.reset")
        applyThemeChange()
    }

    func logFinishedRun(isNewBest: Bool) {
        guard let summary = runController.finalizedSummary else {
            runLogger.error("run.finished_missing_summary")
            return
        }

        for event in balanceAccumulator.events(
            summary: summary, score: runController.scoreBreakdown,
            experimental: balanceExperimentalTuning, arenaSize: currentGameplayBounds.size,
            unlockedWeapons: balanceStartingUnlockCount
        ) {
            runLogger.info("\(event.name)", metadata: event.metadata)
        }
        runLogger.notice("run.finished", metadata: [
            "run_id": "\(balanceAccumulator.runID)",
            "mode": "\(summary.mode.rawValue)",
            "seed": "\(summary.sequenceSeed)",
            "rules_version": "\(summary.rulesVersion)",
            "score": "\(summary.score)",
            "survivalTime": "\(summary.survivalTime)",
            "maxCombo": "\(summary.maxCombo)",
            "enemiesDestroyed": "\(summary.enemiesDestroyed)",
            "bestWeapon": "\(summary.bestWeapon?.rawValue ?? "none")",
            "newBest": "\(isNewBest)"
        ])
    }

    func diagnosticSnapshot() -> DiagnosticGameplaySnapshot {
        DiagnosticGameplaySnapshot(
            uiState: uiState.diagnosticName,
            selectedMode: runSession.selectedMode.rawValue,
            runPhase: runController.phase.diagnosticName,
            score: runController.score,
            survivalTime: runController.survivalTime,
            enemyCount: enemies.count,
            pickupCount: pickups.count,
            localOptions: DiagnosticLocalOptionsSnapshot(
                audioEnabled: localOptions.audioEnabled,
                hapticsEnabled: localOptions.hapticsEnabled,
                theme: localOptions.themeKind.rawValue
            ),
            profile: DiagnosticProfileSnapshot(
                bestScore: runProfile.lifetimeBestScore,
                highestCombo: runProfile.lifetimeHighestCombo,
                longestSurvivalTime: runProfile.lifetimeLongestSurvivalTime,
                totalRuns: runProfile.totalRuns,
                totalEnemiesDestroyed: runProfile.totalEnemiesDestroyed,
                unlockedWeaponCount: runProfile.unlockedWeapons.count,
                earnedAwardCount: runProfile.earnedAwardIDs.count
            )
        )
    }

    func addReadyStartCircle(at point: CGPoint) {
        let radius = readyHoldController.configuration.effectiveStartCircleRadius
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.position = point
        circle.zPosition = ArenaUIZPosition.content
        circle.strokeColor = theme.playerAccentColor.withAlphaComponent(0.68)
        circle.fillColor = theme.playerAccentColor.withAlphaComponent(0.04)
        circle.lineWidth = 2
        circle.glowWidth = 1
        addGameplayOverlayNode(circle)

        let progress = SKShapeNode(circleOfRadius: radius + 8)
        progress.position = point
        progress.zPosition = ArenaUIZPosition.progress
        progress.strokeColor = theme.playerColor.withAlphaComponent(0.66)
        progress.fillColor = .clear
        progress.lineWidth = 2
        progress.glowWidth = 0.65
        addGameplayOverlayNode(progress)
        readyProgressRing = progress

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 11
        label.fontColor = theme.playerColor
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: point.x, y: point.y - 30)
        label.zPosition = ArenaUIZPosition.label
        addGameplayOverlayNode(label)
        readyStatusLabel = label

        let instruction = uiRenderer.makeLabel(
            readyHoldController.isRetry ? "GET READY" : "HOLD TO LAUNCH",
            at: CGPoint(x: point.x, y: point.y + 30),
            fontSize: 10,
            color: theme.playerAccentColor,
            alignment: .center
        )

        addGameplayOverlayNode(instruction)

        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 2) {
            let tick = SKShapeNode(rectOf: CGSize(width: 3, height: 12), cornerRadius: 1)
            tick.position = CGPoint(
                x: point.x + cos(angle) * (radius + 16),
                y: point.y + sin(angle) * (radius + 16)
            )
            tick.zRotation = angle
            tick.zPosition = ArenaUIZPosition.content
            tick.fillColor = theme.borderColor.withAlphaComponent(0.75)
            tick.strokeColor = .clear
            addGameplayOverlayNode(tick)
        }
    }

    func updateReadyProgressDisplay(_ state: ReadyStartHoldState) {
        let requiredDuration = readyHoldController.requiredDuration
        let progress = state.progressFraction(requiredDuration: requiredDuration)
        readyProgressRing?.setScale(0.55 + CGFloat(progress) * 0.45)
        readyProgressRing?.alpha = 0.35 + CGFloat(progress) * 0.65

        if state.isInsideCircle {
            let remaining = max(0, requiredDuration - state.elapsed)
            readyStatusLabel?.text = String(format: readyHoldController.isRetry ? "GO IN %.1fs" : "HOLD %.1fs", remaining)
        } else {
            readyStatusLabel?.text = "CENTER CRAFT"
        }
    }

    func addPreviewThreats(in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let offsets = [
            CGPoint(x: -120, y: 52),
            CGPoint(x: 104, y: 42),
            CGPoint(x: 44, y: -2),
            CGPoint(x: -116, y: -28)
        ]

        for offset in offsets {
            let dot = SKShapeNode(circleOfRadius: 6)
            dot.position = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            dot.zPosition = ArenaUIZPosition.preview
            dot.fillColor = theme.enemyColor.withAlphaComponent(0.5)
            dot.strokeColor = theme.enemyColor.withAlphaComponent(0.75)
            dot.lineWidth = 1
            addGameplayOverlayNode(dot)
        }

        let pickup = SKShapeNode(circleOfRadius: 9)
        pickup.position = CGPoint(x: center.x + 52, y: center.y - 36)
        pickup.zPosition = ArenaUIZPosition.preview
        pickup.fillColor = theme.pickupAmber.withAlphaComponent(0.25)
        pickup.strokeColor = theme.pickupAmber
        pickup.lineWidth = 2
        addGameplayOverlayNode(pickup)
    }

    func addDeathReplayTrace() {
        guard runSession.deathReplayTrace.samples.count >= 2 else {
            return
        }

        let path = CGMutablePath()
        path.move(to: runSession.deathReplayTrace.samples[0].position)
        for sample in runSession.deathReplayTrace.samples.dropFirst() {
            path.addLine(to: sample.position)
        }

        let line = SKShapeNode(path: path)
        line.zPosition = ArenaUIZPosition.content
        line.strokeColor = theme.playerAccentColor.withAlphaComponent(0.3)
        line.lineWidth = 2
        line.glowWidth = theme.kind == .darkTacticalRadar ? 0.45 : 0
        addGameplayOverlayNode(line)
    }

    func addDeathClarityMarker(snapshot: DeathCollisionSnapshot?, fallbackPosition: CGPoint) {
        let position = snapshot?.playerPosition ?? fallbackPosition
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = position
        ring.zPosition = ArenaUIZPosition.content
        ring.strokeColor = theme.enemyColor.withAlphaComponent(0.68)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 0.85
        addGameplayOverlayNode(ring)

        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: position.x - 22, y: position.y))
        crossPath.addLine(to: CGPoint(x: position.x + 22, y: position.y))
        crossPath.move(to: CGPoint(x: position.x, y: position.y - 22))
        crossPath.addLine(to: CGPoint(x: position.x, y: position.y + 22))
        let cross = SKShapeNode(path: crossPath)
        cross.strokeColor = theme.enemyColor
        cross.lineWidth = 1.5
        cross.zPosition = ArenaUIZPosition.content
        addGameplayOverlayNode(cross)

        guard let snapshot else {
            return
        }

        let enemy = SKShapeNode(circleOfRadius: snapshot.enemyRadius + 4)
        enemy.position = snapshot.enemyPosition
        enemy.zPosition = ArenaUIZPosition.content
        enemy.strokeColor = theme.enemyColor.withAlphaComponent(0.68)
        enemy.fillColor = theme.enemyColor.withAlphaComponent(0.09)
        enemy.lineWidth = 1.5
        enemy.glowWidth = theme.kind == .darkTacticalRadar ? 0.65 : 0
        addGameplayOverlayNode(enemy)

        let impactPath = CGMutablePath()
        impactPath.move(to: snapshot.playerPosition)
        impactPath.addLine(to: snapshot.enemyPosition)
        let impactLine = SKShapeNode(path: impactPath)
        impactLine.zPosition = ArenaUIZPosition.content
        impactLine.strokeColor = theme.enemyColor.withAlphaComponent(0.55)
        impactLine.lineWidth = 1.2
        addGameplayOverlayNode(impactLine)
    }

}

#if DEBUG
// MARK: - Test support

extension ArenaScene {
    func prepareForVisualSnapshot(
        state: ArenaUISceneState,
        profile: RunProfile = RunProfile(),
        localOptions: ArenaLocalOptions = .defaults,
        selectedMode: ArenaModeKind = .classic,
        resetDataArmed: Bool = false
    ) {
        self.runProfile = profile
        self.localOptions = localOptions
        runSession.prepareSnapshot(selectedMode: selectedMode)
        navigationState.resetForSnapshot(resetDataArmed: resetDataArmed)
        gameTuning = .defaults
        applyGameTuning(rebuildPlayerVisuals: true)
        runController = ClassicRunController()
        readyHoldController.reset()
        resetGameplayObjects()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
        syncAudioOption()
        syncHapticsOption()
        applyThemeChange()
        debugStatsLabel.isHidden = true

        if state == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }

        show(state)
    }

    func prepareRunStateVisualSnapshot(
        state: ArenaUISceneState,
        profile: RunProfile = RunProfile(),
        localOptions: ArenaLocalOptions = .defaults,
        selectedMode: ArenaModeKind = .classic
    ) {
        prepareForVisualSnapshot(
            state: .home,
            profile: profile,
            localOptions: localOptions,
            selectedMode: selectedMode
        )

        switch state {
        case .preRun:
            preparePreRun()
        case .activeGameplay:
            prepareSeededRunVisualSnapshot(profile: profile, selectedMode: selectedMode)
            show(.activeGameplay)
        case .pause:
            prepareSeededRunVisualSnapshot(profile: profile, selectedMode: selectedMode)
            runController.pause()
            setWeaponEffectPlaybackPaused(true)
            show(.pause)
        case .postRun:
            prepareSeededRunVisualSnapshot(profile: profile, selectedMode: selectedMode)
            finishSeededRunVisualSnapshot(profile: profile)
            show(.postRun)
        case .home, .modeSelect, .awards, .weaponCodex, .options, .developerTuning, .calibrationPreview:
            show(state)
        }
    }

    private func prepareSeededRunVisualSnapshot(profile: RunProfile, selectedMode: ArenaModeKind) {
        self.runProfile = profile
        runSession.prepareSnapshot(
            selectedMode: selectedMode,
            previousBestScore: profile.competitiveRecord(for: selectedMode).bestScore
        )
        resetGameplayObjects()
        runController = ClassicRunController(configuration: runController.configuration)
        runController.start(context: ArenaRunContext(mode: selectedMode, sequenceSeed: weaponRuntime.initialSeed))
        runController.update(deltaTime: 38.4)
        _ = runController.recordItemPickup(pickupID: 1)
        runController.recordEnemyKills(count: 14, weaponKind: .chainLightning)
        seedDeathReplayTraceForSnapshot()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
    }

    private func finishSeededRunVisualSnapshot(profile: RunProfile) {
        runController.endRun(at: Date(timeIntervalSince1970: 1_800))
        guard let summary = runController.finalizedSummary else {
            return
        }

        var updatedProfile = profile
        let result = updatedProfile.record(summary)
        runProfile = updatedProfile

        let playerPosition = movementController.state.position
        let collision = DeathCollisionSnapshot(
            playerPosition: playerPosition,
            enemyPosition: CGPoint(x: playerPosition.x + 24, y: playerPosition.y - 10),
            enemyRadius: 12
        )
        runSession.finishSnapshot(progressionResult: result, collision: collision)
    }

    private func seedDeathReplayTraceForSnapshot() {
        let playerPosition = movementController.state.position
        let samples = [
            CGPoint(x: playerPosition.x - 82, y: playerPosition.y - 42),
            CGPoint(x: playerPosition.x - 54, y: playerPosition.y - 24),
            CGPoint(x: playerPosition.x - 18, y: playerPosition.y - 12),
            playerPosition
        ]

        for (index, position) in samples.enumerated() {
            runSession.deathReplayTrace.record(
                time: runController.survivalTime - TimeInterval(samples.count - index) * 0.35,
                position: position
            )
        }
    }

    func prepareEffectSnapshotForTesting(themeKind: ArenaThemeKind) {
        localOptions = ArenaLocalOptions(
            audioEnabled: false,
            hapticsEnabled: false,
            themeKind: themeKind
        )
        backgroundColor = theme.backgroundColor
        removeAllActions()
        removeAllChildren()
        gameplayRoot.removeAllChildren()
        playerNode = nil
        playerTrailNode = nil
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(
            size: ArenaGeometry.logicalGameplayBounds.size,
            arenaRect: currentGameplayBounds
        )
        addGameplayNode(arenaRoot)
        clearWeaponEffectNodes()
    }

    func revealWeaponEffectsForSnapshotTesting() {
        revealSnapshotEffectNode(weaponEffectsRoot)
    }

    private func revealSnapshotEffectNode(_ node: SKNode) {
        for child in node.children {
            child.removeAllActions()
            if child.alpha == 0 {
                child.alpha = 1
            }
            revealSnapshotEffectNode(child)
        }
    }

    func prepareActiveRunForTesting(mode: ArenaModeKind = .classic, sequenceSeed: Int? = nil) {
        localOptions = ArenaLocalOptions(
            audioEnabled: false,
            hapticsEnabled: false,
            themeKind: localOptions.themeKind
        )
        syncAudioOption()
        syncHapticsOption()
        runSession.selectMode(mode)
        applySelectedModeTuning()
        preparePreRun()
        startRun(sequenceSeed: sequenceSeed)
    }

    func prepareBalanceRunForTesting(
        tuning: GameTuningConfiguration, seed: Int, profile: RunProfile = RunProfile(), mode: ArenaModeKind = .classic
    ) {
        runProfile = profile
        runProfileStore.profile = profile
        gameTuning = tuning
        applyGameTuning()
        rebuildArena()
        configureWeaponEffectsRoot()
        configureUIRoot()
        if flameTrailEffectNode.parent == nil { addGameplayNode(flameTrailEffectNode) }
        prepareActiveRunForTesting(mode: mode, sequenceSeed: seed)
        lastUpdateTime = nil
    }

    func seedBalanceEnemiesForTesting(_ enemies: [ArenaEnemy]) {
        spawnDirector.nextEnemyID = max(spawnDirector.nextEnemyID, (enemies.map(\.id).max() ?? 0) + 1)
        addSpawnedEnemies(enemies)
    }

    func retryRunForTesting() {
        performNavigationAction(.playAgain)
    }

    func prepareRetryForSnapshotTesting() {
        preparePreRun(isRetry: true)
    }

    var pickupCountForTesting: Int {
        pickups.count
    }

    var enemiesForTesting: [ArenaEnemy] { enemies }
    var pickupsForTesting: [WeaponPickup] { pickups }
    var scoreForTesting: Int { runController.score }
    var maxComboForTesting: Int { runController.maxCombo }
    var enemiesDestroyedForTesting: Int { runController.enemiesDestroyed }
    var balanceForTesting: ArenaBalanceAccumulator { balanceAccumulator }
    var scoreBreakdownForTesting: RunScoreBreakdown { runController.scoreBreakdown }
    var gameplayChildrenForTesting: [SKNode] { gameplayRoot.children }

    func screenPositionForTesting(_ point: CGPoint) -> CGPoint {
        gameplayRoot.convert(point, to: self)
    }

    func pauseRunForTesting() {
        pauseRun()
    }

    func resumeRunForTesting() {
        resumeRun()
    }

    func finishRunForTesting() {
        finishRun(playFeedback: false)
    }

    func finishRunWithFeedbackForTesting() {
        finishRun(playFeedback: true)
    }

    func grantPostWeaponSafetyForTesting(
        _ weaponKind: WeaponKind = .chainLightning,
        minimumDuration: TimeInterval = 0
    ) {
        grantPostWeaponSafety(for: weaponKind, minimumDuration: minimumDuration)
    }

    func advancePostWeaponSafetyForTesting(deltaTime: TimeInterval) {
        updatePostWeaponSafety(deltaTime: deltaTime)
    }

    func detectPlayerCollisionForTesting(playerPosition: CGPoint) {
        detectPlayerCollision(playerPosition: playerPosition)
    }

    func detectPlayerCollisionForTesting(
        playerPosition: CGPoint,
        previousPlayerPosition: CGPoint,
        previousDamageableEnemyPositions: [Int: CGPoint],
        allowsSweptCollision: Bool = true
    ) {
        detectPlayerCollision(
            playerPosition: playerPosition,
            previousPlayerPosition: previousPlayerPosition,
            previousDamageableEnemyPositions: previousDamageableEnemyPositions,
            allowsSweptCollision: allowsSweptCollision
        )
    }

    func collectWeaponForTesting(_ kind: WeaponKind, id: Int = 1, tier: WeaponPickupChargeTier = .base) {
        let age: TimeInterval = tier == .base ? 0 : (tier == .charged ? 3 : 6)
        let pickup = WeaponPickup(id: id, kind: kind, position: movementController.state.position,
                                  radius: 8, timeOnScreen: age, chargeTier: tier)
        _ = pickupRegistry.add([pickup], to: gameplayRoot, theme: theme)
        _ = collectPickups(playerPosition: movementController.state.position)
    }

    var postWeaponSafetyRemainingForTesting: TimeInterval {
        activeWeapons.postWeaponSafety.timeRemaining
    }

    func activateRazorShieldForTesting(configuration: StartingWeaponConfiguration) {
        activateRazorShield(
            at: movementController.state.position,
            configuration: configuration
        )
    }

    func updateRazorShieldForTesting(deltaTime: TimeInterval) {
        updateRazorShield(
            deltaTime: deltaTime,
            playerPosition: movementController.state.position
        )
    }

    func activateTimeDilationAuraForTesting(configuration: StartingWeaponConfiguration) {
        activateTimeDilationAura(
            at: movementController.state.position,
            configuration: configuration
        )
    }

    func activateFlameTrailForTesting(configuration: FlameTrailConfiguration) {
        activeWeapons.flameTrail.configuration = configuration
        activeWeapons.flameTrail.activate(at: movementController.state.position)
    }

    func updateFlameTrailForTesting(deltaTime: TimeInterval) {
        updateFlameTrail(
            deltaTime: deltaTime,
            playerPosition: movementController.state.position
        )
    }

    func activateNovaBombForTesting(enemyIDs: Set<Int>) {
        playNovaBomb(enemyIDs: enemyIDs)
    }

    func updateActiveRunForTesting(deltaTime: TimeInterval) {
        updateActiveRun(
            deltaTime: deltaTime,
            playerPosition: movementController.state.position,
            previousPlayerPosition: movementController.state.position
        )
    }

    var isRazorShieldActiveForTesting: Bool {
        activeWeapons.razorShield.isActive || razorShieldNode != nil
    }

    var isTimeDilationAuraActiveForTesting: Bool {
        activeWeapons.timeDilation.isActive || timeDilationAuraNode != nil
    }

    var isPostWeaponSafeForTesting: Bool {
        isPostWeaponSafe
    }

    var showsCollisionProtectionForTesting: Bool {
        playerNode?.showsCollisionProtection ?? false
    }

    func addWeaponEffectNodeForTesting(_ node: SKNode) {
        addWeaponEffectNode(node)
    }

    func addEnemyForTesting(_ enemy: ArenaEnemy) {
        addSpawnedEnemies([enemy])
    }

    func removeEnemyForTesting(id enemyID: Int) {
        removeEnemies(ids: [enemyID])
    }

    func destroyEnemiesForTesting(
        ids enemyIDs: Set<Int>, weaponKind: WeaponKind, activation: WeaponActivation? = nil
    ) {
        destroyEnemies(ids: enemyIDs, weaponKind: weaponKind, activation: activation)
    }

    func freezeEnemiesForTesting(
        ids enemyIDs: Set<Int>,
        duration: TimeInterval,
        thawGraceDuration: TimeInterval = 0,
        activation: WeaponActivation = WeaponActivation(kind: .freezeBurst)
    ) {
        freezeEnemies(
            ids: enemyIDs,
            duration: duration,
            thawGraceDuration: thawGraceDuration,
            activation: activation
        )
    }

    func shatterFrozenContactEnemiesForTesting() {
        shatterFrozenContactEnemies(playerPosition: movementController.state.position)
    }

    func playSeekerSwarmForTesting(enemyIDs: Set<Int>, from playerPosition: CGPoint) {
        playSeekerSwarm(
            enemyIDs: enemyIDs,
            from: playerPosition,
            configuration: weaponResolver.configuration
        )
    }

    func activateGravityWellForTesting(
        center: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        activateGravityWell(at: center, configuration: configuration)
    }

    func updateGravityWellForTesting(deltaTime: TimeInterval) {
        updateGravityWell(deltaTime: deltaTime)
    }

    func enemyPositionForTesting(id: Int) -> CGPoint? {
        enemyRegistry.enemy(id: id)?.position
    }

    func resolveSeekerExplosionForTesting(at target: WeaponImpactTarget) {
        resolveSeekerExplosion(at: target, resolver: weaponResolver)
    }

    var enemyIDsForTesting: Set<Int> {
        Set(enemies.map(\.id))
    }

    var frozenEnemyIDsForTesting: Set<Int> {
        Set(enemies.filter(\.isFrozen).map(\.id))
    }

    var enemyNodeCountForTesting: Int {
        enemyRegistry.nodeCount
    }

    var playerPositionForTesting: CGPoint {
        movementController.state.position
    }

    var isRunGameOverForTesting: Bool {
        runController.phase == .gameOver
    }

    var isRunPausedForTesting: Bool {
        runController.phase == .paused
    }

    var runSurvivalTimeForTesting: TimeInterval {
        runController.survivalTime
    }

    var runScoreTextForTesting: String? {
        runScoreLabel?.text
    }

    var runBestTextForTesting: String? {
        runBestLabel?.text
    }

    var runScorePositionForTesting: CGPoint? {
        runScoreLabel?.position
    }

    var runBestPositionForTesting: CGPoint? {
        runBestLabel?.position
    }

    var runHUDFramesForTesting: (leading: CGRect, trailing: CGRect) {
        runHUDFrames(in: currentLandscapeLayout())
    }

    var uiStateForTesting: ArenaUISceneState {
        uiState
    }

    var isResolvingDeathForTesting: Bool {
        runSession.isResolvingDeath
    }

    var lastDeathCollisionSnapshotForTesting: DeathCollisionSnapshot? {
        runSession.lastDeathCollisionSnapshot
    }

    var isWeaponEffectPlaybackPausedForTesting: Bool {
        weaponEffectsRoot.isPaused
    }

    var weaponEffectNodeCountForTesting: Int {
        weaponEffectsRoot.children.count
    }

    var developerTuningPageIndexForTesting: Int {
        navigationState.developerTuning.pageIndex
    }

    var devTuningPageCountForTesting: Int {
        currentDeveloperTuningMenu().pageCount
    }

    var playerHitRadiusForTesting: CGFloat {
        runController.configuration.playerHitRadius
    }

    var playerVisualRadiusForTesting: CGFloat {
        movementController.configuration.visualRadius
    }

    func openDeveloperTuningForTesting() {
        performNavigationAction(.openDeveloperTuning)
    }

    var classicLeaderboardButtonCountForTesting: Int {
        uiRenderer.hitTargets.filter { $0.action == .openClassicLeaderboard }.count
    }

    var gameCenterStatusMessageForTesting: String? {
        currentGameCenterStatusMessage()
    }

    func requestClassicLeaderboardForTesting() {
        perform(.openClassicLeaderboard)
    }

    func advanceDeveloperTuningPageForTesting() {
        performDeveloperTuningAction(.developerTuningNextPage)
    }

    func selectDeveloperTuningGroupForTesting(_ group: String) {
        performDeveloperTuningAction(.selectTuningGroup(group))
    }

    func selectDeveloperTuningSubgroupForTesting(_ subgroup: String) {
        performDeveloperTuningAction(.selectTuningSubgroup(subgroup))
    }

    func adjustTuningParameterForTesting(id: String, direction: GameTuningAdjustmentDirection) {
        performDeveloperTuningAction(.adjustTuningParameter(id, direction))
    }
}
#endif

// MARK: - Stateful weapon effects

private extension ArenaScene {
    func activateShockwaveWave(
        at center: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .shockwave)
    ) {
        activeWeapons.shockwaveWaves.append(
            ShockwaveWaveState(
                center: center,
                maximumRadius: configuration.shockwaveRadius,
                expansionDuration: configuration.shockwaveExpansionDuration,
                holdDuration: configuration.shockwaveHoldDuration,
                expansionExponent: configuration.waveExpansionExponent,
                activation: activation
            )
        )
        playShockwaveEffect(
            at: center,
            radius: configuration.shockwaveRadius,
            duration: configuration.shockwaveExpansionDuration,
            holdDuration: configuration.shockwaveHoldDuration,
            expansionExponent: configuration.waveExpansionExponent
        )
    }

    func updateShockwaveWaves(deltaTime: TimeInterval) {
        guard !activeWeapons.shockwaveWaves.isEmpty else {
            return
        }

        var activeStates: [ShockwaveWaveState] = []
        var didCompleteWave = false
        for var state in activeWeapons.shockwaveWaves {
            let frame = state.update(deltaTime: deltaTime, enemies: enemies)
            destroyEnemies(ids: frame.destroyedEnemyIDs, weaponKind: .shockwave, activation: state.activation)
            if !frame.isComplete {
                activeStates.append(state)
            } else {
                didCompleteWave = true
            }
        }
        activeWeapons.shockwaveWaves = activeStates
        if didCompleteWave {
            grantPostWeaponSafety(for: .shockwave)
        }
    }

    func activateFreezeBurstWave(
        at center: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .freezeBurst)
    ) {
        activeWeapons.freezeBurstWaves.append(
            FreezeBurstWaveState(
                center: center,
                maximumRadius: configuration.freezeBurstRadius,
                duration: configuration.freezeExpansionDuration,
                expansionExponent: configuration.waveExpansionExponent,
                freezeDuration: configuration.freezeDuration,
                thawGraceDuration: configuration.freezeThawGraceDuration,
                activation: activation
            )
        )
        playFreezeBurstEffect(
            at: center,
            radius: configuration.freezeBurstRadius,
            duration: configuration.freezeExpansionDuration,
            expansionExponent: configuration.waveExpansionExponent
        )
    }

    func updateFreezeBurstWaves(deltaTime: TimeInterval) {
        guard !activeWeapons.freezeBurstWaves.isEmpty else {
            return
        }

        var activeStates: [FreezeBurstWaveState] = []
        var didCompleteWave = false
        for var state in activeWeapons.freezeBurstWaves {
            let frame = state.update(deltaTime: deltaTime, enemies: enemies)
            freezeEnemies(
                ids: frame.frozenEnemyIDs,
                duration: state.freezeDuration,
                thawGraceDuration: state.thawGraceDuration,
                activation: state.activation
            )
            if !frame.isComplete {
                activeStates.append(state)
            } else {
                didCompleteWave = true
            }
        }
        activeWeapons.freezeBurstWaves = activeStates
        if didCompleteWave {
            grantPostWeaponSafety(for: .freezeBurst)
        }
    }

    func activatePowerWave(
        at position: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .powerWave)
    ) {
        activeWeapons.powerWave.activate(configuration: configuration, activation: activation)
        playPowerWaveChargeEffect(
            at: position,
            direction: activeWeapons.aimDirection.resolvedDirection(),
            duration: configuration.powerWaveChargeDuration
        )
    }

    func updatePowerWave(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard activeWeapons.powerWave.isActive else {
            return
        }

        let activation = activeWeapons.powerWave.activation
        let frame = activeWeapons.powerWave.update(
            deltaTime: deltaTime,
            playerPosition: playerPosition,
            direction: activeWeapons.aimDirection.resolvedDirection(),
            playableRect: currentPlayableRect,
            enemies: enemies,
            configuration: weaponResolver.configuration
        )

        if frame.isCharging {
            updatePowerWaveChargeEffect(
                at: playerPosition,
                direction: activeWeapons.aimDirection.resolvedDirection()
            )
        }

        if let release = frame.release {
            deactivatePowerWaveChargeEffect()
            playPowerWaveReleaseEffect(
                at: release.center,
                direction: release.direction,
                range: release.range,
                fanAngleDegrees: release.fanAngleDegrees,
                travelDistance: release.travelDistance,
                duration: release.expansionDuration
            )
        }

        destroyEnemies(ids: frame.destroyedEnemyIDs, weaponKind: .powerWave, activation: activation)
        if frame.isComplete {
            activeWeapons.powerWave.reset()
            grantPostWeaponSafety(for: .powerWave)
        }
    }

    func activateGravityWell(
        at center: CGPoint,
        configuration: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .gravityWell)
    ) {
        let state = GravityWellState(
            center: center,
            timeRemaining: configuration.gravityWellPullDuration,
            activationDelayRemaining: configuration.gravityWellActivationDelay,
            pullRadius: configuration.gravityWellRadius,
            pullDuration: configuration.gravityWellPullDuration,
            clearRadius: configuration.gravityWellClearRadius,
            activation: activation
        )
        activeWeapons.gravityWell = state
        playGravityWellEffect(
            at: center,
            radius: configuration.gravityWellRadius,
            clearRadius: configuration.gravityWellClearRadius,
            duration: state.totalTimeRemaining
        )
        destroyGravityWellCenterEnemies(state)
    }

    func updateGravityWell(deltaTime: TimeInterval, previousPositions: [Int: CGPoint] = [:]) {
        guard var state = activeWeapons.gravityWell else {
            return
        }

        destroyGravityWellCenterEnemies(state, previousPositions: previousPositions)
        let pullDelta = state.consumePullDelta(deltaTime: deltaTime)
        let pullDuration = max(state.pullDuration, 0.001)
        let pullDistance = state.pullRadius / CGFloat(pullDuration) * CGFloat(pullDelta)

        if pullDistance > 0 {
            enemyRegistry.update(ids: state.pullTargets(enemies: enemies)) { enemy in
                enemy.pullToward(state.center, distance: pullDistance)
            }
            destroyGravityWellCenterEnemies(state)
        }

        if state.isComplete {
            completeGravityWell(state)
        } else {
            activeWeapons.gravityWell = state
        }
    }

    func destroyGravityWellCenterEnemies(_ state: GravityWellState, previousPositions: [Int: CGPoint] = [:]) {
        destroyEnemies(
            ids: state.collapseTargets(enemies: enemies, previousPositions: previousPositions),
            weaponKind: .gravityWell,
            activation: state.activation
        )
    }

    func completeGravityWell(_ state: GravityWellState) {
        activeWeapons.gravityWell = nil
        gravityWellEffectNode?.removeFromParent()
        gravityWellEffectNode = nil

        let destroyedIDs = state.collapseTargets(enemies: enemies)
        let targets = impactTargets(forEnemyIDs: destroyedIDs)
        playGravityWellCollapseEffect(
            at: state.center,
            clearRadius: state.clearRadius,
            targets: targets
        ) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .gravityWell, activation: state.activation)
        }
        grantPostWeaponSafety(for: .gravityWell)
    }

    func deactivateGravityWell() {
        activeWeapons.gravityWell = nil
        gravityWellEffectNode?.removeFromParent()
        gravityWellEffectNode = nil
    }

    func freezeEnemies(
        ids enemyIDs: Set<Int>, duration: TimeInterval, thawGraceDuration: TimeInterval,
        activation: WeaponActivation = WeaponActivation(kind: .freezeBurst)
    ) {
        guard !enemyIDs.isEmpty, duration > 0 else {
            return
        }
        var frozenEnemies: [ArenaEnemy] = []
        enemyRegistry.update(ids: enemyIDs) { enemy in
            enemy.freeze(duration: duration, thawGraceDuration: thawGraceDuration, activation: activation)
            frozenEnemies.append(enemy)
        }
        for enemy in WeaponImpactPlan.evenlySampled(frozenEnemies) {
            playFreezeAppliedEffect(at: enemy.position, radius: enemy.radius)
        }
    }

    func shatterFrozenContactEnemies(playerPosition: CGPoint) {
        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )
        let shatterIDs = Set(
            enemies
                .filter {
                    $0.isShatterableFrozen && playerCircle.intersects($0.collisionCircle)
                }
                .map(\.id)
        )

        let groups = Dictionary(grouping: enemies.filter { shatterIDs.contains($0.id) }, by: \.freezeActivation)
        // Use enemy order for deterministic attribution when different freezes overlap.
        var remainingIDs = shatterIDs
        for enemy in enemies where remainingIDs.contains(enemy.id) {
            let ids = Set((groups[enemy.freezeActivation] ?? []).map(\.id))
            destroyEnemies(ids: ids, weaponKind: .freezeBurst, activation: enemy.freezeActivation)
            remainingIDs.subtract(ids)
        }
    }

    private func recordWeaponComboFeedback(
        _ event: WeaponComboEvent,
        previousComboMultiplier: Int,
        clearPositions: [CGPoint]
    ) {
        weaponLogger.notice("weapon.combo.resolved", metadata: [
            "kind": "\(event.kind.rawValue)",
            "from": "\(event.previousFamily.rawValue)",
            "to": "\(event.currentFamily.rawValue)"
        ])

        playWeaponComboEffect(event, at: clearPositions)

        guard runController.comboMultiplier == previousComboMultiplier else {
            return
        }

        playAudio(.comboMilestone)
        playHaptic(.comboMilestone(multiplier: event.kind == .cascade ? 4 : 2))
    }
}

private struct PlayerCollisionCandidate {
    let impactTime: CGFloat
    let enemyID: Int
    let enemyKind: EnemyKind
    let snapshot: DeathCollisionSnapshot
}

private struct PlayerCollisionMotion {
    let playerCircle: CollisionCircle
    let playerStart: CGPoint
    let previousDamageableEnemyPositions: [Int: CGPoint]
    let allowsSweptCollision: Bool
}

private extension GameCenterLeaderboardUnavailableReason {
    var gameplayStatusMessage: String {
        switch self {
        case .unsupported:
            return "GAME CENTER UNAVAILABLE"
        case .authenticationRequired:
            return "SIGN IN TO VIEW RANKS"
        }
    }
}

private extension ArenaUISceneState {
    var diagnosticName: String {
        switch self {
        case .home:
            return "home"
        case .modeSelect:
            return "modeSelect"
        case .awards:
            return "awards"
        case .weaponCodex:
            return "weaponCodex"
        case .options:
            return "options"
        case .developerTuning:
            return "developerTuning"
        case .calibrationPreview:
            return "calibrationPreview"
        case .preRun:
            return "preRun"
        case .activeGameplay:
            return "activeGameplay"
        case .pause:
            return "pause"
        case .postRun:
            return "postRun"
        }
    }
}

private extension ClassicRunPhase {
    var diagnosticName: String {
        switch self {
        case .preRun:
            return "preRun"
        case .active:
            return "active"
        case .paused:
            return "paused"
        case .gameOver:
            return "gameOver"
        }
    }
}

private extension ProcessInfo.ThermalState {
    var diagnosticName: String {
        switch self {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
}
