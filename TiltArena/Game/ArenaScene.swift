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
    func arenaSceneRequestsDiagnosticsExport(
        _ scene: ArenaScene,
        snapshot: DiagnosticGameplaySnapshot
    )
}

@MainActor
protocol ArenaSceneGameCenterDelegate: AnyObject {
    func arenaSceneGameCenterMenuStatus(_ scene: ArenaScene) -> GameCenterMenuStatus
    func arenaSceneRequestsClassicLeaderboard(_ scene: ArenaScene) -> GameCenterLeaderboardPresentationResult
}

// swiftlint:disable:next type_body_length
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
    private let hapticsController = ArenaHapticsController()
    private let audioController = ArenaAudioController()
    private var arenaRoot = SKNode()
    private let weaponEffectsRoot = SKNode()
    private let uiRoot = SKNode()
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    private let keyboardInputController = KeyboardInputController()
    private var gameTuning = GameTuningConfiguration.defaults
    var movementController = PlayerMovementController()
    private var runController = ClassicRunController()
    private var runProfile = RunProfile()
    private var localOptions = ArenaLocalOptions()
    private var uiState: ArenaUISceneState = .home
    private var optionsReturnState: ArenaUISceneState = .home
    private var calibrationReturnState: ArenaUISceneState = .home
    private var developerReturnState: ArenaUISceneState = .home
    private var gameCenterStatusMessage: String?
    private var selectedMode: ArenaModeKind = .classic
    private var previousBestScore = 0
    private var lastProgressionResult: ArenaProgressionResult?
    private var resetDataArmed = false
    private var hasPersistedFinalRun = false
    private var isResolvingDeath = false
    private var developerTuningPageIndex = 0
    private var developerTuningSelectedGroup: String?
    private var developerTuningSelectedSubgroup: String?
    private var developerTuningChangedOnly = false
    private var developerTuningCopyConfirmation: String?
    private var deathReplayTrace = DeathReplayTrace()
    private var lastDeathCollisionSnapshot: DeathCollisionSnapshot?
    private var readyHoldController = ReadyStartHoldController()
    private var readyStartPoint = CGPoint.zero
    private var readyProgressRing: SKShapeNode?
    private var readyStatusLabel: SKLabelNode?
    private var spawnDirector = EnemySpawnDirector()
    private var pickupSpawnConfiguration = PickupSpawnConfiguration()
    private var pickupPlanner = PickupSpawnPlanner()
    var weaponResolver = StartingWeaponResolver()
    var weaponEffectTiming = WeaponEffectTiming()
    private var enemies: [ArenaEnemy] = []
    private var enemyNodes: [Int: EnemyNode] = [:]
    private var enemyTelegraphNodes: [Int: EnemyTelegraphNode] = [:]
    private var formationEnemyIDs: [Int: Set<Int>] = [:]
    private var pickups: [WeaponPickup] = []
    private var pickupNodes: [Int: WeaponPickupNode] = [:]
    private var playerNode: PlayerCraftNode?
    private var playerTrailNode: PlayerTrailNode?
    private var razorShieldTimeRemaining: TimeInterval = 0
    private var activeRazorShieldConfiguration: StartingWeaponConfiguration?
    private var hasPlayedRazorShieldWarning = false
    private var razorShieldNode: SKShapeNode?
    private var shockwaveWaveStates: [ShockwaveWaveState] = []
    private var freezeBurstWaveStates: [FreezeBurstWaveState] = []
    private var flameTrailState = FlameTrailState()
    private var flameTrailSpeedBoostTimeRemaining: TimeInterval = 0
    private var flameTrailInvulnerabilityTimeRemaining: TimeInterval = 0
    private var postWeaponSafetyTimeRemaining: TimeInterval = 0
    private lazy var flameTrailEffectNode = FlameTrailEffectNode(theme: theme)
    private var gravityWellState: GravityWellState?
    var gravityWellEffectNode: SKNode?
    private var aimDirectionState = AimDirectionState()
    private var timeDilationTimeRemaining: TimeInterval = 0
    private var activeTimeDilationConfiguration: StartingWeaponConfiguration?
    private var timeDilationAuraNode: SKNode?
    private var powerWaveState = PowerWaveState()
    var powerWaveChargeNode: SKNode?
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let bestMarkerLabel = SKLabelNode(fontNamed: "Menlo")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
#if DEBUG
    private let debugStatsLabel = SKLabelNode(fontNamed: "Menlo")
    private var debugStatsElapsed: TimeInterval = 0
    private var debugStatsLogElapsed: TimeInterval = 0
    private var debugStatsFrameCount = 0
#endif
    private let hudMargin: CGFloat = 24
    private var uiHitTargets: [ArenaControlHitTarget] = []
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
        super.init(size: size)
        configureSceneDefaults()
    }

    init(
        size: CGSize,
        tiltSettingsStore: TiltSettingsStore,
        runProfileStore: RunProfileStore = RunProfileStore(),
        localOptionsStore: ArenaLocalOptionsStore = ArenaLocalOptionsStore(),
        gameTuningStore: GameTuningStore = GameTuningStore()
    ) {
        self.tiltSettingsStore = tiltSettingsStore
        self.runProfileStore = runProfileStore
        self.localOptionsStore = localOptionsStore
        self.gameTuningStore = gameTuningStore
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
        if flameTrailEffectNode.parent == nil { addChild(flameTrailEffectNode) }
        configureLabels()
        configureUIRoot()
        configureDebugStats()
        placePlayer(resetPosition: true)
        updateRunDisplay()
        rebuildUI()
        tiltInputController.start()
        AppDiagnostics.logger(.scene).notice("scene.presented", metadata: [
            "width": "\(Int(size.width.rounded()))",
            "height": "\(Int(size.height.rounded()))"
        ])
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
        let shouldResetPosition = playerNode == nil || uiState == .home
        placePlayer(resetPosition: shouldResetPosition, resetTrail: shouldResetPosition)
        if uiState == .preRun {
            readyStartPoint = movementController.state.position
            readyHoldController.reset()
        } else if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }
        layoutLabels()
        layoutDebugStats()
        rebuildUI()
        AppDiagnostics.logger(.scene).debug("scene.resized", metadata: [
            "width": "\(Int(size.width.rounded()))",
            "height": "\(Int(size.height.rounded()))"
        ])
    }

    override func willMove(from view: SKView) {
        orientationDelegate?.arenaSceneRequestsOrientationUnlock(self)
        audioController.stopMusic()
        tiltInputController.stop()
        lastUpdateTime = nil
        AppDiagnostics.logger(.scene).notice("scene.removed")
    }

    override func update(_ currentTime: TimeInterval) {
        defer {
            lastUpdateTime = currentTime
        }

        guard let lastUpdateTime else {
            return
        }

        let deltaTime = min(1.0 / 15.0, max(0, currentTime - lastUpdateTime))
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
        AppDiagnostics.logger(.input).notice("input.calibrated", metadata: [
            "orientation": "\(currentTiltScreenOrientation.rawValue)"
        ])
        if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }
        updateRunDisplay()
        rebuildUI()
    }

    func refreshSafeAreaLayout() {
        rebuildArena()
        let shouldResetPosition = playerNode == nil || uiState == .home
        placePlayer(resetPosition: shouldResetPosition, resetTrail: shouldResetPosition)
        if uiState == .calibrationPreview {
            resetCalibrationPreviewPosition()
        }
        layoutLabels()
        layoutDebugStats()
        rebuildUI()
    }

    func refreshGameCenterMenuStatus() {
        guard uiState == .home || uiState == .postRun else {
            return
        }

        rebuildUI()
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
            if let target = uiHitTargets.reversed().first(where: { $0.frame.contains(location) }) {
                perform(target.action)
                return
            }
        }
    }

    private func rebuildArena() {
        arenaRoot.removeFromParent()
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(
            size: size,
            arenaRect: currentGameplayBounds
        )
        addChild(arenaRoot)
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
        addChild(weaponEffectsRoot)
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
            addChild(trailNode)
            playerTrailNode = trailNode
        }

        if playerNode == nil {
            let craftNode = PlayerCraftNode(
                theme: theme,
                visualRadius: movementController.configuration.visualRadius
            )
            addChild(craftNode)
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

    private func configureLabels() {
        configureLabel(timerLabel, fontSize: 16, color: theme.playerColor.withAlphaComponent(0.9))
        timerLabel.horizontalAlignmentMode = .left
        timerLabel.verticalAlignmentMode = .top

        configureLabel(bestMarkerLabel, fontSize: 12, color: theme.playerColor.withAlphaComponent(0.78))
        bestMarkerLabel.horizontalAlignmentMode = .right
        bestMarkerLabel.verticalAlignmentMode = .top

        configureLabel(comboLabel, fontSize: 14, color: theme.playerAccentColor)
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.verticalAlignmentMode = .bottom

        [timerLabel, bestMarkerLabel, comboLabel].forEach { label in
            if label.parent == nil {
                addChild(label)
            }
        }

        layoutLabels()
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.zPosition = 50
    }

    private func layoutLabels() {
        let layout = currentHUDLayout()

        timerLabel.position = layout.timerPosition
        bestMarkerLabel.position = layout.bestMarkerPosition
        comboLabel.position = layout.comboPosition
    }

    private func configureDebugStats() {
        #if DEBUG
        configureLabel(debugStatsLabel, fontSize: 12, color: theme.borderColor)
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
        debugStatsLogElapsed += deltaTime
        debugStatsFrameCount += 1

        guard debugStatsElapsed >= 0.25 else {
            return
        }

        let framesPerSecond = Double(debugStatsFrameCount) / debugStatsElapsed
        let nodeCount = debugNodeCount(in: self)
        debugStatsLabel.text = "nodes:\(nodeCount)  \(Int(framesPerSecond.rounded())) fps"
        if debugStatsLogElapsed >= 5 {
            AppDiagnostics.logger(.performance).info("performance.sample", metadata: [
                "fps": "\(Int(framesPerSecond.rounded()))",
                "nodes": "\(nodeCount)"
            ])
            debugStatsLogElapsed = 0
        }
        debugStatsElapsed = 0
        debugStatsFrameCount = 0
        #endif
    }

    #if DEBUG
    private func debugNodeCount(in node: SKNode) -> Int {
        node.children.reduce(1) { count, child in
            count + debugNodeCount(in: child)
        }
    }
    #endif

    private func currentHUDLayout() -> ArenaHUDLayout {
        ArenaHUDLayout(
            sceneSize: size,
            safeAreaInsets: view?.safeAreaInsets ?? .zero,
            margin: hudMargin
        )
    }

    private func currentLandscapeLayout() -> ArenaLandscapeUILayout {
        ArenaLandscapeUILayout(
            sceneSize: size,
            safeAreaInsets: view?.safeAreaInsets ?? .zero,
            margin: hudMargin
        )
    }

    var currentGameplayBounds: CGRect {
        currentLandscapeLayout().gameplayRect
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
        let input = movementInput(deltaTime: deltaTime)
        let state = movementController.update(input: input, deltaTime: deltaTime, arenaBounds: currentGameplayBounds)
        applyPlayerState(state, resetTrail: false)

        let holdState = readyHoldController.update(
            playerPosition: state.position,
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

        let input = movementInput(deltaTime: deltaTime)
        aimDirectionState.record(input: input)
        let state = updatePlayerMovement(input: input, deltaTime: deltaTime)
        applyPlayerState(state, resetTrail: false)
        updateActiveRun(deltaTime: deltaTime, playerPosition: state.position)
    }

    private func updatePlayerMovement(input: CGVector, deltaTime: TimeInterval) -> PlayerMovementState {
        guard flameTrailSpeedBoostTimeRemaining > 0 else {
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
            speedMultiplier: flameTrailState.configuration.speedMultiplier
        )
    }

    private func updateCalibrationPreview(deltaTime: TimeInterval) {
        let input = movementInput(deltaTime: deltaTime)
        let state = calibrationPreviewMovementController.update(
            input: input,
            deltaTime: deltaTime,
            arenaBounds: currentGameplayBounds
        )

        applyCalibrationPreviewState(state, resetTrail: false)
        updateTiltReadoutDisplay(deltaTime: deltaTime)
    }

    private func movementInput(deltaTime: TimeInterval) -> CGVector {
        let tiltInput = tiltInputController.update(
            deltaTime: deltaTime,
            orientation: currentTiltScreenOrientation
        )
        let keyboardInput = keyboardInputController.movementInput()

        return keyboardInput.isActive ? keyboardInput.vector : tiltInput
    }

    private func enterCalibrationPreview() {
        if uiState != .calibrationPreview {
            calibrationReturnState = uiState
        }

        tiltInputController.resetSmoothedInput()
        resetCalibrationPreviewPosition()
        show(.calibrationPreview)
    }

    private func resetCalibrationPreviewPosition() {
        calibrationPreviewMovementController.configuration = movementController.configuration
        var state = calibrationPreviewMovementController.reset(in: currentGameplayBounds)
        let targetPosition = calibrationPreviewStartPosition(in: currentGameplayBounds)
        let offset = CGVector(
            dx: targetPosition.x - state.position.x,
            dy: targetPosition.y - state.position.y
        )
        if offset.length > 0 {
            state = calibrationPreviewMovementController.dash(
                direction: offset,
                distance: offset.length,
                arenaBounds: currentGameplayBounds
            )
            state = calibrationPreviewMovementController.update(input: .zero, deltaTime: 0, arenaBounds: currentGameplayBounds)
        }
        applyCalibrationPreviewState(state, resetTrail: true)
    }

    private func calibrationPreviewStartPosition(in arenaBounds: CGRect) -> CGPoint {
        let controlsWidth = min(292, max(260, arenaBounds.width * 0.38))
        let playableRect = calibrationPreviewMovementController.configuration.playableRect(in: arenaBounds)
        let visibleMinX = max(playableRect.minX, arenaBounds.minX + controlsWidth + 48)
        let preferredX = (visibleMinX + playableRect.maxX) / 2

        return CGPoint(
            x: min(playableRect.maxX, max(playableRect.minX, preferredX)),
            y: playableRect.midY
        )
    }

    private func applyCalibrationPreviewState(_ state: PlayerMovementState, resetTrail: Bool) {
        let speedFraction = state.velocity.length / max(
            1,
            calibrationPreviewMovementController.configuration.maximumSpeed(in: currentGameplayBounds)
        )
        calibrationPreviewPlayerNode?.apply(state: state, speedFraction: speedFraction)

        if resetTrail {
            calibrationPreviewTrailNode?.reset(to: state.position)
        } else {
            calibrationPreviewTrailNode?.record(position: state.position, speedFraction: speedFraction)
        }
    }

    private func preparePreRun() {
        runController = ClassicRunController(configuration: runController.configuration)
        hasPersistedFinalRun = false
        resetGameplayObjects()
        readyHoldController.reset()
        placePlayer(resetPosition: true)
        readyStartPoint = movementController.state.position
        resetPlayerFeedback()
        show(.preRun)
        AppDiagnostics.logger(.run).notice("run.prepared", metadata: [
            "mode": "\(selectedMode.rawValue)"
        ])
    }

    private func startRun() {
        runController.start()
        readyHoldController.reset()
        resetActiveRun()
        audioController.resetEventLimiter()
        audioController.startMusic()
        hapticsController.prepare()
        show(.activeGameplay)
        AppDiagnostics.logger(.run).notice("run.started", metadata: [
            "mode": "\(selectedMode.rawValue)"
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
        AppDiagnostics.logger(.run).info("run.paused", metadata: [
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
        AppDiagnostics.logger(.run).info("run.resumed", metadata: [
            "score": "\(runController.score)",
            "survivalTime": "\(runController.survivalTime)"
        ])
    }

    private func finishRun(playFeedback: Bool = true, collision: DeathCollisionSnapshot? = nil) {
        guard
            !isResolvingDeath,
            runController.phase == .active || runController.phase == .paused
        else {
            return
        }

        isResolvingDeath = playFeedback
        previousBestScore = runProfile.bestScore
        runController.endRun(mode: selectedMode)
        clearWeaponEffectNodes(paused: true)
        shockwaveWaveStates.removeAll()
        freezeBurstWaveStates.removeAll()
        powerWaveState.reset()
        powerWaveChargeNode = nil
        flameTrailSpeedBoostTimeRemaining = 0
        flameTrailInvulnerabilityTimeRemaining = 0
        clearPostWeaponSafety()
        deactivateTimeDilationAura()
        audioController.stopMusic()
        lastDeathCollisionSnapshot = collision
        let isNewBest = (runController.finalizedSummary?.score ?? runController.score) > previousBestScore
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
        if playFeedback {
            run(.sequence([
                .wait(forDuration: 0.22),
                .run { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isResolvingDeath = false
                    self.show(.postRun)
                }
            ]))
        } else {
            isResolvingDeath = false
            show(.postRun)
        }
        logFinishedRun(isNewBest: isNewBest)
    }

    private func resetActiveRun() {
        hasPersistedFinalRun = false
        isResolvingDeath = false
        lastProgressionResult = nil
        lastDeathCollisionSnapshot = nil
        deathReplayTrace.reset()
        resetGameplayObjects()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
        updateRunDisplay()
    }

    private func resetGameplayObjects() {
        let modeSettings = applySelectedModeRunSettings()
        enemies.removeAll()
        enemyNodes.values.forEach { $0.removeFromParent() }
        enemyNodes.removeAll()
        enemyTelegraphNodes.values.forEach { $0.removeFromParent() }
        enemyTelegraphNodes.removeAll()
        formationEnemyIDs.removeAll()
        spawnDirector.reset(sequenceSeed: modeSettings.sequenceSeed)

        pickups.removeAll()
        pickupNodes.values.forEach { $0.removeFromParent() }
        pickupNodes.removeAll()
        pickupPlanner.reset(
            configuration: pickupSpawnConfiguration,
            sequenceSeed: modeSettings.sequenceSeed
        )
        clearWeaponEffectNodes(paused: false)
        deactivateRazorShield()
        hasPlayedRazorShieldWarning = false
        shockwaveWaveStates.removeAll()
        freezeBurstWaveStates.removeAll()
        flameTrailState.reset()
        flameTrailSpeedBoostTimeRemaining = 0
        flameTrailInvulnerabilityTimeRemaining = 0
        clearPostWeaponSafety()
        flameTrailEffectNode.reset()
        deactivateGravityWell()
        aimDirectionState.reset()
        deactivateTimeDilationAura()
        powerWaveState.reset()
        deactivatePowerWaveChargeEffect()
    }

    private func applyGameTuning(rebuildPlayerVisuals: Bool = false) {
        movementController.configuration = gameTuning.playerMovement
        calibrationPreviewMovementController.configuration = gameTuning.playerMovement
        var runConfiguration = gameTuning.run
        runConfiguration.playerVisualRadius = gameTuning.playerMovement.visualRadius
        runController.configuration = runConfiguration
        readyHoldController.configuration = gameTuning.readyStart
        weaponResolver.configuration = gameTuning.startingWeapons
        weaponEffectTiming = gameTuning.weaponEffectTiming
        flameTrailState.configuration = gameTuning.flameTrail
        deathReplayTrace.duration = gameTuning.feedback.deathReplayDuration
        _ = applySelectedModeRunSettings()

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
            let remainingShieldTime = razorShieldTimeRemaining
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
                razorShieldTimeRemaining = remainingShieldTime
            }
        }
    }

    private func applySelectedModeRunSettings() -> ArenaModeRunSettings {
        let settings = ArenaModeRules.runSettings(for: selectedMode, profile: runProfile)
        let modeTuning = gameTuning.modeTuning(for: selectedMode)
        var tunedPickupConfiguration = modeTuning.pickupSpawnConfiguration
        tunedPickupConfiguration.weaponKindCycle = ArenaProgressionRules.filteredWeaponCycle(
            tunedPickupConfiguration.weaponKindCycle,
            profile: runProfile
        )

        spawnDirector.configuration = modeTuning.enemySpawnConfiguration
        pickupSpawnConfiguration = tunedPickupConfiguration
        return ArenaModeRunSettings(
            enemySpawnConfiguration: modeTuning.enemySpawnConfiguration,
            pickupSpawnConfiguration: tunedPickupConfiguration,
            sequenceSeed: settings.sequenceSeed
        )
    }

    private func resetPlayerFeedback() {
        playerNode?.removeAllActions()
        playerNode?.alpha = 1
        playerNode?.setScale(1)
    }

    private func applyThemeChange() {
        backgroundColor = theme.backgroundColor
        configureLabels()
        configureDebugStats()
        rebuildArena()
        refreshGameplayNodesForTheme()
        rebuildUI()
    }

    private func refreshGameplayNodesForTheme() {
        playerNode?.applyTheme(theme)
        playerTrailNode?.applyTheme(theme)
        flameTrailEffectNode.applyTheme(theme)
        refreshEnemyNodesForTheme()
        refreshPickupNodesForTheme()
        refreshTelegraphNodesForTheme()
        refreshActiveWeaponEffectNodesForTheme()
    }

    private func refreshEnemyNodesForTheme() {
        for enemy in enemies {
            enemyNodes[enemy.id]?.applyTheme(theme, enemy: enemy)
        }
    }

    private func refreshPickupNodesForTheme() {
        for pickup in pickups {
            pickupNodes[pickup.id]?.applyTheme(theme, pickup: pickup)
        }
    }

    private func refreshTelegraphNodesForTheme() {
        enemyTelegraphNodes.values.forEach { $0.applyTheme(theme) }
    }

    private func refreshActiveWeaponEffectNodesForTheme() {
        if let razorShieldNode {
            styleRazorShieldNode(razorShieldNode)
        }

        if let gravityWellState {
            playGravityWellEffect(
                at: gravityWellState.center,
                radius: gravityWellState.pullRadius,
                duration: gravityWellState.totalTimeRemaining
            )
        }

        if powerWaveState.isCharging {
            playPowerWaveChargeEffect(
                at: movementController.state.position,
                direction: aimDirectionState.resolvedDirection(),
                duration: powerWaveState.chargeTimeRemaining
            )
        }

        if timeDilationTimeRemaining > 0 {
            timeDilationAuraNode?.removeFromParent()
            timeDilationAuraNode = playTimeDilationAuraEffect(
                at: movementController.state.position,
                radius: timeDilationConfiguration.timeDilationRadius,
                duration: timeDilationTimeRemaining
            )
        }
    }

    private func updateActiveRun(deltaTime: TimeInterval, playerPosition initialPlayerPosition: CGPoint) {
        var playerPosition = initialPlayerPosition

        runController.update(deltaTime: deltaTime)
        deathReplayTrace.record(time: runController.survivalTime, position: playerPosition)
        spawnEnemiesIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        advancePickupCharges(deltaTime: deltaTime)
        spawnPickupIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        updateFlameTrailTimers(deltaTime: deltaTime)
        updatePostWeaponSafety(deltaTime: deltaTime)
        playerPosition = collectPickups(playerPosition: playerPosition)
        advanceEnemies(deltaTime: deltaTime, playerPosition: playerPosition)
        updateTimeDilationAura(deltaTime: deltaTime, playerPosition: playerPosition)
        updateGravityWell(deltaTime: deltaTime)
        updateShockwaveWaves(deltaTime: deltaTime)
        updateFreezeBurstWaves(deltaTime: deltaTime)
        updatePowerWave(deltaTime: deltaTime, playerPosition: playerPosition)
        removeExpiredEnemies()
        cullExitedLinearPatternEnemies()
        updateRazorShield(deltaTime: deltaTime, playerPosition: playerPosition)
        shatterFrozenContactEnemies(playerPosition: playerPosition)
        updateFlameTrail(deltaTime: deltaTime, playerPosition: playerPosition)
        detectPlayerCollision(playerPosition: playerPosition)
        updateRunDisplay()
    }

    private func spawnEnemiesIfNeeded(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let frame = spawnDirector.update(
            deltaTime: deltaTime,
            survivalTime: runController.survivalTime,
            activeEnemies: enemies,
            playableRect: currentPlayableRect,
            playerPosition: playerPosition,
            pickupCircles: pickups.map(\.collisionCircle)
        )

        removeEnemyTelegraphs(ids: frame.telegraphIDsToRemove)
        showEnemyTelegraphs(frame.telegraphsToShow)
        addSpawnedEnemies(frame.newEnemies)
    }

    private func addSpawnedEnemies(_ spawnedEnemies: [ArenaEnemy]) {
        if !spawnedEnemies.isEmpty {
            AppDiagnostics.logger(.spawn).debug("spawn.enemies", metadata: [
                "count": "\(spawnedEnemies.count)",
                "survivalTime": "\(runController.survivalTime)"
            ])
        }

        for enemy in spawnedEnemies {
            enemies.append(enemy)

            let node = EnemyNode(enemy: enemy, theme: theme)
            enemyNodes[enemy.id] = node
            addChild(node)

            if let formationID = enemy.formationID {
                formationEnemyIDs[formationID, default: []].insert(enemy.id)
            }
        }
    }

    private func showEnemyTelegraphs(_ telegraphs: [EnemyTelegraph]) {
        for telegraph in telegraphs {
            enemyTelegraphNodes[telegraph.id]?.removeFromParent()
            let node = EnemyTelegraphNode(telegraph: telegraph, theme: theme)
            enemyTelegraphNodes[telegraph.id] = node
            addChild(node)
        }
    }

    private func removeEnemyTelegraphs(ids telegraphIDs: Set<Int>) {
        for telegraphID in telegraphIDs {
            enemyTelegraphNodes.removeValue(forKey: telegraphID)?.removeFromParent()
        }
    }

    private func spawnPickupIfNeeded(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let enemyCircles = enemies.map(\.collisionCircle)

        let spawnedPickups = pickupPlanner.update(
            deltaTime: deltaTime,
            phase: runController.phase,
            activePickupCount: pickups.count,
            playableRect: currentPlayableRect,
            playerPosition: playerPosition,
            enemyCircles: enemyCircles,
            configuration: pickupSpawnConfiguration
        )

        guard !spawnedPickups.isEmpty else {
            return
        }

        for pickup in spawnedPickups {
            pickups.append(pickup)
            AppDiagnostics.logger(.weapon).info("pickup.spawned", metadata: [
                "id": "\(pickup.id)",
                "kind": "\(pickup.kind.rawValue)",
                "tier": "\(pickup.chargeTier.metadataValue)"
            ])

            let node = WeaponPickupNode(pickup: pickup, theme: theme)
            pickupNodes[pickup.id] = node
            addChild(node)
        }
    }

    private func advancePickupCharges(deltaTime: TimeInterval) {
        guard deltaTime > 0, !pickups.isEmpty else {
            return
        }

        for index in pickups.indices {
            let previousTier = pickups[index].chargeTier
            pickups[index].advanceCharge(deltaTime: deltaTime, configuration: pickupSpawnConfiguration)

            guard pickups[index].chargeTier != previousTier else {
                continue
            }

            pickupNodes[pickups[index].id]?.apply(pickups[index])
            AppDiagnostics.logger(.weapon).info("pickup.charged", metadata: [
                "id": "\(pickups[index].id)",
                "kind": "\(pickups[index].kind.rawValue)",
                "tier": "\(pickups[index].chargeTier.metadataValue)"
            ])
        }
    }

    private func advanceEnemies(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let runSpeedMultiplier = spawnDirector.configuration.enemySurvivalSpeedMultiplier(
            at: runController.survivalTime
        )
        let maximumEnemySpeed = movementController.configuration.maximumSpeed(in: currentGameplayBounds)

        for index in enemies.indices {
            enemies[index].advance(
                toward: playerPosition,
                deltaTime: deltaTime,
                externalSpeedMultiplier: runSpeedMultiplier * timeDilationEnemySpeedMultiplier(
                    for: enemies[index],
                    playerPosition: playerPosition
                ),
                maximumSpeed: maximumEnemySpeed
            )
            enemyNodes[enemies[index].id]?.apply(enemies[index])
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

        for formationID in Set(exitedEnemies.compactMap(\.formationID)) {
            formationEnemyIDs.removeValue(forKey: formationID)
        }

        enemies.removeAll { exitedEnemyIDs.contains($0.id) }
        for enemyID in exitedEnemyIDs {
            enemyNodes.removeValue(forKey: enemyID)?.removeFromParent()
        }
    }

    private func removeExpiredEnemies() {
        let expiredEnemyIDs = Set(enemies.filter(\.isExpired).map(\.id))

        guard !expiredEnemyIDs.isEmpty else {
            return
        }

        enemies.removeAll { expiredEnemyIDs.contains($0.id) }
        removeFormationEnemies(ids: expiredEnemyIDs)

        for enemyID in expiredEnemyIDs {
            enemyNodes.removeValue(forKey: enemyID)?.removeFromParent()
        }
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
            AppDiagnostics.logger(.weapon).notice("pickup.collected", metadata: [
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
        pickups.removeAll { $0.id == id }
        pickupNodes.removeValue(forKey: id)?.removeFromParent()
    }

    private func applyWeapon(_ pickup: WeaponPickup, playerPosition: CGPoint) {
        var rng = SystemRandomNumberGenerator()
        let chargedConfiguration = weaponResolver.configuration.applying(chargeTier: pickup.chargeTier)
        let chargedResolver = StartingWeaponResolver(configuration: chargedConfiguration)
        let application = WeaponApplicationCoordinator(resolver: chargedResolver).application(
            kind: pickup.kind,
            playerPosition: playerPosition,
            enemies: enemies,
            using: &rng
        )
        var log = application.log

        if let directionalDestroyedCount = performWeaponApplicationEffect(
            application.effect,
            from: playerPosition,
            configuration: chargedConfiguration,
            chargeTier: pickup.chargeTier
        ) {
            log.destroyedCount = directionalDestroyedCount
        }
        playChargedWeaponActivationEffect(
            kind: pickup.kind,
            at: playerPosition,
            chargeTier: pickup.chargeTier
        )

        AppDiagnostics.logger(.weapon).notice("weapon.resolved", metadata: [
            "kind": "\(pickup.kind.rawValue)",
            "tier": "\(pickup.chargeTier.metadataValue)",
            "destroyed": "\(log.destroyedCount)",
            "frozen": "\(log.frozenCount)",
            "gravityTargets": "\(log.gravityTargetCount)"
        ])
    }

    private func performWeaponApplicationEffect(
        _ effect: WeaponApplication.Effect,
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        chargeTier: WeaponPickupChargeTier
    ) -> Int? {
        switch effect {
        case .timeDilationAura:
            return activateTimeDilationAura(at: playerPosition, configuration: configuration)
        case .ricochetLance:
            let destroyedCount = fireRicochetLance(from: playerPosition, configuration: configuration)
            grantPostWeaponSafety(for: .ricochetLance)
            return destroyedCount
        default:
            performWeaponActivationEffect(
                effect,
                from: playerPosition,
                configuration: configuration,
                chargeTier: chargeTier
            )
            return nil
        }
    }

    private func performWeaponActivationEffect(
        _ effect: WeaponApplication.Effect,
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration,
        chargeTier: WeaponPickupChargeTier
    ) {
        switch effect {
        case .shockwaveWave:
            activateShockwaveWave(at: playerPosition, configuration: configuration)
        case .seekerSwarm(let enemyIDs):
            playSeekerSwarm(
                enemyIDs: enemyIDs,
                from: playerPosition,
                configuration: configuration
            )
            grantPostWeaponSafety(for: .seekerSwarm)
        case .razorShield:
            activateRazorShield(at: playerPosition, configuration: configuration)
        case .freezeBurstWave:
            activateFreezeBurstWave(at: playerPosition, configuration: configuration)
        case .gravityWell(let enemyIDs):
            activateGravityWell(at: playerPosition, enemyIDs: enemyIDs, configuration: configuration)
        case .chainLightning(let enemyIDs):
            playChainLightning(enemyIDs: enemyIDs, from: playerPosition, configuration: configuration)
            grantPostWeaponSafety(for: .chainLightning)
        case .flameTrail:
            activateFlameTrail(at: playerPosition, chargeTier: chargeTier)
        case .timeDilationAura, .ricochetLance:
            break
        case .powerWave:
            activatePowerWave(at: playerPosition, configuration: configuration)
        case .novaBomb(let enemyIDs):
            playNovaBomb(enemyIDs: enemyIDs)
            grantPostWeaponSafety(for: .novaBomb)
        }
    }

    private func playSeekerSwarm(
        enemyIDs: Set<Int>,
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        let resolver = StartingWeaponResolver(configuration: configuration)
        let targets = impactTargets(forEnemyIDs: enemyIDs)
            .sorted { lhs, rhs in
                ArenaGeometry.squaredDistance(from: lhs.position, to: playerPosition)
                    < ArenaGeometry.squaredDistance(from: rhs.position, to: playerPosition)
            }
        playSeekerSwarmEffect(
            from: playerPosition,
            to: targets,
            configuration: configuration,
            targetPosition: { [weak self] enemyID in
                self?.position(forEnemyID: enemyID)
            },
            onImpact: { [weak self] target in
                self?.resolveSeekerExplosion(at: target, resolver: resolver)
            }
        )
    }

    private func position(forEnemyID enemyID: Int) -> CGPoint? {
        enemies.first { $0.id == enemyID }?.position
    }

    private func resolveSeekerExplosion(at target: WeaponImpactTarget, resolver: StartingWeaponResolver) {
        destroyEnemies(
            ids: resolver.seekerExplosionTargets(center: target.position, enemies: enemies),
            weaponKind: .seekerSwarm
        )
        grantPostWeaponSafety(for: .seekerSwarm)
    }

    private func playChainLightning(
        enemyIDs: [Int],
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        let targets = impactTargets(forEnemyIDs: enemyIDs)
        playChainLightningEffect(
            from: playerPosition,
            through: targets,
            configuration: configuration,
            accentColor: theme.playerAccentColor,
            coreColor: theme.playerColor
        ) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .chainLightning)
            self?.grantPostWeaponSafety(for: .chainLightning)
        }
    }

    private func playNovaBomb(enemyIDs: Set<Int>) {
        let targets = impactTargets(forEnemyIDs: enemyIDs)
        playNovaBombEffect(targets: targets) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .novaBomb)
            self?.grantPostWeaponSafety(for: .novaBomb)
        }
    }

    private func positions(forEnemyIDs enemyIDs: Set<Int>) -> [CGPoint] {
        enemies.compactMap { enemyIDs.contains($0.id) ? $0.position : nil }
    }

    private func impactTargets(forEnemyIDs enemyIDs: Set<Int>) -> [WeaponImpactTarget] {
        enemies.compactMap { enemy in
            enemyIDs.contains(enemy.id) ? WeaponImpactTarget(id: enemy.id, position: enemy.position) : nil
        }
    }

    private func impactTargets(forEnemyIDs enemyIDs: [Int]) -> [WeaponImpactTarget] {
        let enemiesByID = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0) })
        return enemyIDs.compactMap { enemyID in
            guard let enemy = enemiesByID[enemyID] else {
                return nil
            }

            return WeaponImpactTarget(id: enemy.id, position: enemy.position)
        }
    }

    private func destroyEnemies(ids enemyIDs: Set<Int>, weaponKind: WeaponKind?) {
        let liveEnemyIDs = Set(enemies.map(\.id))
        let enemyIDs = enemyIDs.intersection(liveEnemyIDs)

        guard !enemyIDs.isEmpty else {
            return
        }

        let destroyedEnemies = enemies.filter { enemyIDs.contains($0.id) }
        let clearPositions = destroyedEnemies.map(\.position)
        let splitChildren = splitterChildren(from: destroyedEnemies)
        let previousComboMultiplier = runController.comboMultiplier
        let weaponComboEvent = runController.recordEnemyKills(count: enemyIDs.count, weaponKind: weaponKind)
        reportGameCenterAchievementEvent(.enemyClear(
            count: enemyIDs.count,
            weaponKind: weaponKind,
            maxCombo: runController.maxCombo
        ))
        playEnemyClearHaptics(killCount: enemyIDs.count, previousComboMultiplier: previousComboMultiplier)
        playEnemyClearAudio(killCount: enemyIDs.count, previousComboMultiplier: previousComboMultiplier)
        if let weaponComboEvent {
            recordWeaponComboFeedback(
                weaponComboEvent,
                previousComboMultiplier: previousComboMultiplier,
                clearPositions: clearPositions
            )
        }
        playEnemyClearBursts(
            at: clearPositions,
            weaponKind: weaponKind,
            comboMultiplier: runController.comboMultiplier
        )
        if enemyIDs.count >= gameTuning.feedback.multiKillShakeThreshold {
            playScreenShake(
                amplitude: gameTuning.feedback.multiKillShakeAmplitude,
                duration: gameTuning.feedback.multiKillShakeDuration
            )
        }
        removeEnemies(ids: enemyIDs)
        addSplitterChildren(splitChildren)
    }

    private func splitterChildren(from destroyedEnemies: [ArenaEnemy]) -> [ArenaEnemy] {
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

        AppDiagnostics.logger(.spawn).info("enemy.split", metadata: [
            "children": "\(childrenToAdd.count)"
        ])
        addSpawnedEnemies(childrenToAdd)
    }

    private func reportGameCenterAchievementEvent(_ event: GameCenterAchievementEvent) {
        guard !Self.isRunningUnitTests else {
            return
        }

        GameCenterService.shared.reportAchievementEvent(event)
    }

    private func removeEnemies(ids enemyIDs: Set<Int>) {
        enemies.removeAll { enemyIDs.contains($0.id) }
        removeFormationEnemies(ids: enemyIDs)

        for enemyID in enemyIDs {
            guard let node = enemyNodes.removeValue(forKey: enemyID) else {
                continue
            }

            let fade = SKAction.group([
                .scale(to: 0.35, duration: 0.08),
                .fadeOut(withDuration: 0.08)
            ])
            node.run(.sequence([fade, .removeFromParent()]))
        }
    }

    private func removeFormationEnemies(ids enemyIDs: Set<Int>) {
        for formationID in formationEnemyIDs.keys.sorted() {
            guard var remainingEnemyIDs = formationEnemyIDs[formationID] else {
                continue
            }

            remainingEnemyIDs.subtract(enemyIDs)

            if remainingEnemyIDs.isEmpty {
                formationEnemyIDs.removeValue(forKey: formationID)
            } else {
                formationEnemyIDs[formationID] = remainingEnemyIDs
            }
        }
    }

    private func activateRazorShield(
        at playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        activeRazorShieldConfiguration = configuration
        razorShieldTimeRemaining = configuration.razorShieldDuration
        hasPlayedRazorShieldWarning = false

        razorShieldNode?.removeFromParent()
        let node = SKShapeNode(circleOfRadius: configuration.razorShieldRadius)
        node.zPosition = 19
        styleRazorShieldNode(node)
        addWeaponEffectNode(node)
        razorShieldNode = node

        razorShieldNode?.position = playerPosition
        razorShieldNode?.isHidden = false
    }

    private var razorShieldConfiguration: StartingWeaponConfiguration {
        activeRazorShieldConfiguration ?? weaponResolver.configuration
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
        guard razorShieldTimeRemaining > 0 else {
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
        playRazorShieldImpactEffect(from: playerPosition, targets: targets) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .razorShield)
        }

        razorShieldTimeRemaining = max(0, razorShieldTimeRemaining - max(0, deltaTime))
        playRazorShieldWarningIfNeeded()

        if razorShieldTimeRemaining == 0 {
            triggerRazorShieldExpiryExplosion(at: playerPosition)
            deactivateRazorShield(emitHaptic: true)
            grantPostWeaponSafety(for: .razorShield)
        }
    }

    private func triggerRazorShieldExpiryExplosion(at playerPosition: CGPoint) {
        let configuration = razorShieldConfiguration
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
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .razorShield)
        }
    }

    private func deactivateRazorShield(emitHaptic: Bool = false) {
        let hadActiveShield = razorShieldNode != nil || razorShieldTimeRemaining > 0
        razorShieldTimeRemaining = 0
        activeRazorShieldConfiguration = nil
        hasPlayedRazorShieldWarning = false
        razorShieldNode?.removeFromParent()
        razorShieldNode = nil

        if emitHaptic, hadActiveShield, runController.phase == .active {
            playAudio(.shieldExpired)
            playHaptic(.shieldExpired)
        }
    }

    private func playRazorShieldWarningIfNeeded() {
        guard
            !hasPlayedRazorShieldWarning,
            razorShieldTimeRemaining > 0,
            razorShieldTimeRemaining <= gameTuning.feedback.razorShieldWarningLeadTime,
            runController.phase == .active
        else {
            return
        }

        hasPlayedRazorShieldWarning = true
        playAudio(.shieldWarning)
        playHaptic(.shieldWarning)
        let pulse = SKAction.sequence([
            .group([.fadeAlpha(to: 0.48, duration: 0.06), .scale(to: 1.12, duration: 0.06)]),
            .group([.fadeAlpha(to: 1, duration: 0.08), .scale(to: 1, duration: 0.08)])
        ])
        razorShieldNode?.run(.repeat(pulse, count: 3), withKey: "razor.warning")
    }

    private func updateFlameTrail(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let frame = flameTrailState.update(
            deltaTime: deltaTime,
            playerPosition: playerPosition,
            enemies: enemies
        )
        let targets = impactTargets(forEnemyIDs: frame.burnedEnemyIDs)
        playFlameTrailImpactEffect(at: targets) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .flameTrail)
        }
        flameTrailEffectNode.apply(segments: frame.segments)
    }

    private func activateFlameTrail(at playerPosition: CGPoint, chargeTier: WeaponPickupChargeTier = .base) {
        flameTrailState.configuration = gameTuning.flameTrail.applying(chargeTier: chargeTier)
        flameTrailState.activate(at: playerPosition)
        flameTrailSpeedBoostTimeRemaining = max(
            flameTrailSpeedBoostTimeRemaining,
            flameTrailState.configuration.duration
        )
        flameTrailInvulnerabilityTimeRemaining = max(
            flameTrailInvulnerabilityTimeRemaining,
            flameTrailState.configuration.invulnerabilityDuration,
            gameTuning.feedback.postWeaponSafetyDuration
        )
        flameTrailEffectNode.apply(segments: flameTrailState.segments)
    }

    private func updateFlameTrailTimers(deltaTime: TimeInterval) {
        let clampedDelta = max(0, deltaTime)
        let boostDelta = min(flameTrailSpeedBoostTimeRemaining, clampedDelta)

        flameTrailSpeedBoostTimeRemaining -= boostDelta
        flameTrailInvulnerabilityTimeRemaining = max(
            0,
            flameTrailInvulnerabilityTimeRemaining - (clampedDelta - boostDelta)
        )
    }

    private var isFlameTrailInvulnerable: Bool {
        flameTrailSpeedBoostTimeRemaining > 0 || flameTrailInvulnerabilityTimeRemaining > 0
    }

    private func grantPostWeaponSafety(for weaponKind: WeaponKind) {
        let duration = max(0, gameTuning.feedback.postWeaponSafetyDuration)
        guard duration > 0, runController.phase == .active else {
            return
        }

        postWeaponSafetyTimeRemaining = max(postWeaponSafetyTimeRemaining, duration)
        AppDiagnostics.logger(.weapon).debug("weapon.postSafety", metadata: [
            "kind": "\(weaponKind.rawValue)",
            "duration": "\(duration)"
        ])
    }

    private func updatePostWeaponSafety(deltaTime: TimeInterval) {
        guard postWeaponSafetyTimeRemaining > 0 else {
            return
        }

        postWeaponSafetyTimeRemaining = max(0, postWeaponSafetyTimeRemaining - max(0, deltaTime))
    }

    private func clearPostWeaponSafety() {
        postWeaponSafetyTimeRemaining = 0
    }

    private var isPostWeaponSafe: Bool {
        postWeaponSafetyTimeRemaining > 0
    }

    private var isPlayerCollisionProtected: Bool {
        isFlameTrailInvulnerable || isPostWeaponSafe
    }

    private func activateTimeDilationAura(
        at playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration
    ) -> Int {
        activeTimeDilationConfiguration = configuration
        timeDilationTimeRemaining = max(
            timeDilationTimeRemaining,
            configuration.timeDilationDuration
        )
        timeDilationAuraNode?.removeFromParent()
        timeDilationAuraNode = playTimeDilationAuraEffect(
            at: playerPosition,
            radius: configuration.timeDilationRadius,
            duration: timeDilationTimeRemaining
        )
        pushTimeDilationEnemies(from: playerPosition)
        return 0
    }

    private var timeDilationConfiguration: StartingWeaponConfiguration {
        activeTimeDilationConfiguration ?? weaponResolver.configuration
    }

    private func pushTimeDilationEnemies(from playerPosition: CGPoint) {
        let configuration = timeDilationConfiguration
        let pushRadius = max(0, configuration.timeDilationPushRadius)
        let maximumPushDistance = max(0, configuration.timeDilationMaximumPushDistance)

        guard pushRadius > 0, maximumPushDistance > 0 else {
            return
        }

        for index in enemies.indices {
            let distance = hypot(
                enemies[index].position.x - playerPosition.x,
                enemies[index].position.y - playerPosition.y
            )

            guard distance <= pushRadius else {
                continue
            }

            let strength = 1 - min(1, max(0, distance / pushRadius))
            enemies[index].pushAway(from: playerPosition, distance: maximumPushDistance * strength)
            enemyNodes[enemies[index].id]?.apply(enemies[index])
        }
    }

    private func updateTimeDilationAura(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard timeDilationTimeRemaining > 0 else {
            return
        }

        timeDilationAuraNode?.position = playerPosition
        timeDilationTimeRemaining = max(
            0,
            timeDilationTimeRemaining - max(0, deltaTime)
        )

        if timeDilationTimeRemaining == 0 {
            timeDilationAuraNode?.removeFromParent()
            timeDilationAuraNode = nil
            activeTimeDilationConfiguration = nil
            grantPostWeaponSafety(for: .warpDash)
        }
    }

    private func deactivateTimeDilationAura() {
        timeDilationTimeRemaining = 0
        activeTimeDilationConfiguration = nil
        timeDilationAuraNode?.removeFromParent()
        timeDilationAuraNode = nil
    }

    private func timeDilationEnemySpeedMultiplier(for enemy: ArenaEnemy, playerPosition: CGPoint) -> CGFloat {
        guard timeDilationTimeRemaining > 0 else {
            return 1
        }

        let configuration = timeDilationConfiguration
        let radius = max(0, configuration.timeDilationRadius)
        guard radius > 0 else {
            return 1
        }

        let distance = hypot(enemy.position.x - playerPosition.x, enemy.position.y - playerPosition.y)
        guard distance < radius else {
            return 1
        }

        let closeness = 1 - min(1, max(0, distance / radius))
        let maximumSlowFactor = max(1, configuration.timeDilationMaximumSlowFactor)
        let slowFactor = 1 + closeness * (maximumSlowFactor - 1)
        return 1 / slowFactor
    }

    private func fireRicochetLance(
        from playerPosition: CGPoint,
        configuration: StartingWeaponConfiguration
    ) -> Int {
        let result = RicochetLancePath.resolve(
            origin: playerPosition,
            direction: aimDirectionState.resolvedDirection(),
            playableRect: currentPlayableRect,
            enemies: enemies,
            configuration: configuration
        )
        let targets = impactTargets(forEnemyIDs: result.destroyedEnemyIDs)
        playRicochetLanceEffect(
            segments: result.segments,
            targets: targets,
            configuration: configuration
        ) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .ricochetLance)
            self?.grantPostWeaponSafety(for: .ricochetLance)
        }

        return targets.count
    }

    private func detectPlayerCollision(playerPosition: CGPoint) {
        guard !isPlayerCollisionProtected else {
            return
        }

        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )

        guard let collidingEnemy = enemies.first(where: {
            $0.canDamagePlayer
                && playerCircle.intersects($0.collisionCircle)
        }) else {
            return
        }

        finishRun(
            collision: DeathCollisionSnapshot(
                playerPosition: playerPosition,
                enemyPosition: collidingEnemy.position,
                enemyRadius: collidingEnemy.radius
            )
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

    private func updateRunDisplay() {
        timerLabel.alpha = uiState == .pause || uiState == .postRun ? 0.55 : 1

        switch uiState {
        case .home, .modeSelect, .awards, .weaponCodex, .options, .developerTuning, .calibrationPreview:
            timerLabel.isHidden = true
            bestMarkerLabel.isHidden = true
            comboLabel.isHidden = true
        case .preRun:
            timerLabel.isHidden = false
            bestMarkerLabel.isHidden = false
            comboLabel.isHidden = true
            timerLabel.text = "BEST \(runProfile.bestScore)"
            bestMarkerLabel.text = "\(selectedMode.displayName) READY"
        case .activeGameplay:
            timerLabel.isHidden = false
            bestMarkerLabel.isHidden = false
            comboLabel.isHidden = false
            timerLabel.text = "SCORE \(runController.score)  \(formatSurvivalTime(runController.survivalTime))"
            bestMarkerLabel.text = "BEST \(runProfile.bestScore)"
            comboLabel.text = formatCombo()
        case .pause:
            timerLabel.isHidden = false
            bestMarkerLabel.isHidden = false
            comboLabel.isHidden = false
            timerLabel.text = "SCORE \(runController.score)  \(formatSurvivalTime(runController.survivalTime))"
            bestMarkerLabel.text = "PAUSED"
            comboLabel.text = formatCombo()
        case .postRun:
            timerLabel.isHidden = false
            bestMarkerLabel.isHidden = true
            comboLabel.isHidden = true
            timerLabel.text = "BEST \(runProfile.bestScore)"
        }

    }

    private func formatSurvivalTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }

    private func formatCombo() -> String {
        let weaponComboText = formatWeaponCombo()
        guard runController.currentCombo > 0 else {
            return weaponComboText
        }

        let comboText = String(
            format: "COMBO %d  x%d  %.1fs",
            runController.currentCombo,
            runController.comboMultiplier,
            runController.comboTimeRemaining
        )
        guard !weaponComboText.isEmpty else {
            return comboText
        }

        return "\(comboText)  \(weaponComboText)"
    }

    private func formatWeaponCombo() -> String {
        if let event = runController.weaponComboEvent {
            return event.kind.hudLabel
        }

        guard let primer = runController.weaponComboPrimer else {
            return ""
        }

        return String(format: "%@ %.1fs", primer.family.hudLabel, primer.timeRemaining)
    }

    private func persistFinalRunIfNeeded() {
        guard !hasPersistedFinalRun, let summary = runController.finalizedSummary else {
            return
        }

        let result = runProfileStore.record(summary)
        runProfile = result.profile
        lastProgressionResult = result
        hasPersistedFinalRun = true
        if !Self.isRunningUnitTests {
            let gameCenterService = GameCenterService.shared
            gameCenterService.submitRunScore(summary)
            gameCenterService.reportAchievementEvent(.runFinished(summary))
        }
    }

}

private extension ArenaScene {
    func show(_ state: ArenaUISceneState) {
        if state != .options {
            resetDataArmed = false
        }
        if state != .home && state != .postRun {
            gameCenterStatusMessage = nil
        }

        uiState = state
        syncOrientationLock()
        updateRunDisplay()
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

    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var shouldLockCurrentOrientation: Bool {
        switch uiState {
        case .options:
            return optionsReturnState.requiresLockedRunOrientation
        case .developerTuning:
            return developerReturnState.requiresLockedRunOrientation
        default:
            return uiState.requiresLockedRunOrientation
        }
    }

    func rebuildUI() {
        uiRoot.removeAllChildren()
        uiHitTargets.removeAll()
        calibrationPreviewPlayerNode = nil
        calibrationPreviewTrailNode = nil
        tiltReadoutValueLabels.removeAll()
        tiltReadoutUpdateTime = 0
        readyProgressRing = nil
        readyStatusLabel = nil
        updatePersistentGameplayNodeVisibility()

        renderCurrentUI()

        updateRunDisplay()
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
            renderModeSelect()
        case .awards:
            renderAwards()
        case .weaponCodex:
            renderWeaponCodex()
        case .options:
            renderOptions()
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
            break
        case .pause:
            renderPause()
        case .postRun:
            renderPostRun()
        default:
            break
        }
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
        let bottomButtonSize = CGSize(width: 88, height: 38)
        addTitle("TILT ARENA", at: layout.titlePosition)
        addSmallLabel(
            "CLASSIC SURVIVAL",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 34),
            color: theme.borderColor,
            alignment: .left
        )
        addSmallLabel(
            "BEST \(runProfile.bestScore)",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 56),
            color: theme.playerAccentColor,
            alignment: .left
        )
        renderGameCenterStatusMessage(
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 78),
            alignment: .left
        )
        addPreviewThreats(in: layout.gameplayRect)
        addButton(
            "PLAY",
            frame: layout.stackedLowerRightButtonFrame(aboveBottomControlHeight: bottomButtonSize.height),
            action: .play,
            style: .primary
        )
        renderHomeNavigationButtons(layout: layout, buttonSize: bottomButtonSize)
        #if DEBUG
        addButton(
            "DEV",
            frame: CGRect(x: layout.safeRect.maxX - 70, y: layout.safeRect.maxY - 42, width: 70, height: 34),
            action: .openDeveloperTuning,
            style: .secondary
        )
        #endif
    }

    func renderHomeNavigationButtons(layout: ArenaLandscapeUILayout, buttonSize: CGSize) {
        addButton(
            "MODES",
            frame: layout.bottomButtonFrame(index: 0, count: 5, buttonSize: buttonSize),
            action: .openModes,
            style: .secondary
        )
        addButton(
            "AWARDS",
            frame: layout.bottomButtonFrame(index: 1, count: 5, buttonSize: buttonSize),
            action: .openAwards,
            style: .secondary
        )
        addButton(
            "WEAPONS",
            frame: layout.bottomButtonFrame(index: 2, count: 5, buttonSize: buttonSize),
            action: .openWeaponCodex,
            style: .secondary
        )
        addButton(
            "RANKS",
            frame: layout.bottomButtonFrame(index: 3, count: 5, buttonSize: buttonSize),
            action: .openClassicLeaderboard,
            style: .secondary
        )
        addButton(
            "OPTIONS",
            frame: layout.bottomButtonFrame(index: 4, count: 5, buttonSize: buttonSize),
            action: .openOptions,
            style: .secondary
        )
    }

    func renderModeSelect() {
        let layout = currentLandscapeLayout()
        let contentFrame = addMenuChrome(title: "MODES", layout: layout)

        let rows = ArenaMenuContent.modeRows(profile: runProfile, selectedMode: selectedMode)
        let detailWidth = min(168, contentFrame.width * 0.34)
        let columnGap: CGFloat = 14
        let rowWidth = max(0, contentFrame.width - detailWidth - columnGap)
        let rowSpacing: CGFloat = 8
        let availableRowHeight = (
            contentFrame.height - CGFloat(max(0, rows.count - 1)) * rowSpacing
        ) / CGFloat(max(1, rows.count))
        let rowHeight = min(
            50,
            max(40, availableRowHeight)
        )
        let rowStartY = contentFrame.maxY - rowHeight

        for (index, row) in rows.enumerated() {
            let frame = CGRect(
                x: contentFrame.minX,
                y: rowStartY - CGFloat(index) * (rowHeight + rowSpacing),
                width: rowWidth,
                height: rowHeight
            )
            addModeRow(row, frame: frame)
        }

        let detailFrame = CGRect(
            x: contentFrame.maxX - detailWidth,
            y: contentFrame.minY,
            width: detailWidth,
            height: contentFrame.height
        )
        renderSelectedModeSummary(in: detailFrame)
    }

    func renderAwards() {
        let layout = currentLandscapeLayout()
        let contentFrame = addMenuChrome(title: "AWARDS", layout: layout)

        let rows = ArenaMenuContent.awardRows(profile: runProfile)
        let unlockFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.maxY - 42,
            width: contentFrame.width,
            height: 42
        )
        renderActiveUnlockBanner(in: unlockFrame)

        let columnCount = 3
        let columnGap: CGFloat = 10
        let rowSpacing: CGFloat = 8
        let columnWidth = max(
            0,
            (contentFrame.width - CGFloat(columnCount - 1) * columnGap) / CGFloat(columnCount)
        )
        let awardTopY = unlockFrame.minY - 12
        let rowHeight = min(46, max(34, (awardTopY - contentFrame.minY - rowSpacing) / 2))

        for (index, row) in rows.enumerated() {
            let column = index % columnCount
            let rowIndex = index / columnCount
            let frame = CGRect(
                x: contentFrame.minX + CGFloat(column) * (columnWidth + columnGap),
                y: awardTopY - rowHeight - CGFloat(rowIndex) * (rowHeight + rowSpacing),
                width: columnWidth,
                height: rowHeight
            )
            addAwardRow(row, frame: frame)
        }
    }

    func renderWeaponCodex() {
        let layout = currentLandscapeLayout()
        let contentFrame = addMenuChrome(title: "WEAPONS", layout: layout)
        let rows = ArenaMenuContent.weaponCodexRows(profile: runProfile)

        let columnCount = 3
        let columnGap: CGFloat = 8
        let rowGap: CGFloat = 8
        let rowCount = Int(ceil(Double(rows.count) / Double(columnCount)))
        let columnWidth = max(
            0,
            (contentFrame.width - CGFloat(columnCount - 1) * columnGap) / CGFloat(columnCount)
        )
        let rowHeight = max(
            34,
            (
                contentFrame.height - CGFloat(max(0, rowCount - 1)) * rowGap
            ) / CGFloat(max(1, rowCount))
        )

        for (index, row) in rows.enumerated() {
            let column = index % columnCount
            let rowIndex = index / columnCount
            let frame = CGRect(
                x: contentFrame.minX + CGFloat(column) * (columnWidth + columnGap),
                y: contentFrame.maxY - rowHeight - CGFloat(rowIndex) * (rowHeight + rowGap),
                width: columnWidth,
                height: rowHeight
            )
            addWeaponCodexRow(row, frame: frame)
        }
    }

    func renderOptions() {
        let layout = currentLandscapeLayout()
        let contentFrame = addMenuChrome(title: "OPTIONS", layout: layout)

        let columnGap: CGFloat = 18
        let columnWidth = max(0, (contentFrame.width - columnGap) / 2)
        let left = CGRect(
            x: contentFrame.minX,
            y: contentFrame.minY,
            width: columnWidth,
            height: contentFrame.height
        )
        let right = CGRect(
            x: contentFrame.maxX - columnWidth,
            y: contentFrame.minY,
            width: columnWidth,
            height: contentFrame.height
        )
        addPanel(frame: left)
        addPanel(frame: right)

        renderTiltOptions(in: left)
        renderLocalOptions(in: right)
    }

    func renderDeveloperTuning() {
        let layout = currentLandscapeLayout()
        let contentFrame = addMenuChrome(title: "DEV TUNING", layout: layout)
        let changedCount = gameTuning.changedParameters().count

        renderDeveloperTuningHeaderActions(layout: layout, changedCount: changedCount)

        let menu = currentDeveloperTuningMenu()
        let frames = developerTuningFrames(in: contentFrame)
        renderDeveloperTuningSelector(
            title: "GROUP",
            items: menu.groups,
            selected: menu.selectedGroup,
            frame: frames.group,
            action: { .selectTuningGroup($0) }
        )
        renderDeveloperTuningSelector(
            title: "SUBGROUP",
            items: menu.subgroups,
            selected: menu.selectedSubgroup,
            frame: frames.subgroup,
            action: { .selectTuningSubgroup($0) }
        )
        renderDeveloperTuningParameterList(
            menu.parameters,
            selectedGroup: menu.selectedGroup,
            selectedSubgroup: menu.selectedSubgroup,
            frame: frames.parameters
        )
    }

    func renderDeveloperTuningHeaderActions(layout: ArenaLandscapeUILayout, changedCount: Int) {
        addButton(
            "COPY",
            frame: CGRect(x: layout.safeRect.maxX - 246, y: layout.safeRect.maxY - 48, width: 66, height: 34),
            action: .copyTuningParameters,
            style: changedCount == 0 ? .secondary : .primary
        )
        addButton(
            developerTuningChangedOnly ? "CHANGED" : "ALL",
            frame: CGRect(x: layout.safeRect.maxX - 174, y: layout.safeRect.maxY - 48, width: 98, height: 34),
            action: .toggleDeveloperTuningChangedOnly,
            style: developerTuningChangedOnly ? .primary : .secondary
        )
        addButton(
            "RESET",
            frame: CGRect(x: layout.safeRect.maxX - 68, y: layout.safeRect.maxY - 48, width: 54, height: 34),
            action: .resetTuningParameters,
            style: changedCount == 0 ? .secondary : .danger
        )

        if let developerTuningCopyConfirmation {
            addLabel(
                developerTuningCopyConfirmation,
                at: CGPoint(x: layout.safeRect.maxX - 14, y: layout.safeRect.maxY - 66),
                fontSize: 9,
                color: theme.playerAccentColor,
                alignment: .right
            )
        }
    }

    private func developerTuningFrames(in contentFrame: CGRect) -> DeveloperTuningFrames {
        let columnGap: CGFloat = contentFrame.width < 620 ? 8 : 12
        let groupWidth = min(126, max(102, contentFrame.width * 0.2))
        let subgroupWidth = min(148, max(116, contentFrame.width * 0.23))
        let group = CGRect(
            x: contentFrame.minX,
            y: contentFrame.minY,
            width: groupWidth,
            height: contentFrame.height
        )
        let subgroup = CGRect(
            x: group.maxX + columnGap,
            y: contentFrame.minY,
            width: subgroupWidth,
            height: contentFrame.height
        )
        let parameters = CGRect(
            x: subgroup.maxX + columnGap,
            y: contentFrame.minY,
            width: max(0, contentFrame.maxX - subgroup.maxX - columnGap),
            height: contentFrame.height
        )

        return DeveloperTuningFrames(group: group, subgroup: subgroup, parameters: parameters)
    }

    func developerTuningPageSize(in frame: CGRect) -> Int {
        let usableHeight = max(0, frame.height - 76)
        return max(1, Int(floor(usableHeight / developerTuningRowHeight(in: frame))))
    }

    func developerTuningRowHeight(in frame: CGRect) -> CGFloat {
        frame.height < 230 ? 28 : 32
    }

    private func currentDeveloperTuningMenu() -> DeveloperTuningMenu {
        let groups = GameTuningParameterCatalog.groupNames(
            changedOnly: developerTuningChangedOnly,
            tuning: gameTuning
        )
        if developerTuningSelectedGroup.map({ !groups.contains($0) }) ?? true {
            developerTuningSelectedGroup = groups.first
            developerTuningPageIndex = 0
        }

        guard let selectedGroup = developerTuningSelectedGroup else {
            developerTuningSelectedSubgroup = nil
            return DeveloperTuningMenu(
                groups: groups,
                selectedGroup: nil,
                subgroups: [],
                selectedSubgroup: nil,
                parameters: []
            )
        }

        let subgroups = GameTuningParameterCatalog.subgroupNames(
            in: selectedGroup,
            changedOnly: developerTuningChangedOnly,
            tuning: gameTuning
        )
        if developerTuningSelectedSubgroup.map({ !subgroups.contains($0) }) ?? true {
            developerTuningSelectedSubgroup = subgroups.first
            developerTuningPageIndex = 0
        }

        guard let selectedSubgroup = developerTuningSelectedSubgroup else {
            return DeveloperTuningMenu(
                groups: groups,
                selectedGroup: selectedGroup,
                subgroups: subgroups,
                selectedSubgroup: nil,
                parameters: []
            )
        }

        let parameters = GameTuningParameterCatalog.parameters(
            in: selectedGroup,
            subgroup: selectedSubgroup,
            changedOnly: developerTuningChangedOnly,
            tuning: gameTuning
        )

        return DeveloperTuningMenu(
            groups: groups,
            selectedGroup: selectedGroup,
            subgroups: subgroups,
            selectedSubgroup: selectedSubgroup,
            parameters: parameters
        )
    }

    func renderDeveloperTuningSelector(
        title: String,
        items: [String],
        selected: String?,
        frame: CGRect,
        action: (String) -> ArenaControlAction
    ) {
        addPanel(frame: frame)
        addSectionLabel(title, at: CGPoint(x: frame.minX + 10, y: frame.maxY - 15))

        guard !items.isEmpty else {
            addLabel(
                "NONE",
                at: CGPoint(x: frame.minX + 10, y: frame.maxY - 42),
                fontSize: 9,
                color: theme.borderColor.withAlphaComponent(0.75),
                alignment: .left
            )
            return
        }

        let headerHeight: CGFloat = 22
        let bottomPadding: CGFloat = 6
        let rowGap: CGFloat = 2
        let rowHeight = min(
            28,
            max(
                10,
                (
                    frame.height - headerHeight - bottomPadding - CGFloat(max(0, items.count - 1)) * rowGap
                ) / CGFloat(items.count)
            )
        )
        let rowFontSize = min(10, max(6.8, rowHeight * 0.42))

        for (index, item) in items.enumerated() {
            let rowFrame = CGRect(
                x: frame.minX + 6,
                y: frame.maxY - headerHeight - CGFloat(index + 1) * rowHeight - CGFloat(index) * rowGap,
                width: frame.width - 12,
                height: rowHeight
            )
            let isSelected = item == selected
            addPanel(
                frame: rowFrame,
                stroke: isSelected ? theme.playerAccentColor.withAlphaComponent(0.85) : theme.borderColor.withAlphaComponent(0.26),
                fill: isSelected ? theme.playerAccentColor.withAlphaComponent(0.11) : theme.backgroundColor.withAlphaComponent(0.28)
            )
            addLabel(
                truncatedMenuText(item.uppercased(), fontSize: rowFontSize, width: rowFrame.width - 14),
                at: CGPoint(x: rowFrame.minX + 7, y: rowFrame.midY),
                fontSize: rowFontSize,
                color: isSelected ? theme.playerAccentColor : theme.playerColor.withAlphaComponent(0.82),
                alignment: .left
            )
            uiHitTargets.append(ArenaControlHitTarget(action: action(item), frame: rowFrame))
        }
    }

    func renderDeveloperTuningParameterList(
        _ parameters: [GameTuningParameterSpec],
        selectedGroup: String?,
        selectedSubgroup: String?,
        frame: CGRect
    ) {
        addPanel(frame: frame)

        let changedCount = gameTuning.changedParameters().count
        renderDeveloperTuningParameterHeader(
            selectedGroup: selectedGroup,
            selectedSubgroup: selectedSubgroup,
            frame: frame,
            changedCount: changedCount
        )

        guard !parameters.isEmpty else {
            renderDeveloperTuningEmptyParameterList(in: frame)
            return
        }

        let pageSize = developerTuningPageSize(in: frame)
        let pageCount = max(1, Int(ceil(Double(parameters.count) / Double(pageSize))))
        developerTuningPageIndex = min(max(0, developerTuningPageIndex), pageCount - 1)

        renderDeveloperTuningPageControls(
            pageCount: pageCount,
            parameterCount: parameters.count,
            frame: frame
        )
        renderDeveloperTuningRows(parameters, pageSize: pageSize, frame: frame)
    }

    func renderDeveloperTuningParameterHeader(
        selectedGroup: String?,
        selectedSubgroup: String?,
        frame: CGRect,
        changedCount: Int
    ) {
        let heading = [selectedGroup, selectedSubgroup].compactMap { $0 }.joined(separator: " / ")
        let headingText = heading.isEmpty ? "NO PARAMETERS" : heading.uppercased()
        addLabel(
            truncatedMenuText(headingText, fontSize: 10, width: frame.width - 116),
            at: CGPoint(x: frame.minX + 10, y: frame.maxY - 17),
            fontSize: 10,
            color: theme.playerColor,
            alignment: .left
        )
        addLabel(
            "\(changedCount) CHANGED",
            at: CGPoint(x: frame.maxX - 10, y: frame.maxY - 17),
            fontSize: 8,
            color: changedCount == 0 ? theme.borderColor : theme.playerAccentColor,
            alignment: .right
        )
    }

    func renderDeveloperTuningEmptyParameterList(in frame: CGRect) {
        addLabel(
            developerTuningChangedOnly ? "NO CHANGED PARAMETERS" : "NO PARAMETERS",
            at: CGPoint(x: frame.midX, y: frame.midY),
            fontSize: 11,
            color: theme.borderColor.withAlphaComponent(0.78),
            alignment: .center
        )
    }

    func renderDeveloperTuningPageControls(pageCount: Int, parameterCount: Int, frame: CGRect) {
        let controlsY = frame.maxY - 46
        addButton(
            "<",
            frame: CGRect(x: frame.minX + 10, y: controlsY - 13, width: 34, height: 26),
            action: .developerTuningPreviousPage,
            style: developerTuningPageIndex == 0 ? .secondary : .primary
        )
        addButton(
            ">",
            frame: CGRect(x: frame.minX + 52, y: controlsY - 13, width: 34, height: 26),
            action: .developerTuningNextPage,
            style: developerTuningPageIndex + 1 >= pageCount ? .secondary : .primary
        )
        addLabel(
            "PAGE \(developerTuningPageIndex + 1)/\(pageCount)  \(parameterCount) VALUES",
            at: CGPoint(x: frame.minX + 98, y: controlsY),
            fontSize: 8,
            color: theme.borderColor,
            alignment: .left
        )
    }

    func renderDeveloperTuningRows(
        _ parameters: [GameTuningParameterSpec],
        pageSize: Int,
        frame: CGRect
    ) {
        let pageStart = developerTuningPageIndex * pageSize
        let pageEnd = min(parameters.count, pageStart + pageSize)
        let visibleParameters = Array(parameters[pageStart..<pageEnd])
        let rowHeight = developerTuningRowHeight(in: frame)
        let rowStartY = frame.maxY - 68
        for (index, parameter) in visibleParameters.enumerated() {
            let rowFrame = CGRect(
                x: frame.minX + 8,
                y: rowStartY - CGFloat(index + 1) * rowHeight,
                width: frame.width - 16,
                height: rowHeight - 4
            )
            renderDeveloperTuningRow(parameter, frame: rowFrame)
        }
    }

    func truncatedMenuText(_ text: String, fontSize: CGFloat, width: CGFloat) -> String {
        let maxCharacters = max(1, Int(width / max(1, fontSize * 0.62)))
        guard text.count > maxCharacters else {
            return text
        }
        guard maxCharacters > 3 else {
            return String(text.prefix(maxCharacters))
        }

        return "\(text.prefix(maxCharacters - 3))..."
    }

    func renderDeveloperTuningRow(_ parameter: GameTuningParameterSpec, frame: CGRect) {
        let isChanged = gameTuning.isChanged(parameter)
        addPanel(
            frame: frame,
            stroke: isChanged ? theme.playerAccentColor.withAlphaComponent(0.62) : theme.borderColor.withAlphaComponent(0.28),
            fill: isChanged ? theme.playerAccentColor.withAlphaComponent(0.08) : theme.backgroundColor.withAlphaComponent(0.42)
        )

        let compact = frame.width < 320
        if isChanged {
            addLabel(
                "*",
                at: CGPoint(x: frame.minX + 10, y: frame.midY),
                fontSize: 11,
                color: theme.playerAccentColor,
                alignment: .left
            )
        }
        let titleFontSize: CGFloat = compact ? 8 : 9
        let titleX = frame.minX + (isChanged ? 24 : 12)
        let titleMaxWidth = max(44, frame.maxX - titleX - 124)
        addLabel(
            truncatedMenuText(parameter.title.uppercased(), fontSize: titleFontSize, width: titleMaxWidth),
            at: CGPoint(x: titleX, y: frame.midY),
            fontSize: titleFontSize,
            color: theme.playerColor,
            alignment: .left
        )
        addLabel(
            parameter.displayValue(in: gameTuning),
            at: CGPoint(x: frame.maxX - 90, y: frame.midY),
            fontSize: 10,
            color: theme.playerAccentColor,
            alignment: .right
        )
        addButton(
            "-",
            frame: CGRect(x: frame.maxX - 78, y: frame.midY - 12, width: 32, height: 24),
            action: .adjustTuningParameter(parameter.id, .decrease),
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: frame.maxX - 38, y: frame.midY - 12, width: 32, height: 24),
            action: .adjustTuningParameter(parameter.id, .increase),
            style: .secondary
        )
    }

    func renderCalibrationPreview() {
        let layout = currentLandscapeLayout()
        addCalibrationPreviewWorld(layout: layout)

        let controlsFrame = calibrationControlsFrame(layout: layout)
        addPanel(
            frame: controlsFrame,
            fill: theme.panelFillColor.withAlphaComponent(0.98)
        )
        addCalibrationHeader(in: controlsFrame)
        renderCalibrationControls(in: controlsFrame)
        addSmallLabel(
            calibrationText,
            at: CGPoint(x: layout.safeRect.maxX - 12, y: layout.safeRect.minY + 20),
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

        let state = calibrationPreviewMovementController.clampToArena(currentGameplayBounds)
        applyCalibrationPreviewState(state, resetTrail: true)
    }

    func calibrationControlsFrame(layout: ArenaLandscapeUILayout) -> CGRect {
        let controlsWidth = min(278, max(252, layout.safeRect.width * 0.36))
        let controlsHeight = max(0, min(210, layout.safeRect.height - 28))
        return CGRect(
            x: layout.safeRect.minX + 14,
            y: layout.safeRect.maxY - controlsHeight - 14,
            width: controlsWidth,
            height: controlsHeight
        )
    }

    func addCalibrationHeader(in frame: CGRect) {
        addBackButton(
            frame: CGRect(
                x: frame.minX + 12,
                y: frame.maxY - 46,
                width: 42,
                height: 34
            )
        )
        addTitle(
            "CALIBRATE",
            at: CGPoint(x: frame.minX + 66, y: frame.maxY - 29)
        )
    }

    func renderCalibrationControls(in frame: CGRect) {
        let settings = tiltSettingsStore.settings
        addSectionLabel("NEUTRAL", at: CGPoint(x: frame.minX + 14, y: frame.maxY - 62))
        addButton(
            "SET",
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 100, width: 82, height: 34),
            action: .calibrate,
            style: .primary
        )
        addSmallLabel(
            "SENSITIVITY \(String(format: "%.1f", settings.clampedSensitivity))",
            at: CGPoint(x: frame.minX + 112, y: frame.maxY - 66),
            color: theme.borderColor,
            alignment: .left
        )
        addButton(
            "-",
            frame: CGRect(x: frame.minX + 112, y: frame.maxY - 112, width: 44, height: 30),
            action: .sensitivityDown,
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: frame.minX + 168, y: frame.maxY - 112, width: 44, height: 30),
            action: .sensitivityUp,
            style: .secondary
        )

        addSectionLabel("PRESET", at: CGPoint(x: frame.minX + 14, y: frame.maxY - 128))
        let presetY = frame.maxY - 164
        for (index, preset) in [TiltCalibrationPreset.standard, .flatTable, .reclined].enumerated() {
            let presetSpacing: CGFloat = 8
            let presetWidth = (frame.width - 28 - presetSpacing * 2) / 3
            let buttonFrame = CGRect(
                x: frame.minX + 14 + CGFloat(index) * (presetWidth + presetSpacing),
                y: presetY,
                width: presetWidth,
                height: 30
            )
            addButton(
                presetTitle(preset),
                frame: buttonFrame,
                action: .preset(preset),
                style: settings.calibration.preset == preset ? .primary : .secondary
            )
        }

        renderTiltReadout(in: CGRect(
            x: frame.minX + 14,
            y: frame.minY + 8,
            width: frame.width - 28,
            height: 24
        ))
    }

    func renderTiltOptions(in frame: CGRect) {
        addSectionLabel("TILT CONTROL", at: CGPoint(x: frame.minX + 14, y: frame.maxY - 22))
        addButton(
            "CALIBRATE",
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 64, width: 112, height: 34),
            action: .openCalibrationPreview,
            style: .primary
        )
        let settings = tiltSettingsStore.settings
        addSmallLabel(
            "SENS \(String(format: "%.1f", settings.clampedSensitivity))",
            at: CGPoint(x: frame.minX + 142, y: frame.maxY - 36),
            color: theme.borderColor,
            alignment: .left
        )
        addButton(
            "-",
            frame: CGRect(x: frame.minX + 142, y: frame.maxY - 82, width: 40, height: 30),
            action: .sensitivityDown,
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: frame.minX + 192, y: frame.maxY - 82, width: 40, height: 30),
            action: .sensitivityUp,
            style: .secondary
        )

        addSectionLabel("PRESET", at: CGPoint(x: frame.minX + 14, y: frame.minY + 70))
        let presetY = frame.minY + 22
        let presetSpacing: CGFloat = 8
        let presetWidth = min(74, max(44, (frame.width - 28 - presetSpacing * 2) / 3))
        for (index, preset) in [TiltCalibrationPreset.standard, .flatTable, .reclined].enumerated() {
            let buttonFrame = CGRect(
                x: frame.minX + 14 + CGFloat(index) * (presetWidth + presetSpacing),
                y: presetY,
                width: presetWidth,
                height: 34
            )
            addButton(
                presetTitle(preset),
                frame: buttonFrame,
                action: .preset(preset),
                style: settings.calibration.preset == preset ? .primary : .secondary
            )
        }
    }

    func renderTiltReadout(in frame: CGRect) {
        tiltReadoutValueLabels.removeAll()
        let rows = TiltReadoutFormatter.gameplayRows(
            for: nil,
            fallbackOrientation: currentTiltScreenOrientation
        )
        let startY = frame.maxY
        let rowSpacing: CGFloat = 16

        for (index, row) in rows.enumerated() {
            let y = startY - CGFloat(index) * rowSpacing
            addLabel(
                row.title,
                at: CGPoint(x: frame.minX + 14, y: y),
                fontSize: 10,
                color: theme.borderColor,
                alignment: .left
            )
            let valueLabel = makeLabel(
                row.value,
                at: CGPoint(x: frame.maxX - 14, y: y),
                fontSize: 10,
                color: theme.playerAccentColor,
                alignment: .right
            )
            tiltReadoutValueLabels.append(valueLabel)
            uiRoot.addChild(valueLabel)
        }

        updateTiltReadoutDisplay()
    }

    func renderLocalOptions(in frame: CGRect) {
        let contentMinX = frame.minX + 14
        let contentWidth = max(0, frame.width - 28)
        let rowSpacing: CGFloat = 10
        let pairedButtonWidth = max(0, (contentWidth - rowSpacing) / 2)

        addSectionLabel("FEEDBACK", at: CGPoint(x: contentMinX, y: frame.maxY - 22))
        renderLocalToggleOptions(
            contentMinX: contentMinX,
            topRowY: frame.maxY - 64,
            pairedButtonWidth: pairedButtonWidth,
            rowSpacing: rowSpacing
        )
        renderThemeOptions(
            contentMinX: contentMinX,
            contentWidth: contentWidth,
            themeRowY: frame.minY + 52,
            rowSpacing: rowSpacing
        )
        renderLocalActionOptions(
            contentMinX: contentMinX,
            bottomRowY: frame.minY + 14,
            pairedButtonWidth: pairedButtonWidth,
            rowSpacing: rowSpacing
        )
    }

    func renderLocalToggleOptions(
        contentMinX: CGFloat,
        topRowY: CGFloat,
        pairedButtonWidth: CGFloat,
        rowSpacing: CGFloat
    ) {
        addToggle(
            title: "AUDIO",
            isOn: localOptions.audioEnabled,
            frame: CGRect(x: contentMinX, y: topRowY, width: pairedButtonWidth, height: 34),
            action: .toggleAudio
        )
        addToggle(
            title: "HAPTICS",
            isOn: localOptions.hapticsEnabled,
            frame: CGRect(
                x: contentMinX + pairedButtonWidth + rowSpacing,
                y: topRowY,
                width: pairedButtonWidth,
                height: 34
            ),
            action: .toggleHaptics
        )
    }

    func renderThemeOptions(
        contentMinX: CGFloat,
        contentWidth: CGFloat,
        themeRowY: CGFloat,
        rowSpacing: CGFloat
    ) {
        let themeKinds = ArenaThemeKind.allCases
        let themeButtonWidth = max(
            0,
            (contentWidth - CGFloat(max(0, themeKinds.count - 1)) * rowSpacing) / CGFloat(themeKinds.count)
        )
        for (index, themeKind) in themeKinds.enumerated() {
            addButton(
                themeKind.shortTitle,
                frame: CGRect(
                    x: contentMinX + CGFloat(index) * (themeButtonWidth + rowSpacing),
                    y: themeRowY,
                    width: themeButtonWidth,
                    height: 32
                ),
                action: .selectTheme(themeKind),
                style: localOptions.themeKind == themeKind ? .primary : .secondary
            )
        }
    }

    func renderLocalActionOptions(
        contentMinX: CGFloat,
        bottomRowY: CGFloat,
        pairedButtonWidth: CGFloat,
        rowSpacing: CGFloat
    ) {
        addButton(
            "LOGS",
            frame: CGRect(x: contentMinX, y: bottomRowY, width: pairedButtonWidth, height: 30),
            action: .exportDiagnostics,
            style: .secondary
        )
        addButton(
            resetDataArmed ? "CONFIRM" : "RESET",
            frame: CGRect(
                x: contentMinX + pairedButtonWidth + rowSpacing,
                y: bottomRowY,
                width: pairedButtonWidth,
                height: 30
            ),
            action: .resetData,
            style: .danger
        )
    }

    func renderPreRun() {
        let layout = currentLandscapeLayout()
        addButton(
            "CAL",
            frame: CGRect(x: layout.safeRect.maxX - 112, y: layout.safeRect.maxY - 40, width: 48, height: 36),
            action: .openCalibrationPreview,
            style: .secondary
        )
        addButton(
            "OPT",
            frame: CGRect(x: layout.safeRect.maxX - 54, y: layout.safeRect.maxY - 40, width: 54, height: 36),
            action: .openOptions,
            style: .secondary
        )
        addReadyStartCircle(at: readyStartPoint)
        addLabel(
            "HOLD 3s TO START",
            at: CGPoint(x: layout.safeRect.midX, y: layout.safeRect.midY - 92),
            fontSize: 15,
            color: theme.playerColor,
            alignment: .center
        )
        addSmallLabel(
            selectedMode.displayName,
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.minY + 16),
            color: theme.borderColor,
            alignment: .left
        )
        addSmallLabel(
            calibrationText,
            at: CGPoint(x: layout.safeRect.maxX, y: layout.safeRect.minY + 16),
            color: theme.borderColor,
            alignment: .right
        )
        updateReadyProgressDisplay(readyHoldController.state)
    }

    func renderPause() {
        let layout = currentLandscapeLayout()
        addScrim(alpha: 0.58)
        addLabel(
            "PAUSED",
            at: CGPoint(x: layout.safeRect.midX, y: layout.safeRect.midY + 54),
            fontSize: 26,
            color: theme.playerColor,
            alignment: .center
        )
        addButton(
            "RESUME",
            frame: CGRect(x: layout.safeRect.midX - 82, y: layout.safeRect.midY - 20, width: 164, height: 50),
            action: .resume,
            style: .primary
        )
        addButton(
            "CALIBRATE",
            frame: CGRect(x: layout.safeRect.maxX - 150, y: layout.safeRect.midY + 12, width: 150, height: 38),
            action: .openCalibrationPreview,
            style: .secondary
        )
        addButton(
            "OPTIONS",
            frame: CGRect(x: layout.safeRect.maxX - 150, y: layout.safeRect.midY - 38, width: 150, height: 38),
            action: .openOptions,
            style: .secondary
        )
        #if DEBUG
        addButton(
            "DEV",
            frame: CGRect(x: layout.safeRect.maxX - 150, y: layout.safeRect.midY - 88, width: 150, height: 38),
            action: .openDeveloperTuning,
            style: .secondary
        )
        #endif
        addButton(
            "END RUN",
            frame: CGRect(x: layout.safeRect.minX, y: layout.safeRect.minY, width: 132, height: 36),
            action: .endRun,
            style: .danger
        )
    }

    func renderPostRun() {
        let layout = currentLandscapeLayout()
        addScrim(alpha: 0.62)
        let summary = runController.finalizedSummary

        renderPostRunScore(summary: summary, layout: layout)
        addDeathReplayTrace()
        addDeathClarityMarker(
            snapshot: lastDeathCollisionSnapshot,
            fallbackPosition: movementController.state.position
        )
        renderPostRunHighlights(summary: summary, in: postRunHighlightsFrame(layout: layout))
        renderPostRunButtons(layout: layout)
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
        addLabel(
            "GAME OVER",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 52),
            fontSize: 24,
            color: theme.enemyColor,
            alignment: .left
        )
        addLabel(
            "\(summary?.score ?? runController.score)",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 86),
            fontSize: 30,
            color: theme.playerColor,
            alignment: .left
        )
        addSmallLabel(
            summary?.score ?? 0 > previousBestScore ? "NEW BEST" : "BEST \(runProfile.bestScore)",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 112),
            color: theme.playerAccentColor,
            alignment: .left
        )
        renderGameCenterStatusMessage(
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 136),
            alignment: .left
        )
    }

    func renderPostRunHighlights(summary: RunSummary?, in frame: CGRect) {
        addPanel(frame: frame)
        let highlights = ArenaMenuContent.postRunHighlights(
            summary: summary,
            profile: runProfile,
            previousBestScore: previousBestScore,
            progressionResult: lastProgressionResult
        )
        let compact = frame.height < 150
        let topPadding: CGFloat = compact ? 22 : 28
        let bottomPadding: CGFloat = compact ? 14 : 18
        let availableHeight = max(0, frame.height - topPadding - bottomPadding)
        let rowSpacing = highlights.count > 1
            ? min(26, max(compact ? 14 : 18, availableHeight / CGFloat(highlights.count - 1)))
            : 0

        for (index, text) in highlights.enumerated() {
            addLabel(
                text,
                at: CGPoint(x: frame.minX + 14, y: frame.maxY - topPadding - CGFloat(index) * rowSpacing),
                fontSize: compact ? 10 : 12,
                color: index == 0 ? theme.playerAccentColor : theme.borderColor,
                alignment: .left
            )
        }
    }

    func renderPostRunButtons(layout: ArenaLandscapeUILayout) {
        let primaryFrame = layout.lowerRightButtonFrame
        addButton(
            "PLAY AGAIN",
            frame: primaryFrame,
            action: .playAgain,
            style: .primary
        )
        let navSpacing: CGFloat = 10
        let navAvailableWidth = max(0, primaryFrame.minX - layout.controlRect.minX - 20)
        let navButtonWidth = min(104, max(72, (navAvailableWidth - navSpacing * 2) / 3))
        let buttonSize = CGSize(width: navButtonWidth, height: 36)
        let navStartX = layout.controlRect.minX
        addButton(
            "MODES",
            frame: CGRect(x: navStartX, y: layout.controlRect.minY, width: buttonSize.width, height: buttonSize.height),
            action: .openModes,
            style: .secondary
        )
        addButton(
            "RANKS",
            frame: CGRect(
                x: navStartX + buttonSize.width + navSpacing,
                y: layout.controlRect.minY,
                width: buttonSize.width,
                height: buttonSize.height
            ),
            action: .openClassicLeaderboard,
            style: .secondary
        )
        addButton(
            "HOME",
            frame: CGRect(
                x: navStartX + (buttonSize.width + navSpacing) * 2,
                y: layout.controlRect.minY,
                width: buttonSize.width,
                height: buttonSize.height
            ),
            action: .home,
            style: .secondary
        )
    }

    func renderGameCenterStatusMessage(
        at position: CGPoint,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        guard let statusMessage = currentGameCenterStatusMessage() else {
            return
        }

        addSmallLabel(
            statusMessage,
            at: position,
            color: theme.playerAccentColor,
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
        case .exportDiagnostics:
            exportDiagnostics()
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
            gameCenterStatusMessage = nil
        case let .unavailable(reason):
            gameCenterStatusMessage = reason.gameplayStatusMessage
            rebuildUI()
        }
    }

    func currentGameCenterStatusMessage() -> String? {
        guard uiState == .home || uiState == .postRun else {
            return nil
        }

        return gameCenterStatusMessage
            ?? gameCenterDelegate?.arenaSceneGameCenterMenuStatus(self).menuMessage
    }

    func performNavigationAction(_ action: ArenaControlAction) {
        switch action {
        case .play where selectedModeIsAvailable:
            preparePreRun()
        case .playAgain:
            preparePreRun()
        case .openModes, .openAwards, .openWeaponCodex:
            openMenu(action)
        case .openOptions:
            optionsReturnState = uiState
            show(.options)
        case .openDeveloperTuning:
            developerReturnState = uiState
            developerTuningCopyConfirmation = nil
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
            show(calibrationReturnState)
            return
        }

        if uiState == .developerTuning {
            developerTuningCopyConfirmation = nil
            show(developerReturnState)
            return
        }

        show(uiState == .options ? optionsReturnState : .home)
    }

    func performRunControlAction(_ action: ArenaControlAction) {
        switch action {
        case let .selectMode(mode):
            guard modeRowsByKind[mode]?.isAvailable == true else {
                return
            }

            selectedMode = mode
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
            developerTuningPageIndex = max(0, developerTuningPageIndex - 1)
            rebuildUI()
        case .developerTuningNextPage:
            advanceDeveloperTuningPage()
        case let .selectTuningGroup(group):
            developerTuningSelectedGroup = group
            developerTuningSelectedSubgroup = nil
            developerTuningPageIndex = 0
            developerTuningCopyConfirmation = nil
            rebuildUI()
        case let .selectTuningSubgroup(subgroup):
            developerTuningSelectedSubgroup = subgroup
            developerTuningPageIndex = 0
            developerTuningCopyConfirmation = nil
            rebuildUI()
        case .toggleDeveloperTuningChangedOnly:
            developerTuningChangedOnly.toggle()
            developerTuningPageIndex = 0
            developerTuningCopyConfirmation = nil
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
        let pageSize = developerTuningPageSize(in: menuContentFrame(layout: currentLandscapeLayout()))
        let parameters = currentDeveloperTuningMenu().parameters
        let pageCount = max(
            1,
            Int(ceil(Double(parameters.count) / Double(pageSize)))
        )
        developerTuningPageIndex = min(pageCount - 1, developerTuningPageIndex + 1)
        rebuildUI()
    }

    func adjustDeveloperTuningParameter(id parameterID: String, direction: GameTuningAdjustmentDirection) {
        let oldPlayerRadius = gameTuning.playerMovement.visualRadius
        gameTuning.adjustParameter(id: parameterID, direction: direction)
        gameTuningStore.tuning = gameTuning
        let didChangePlayerRadius = oldPlayerRadius != gameTuning.playerMovement.visualRadius
        applyGameTuning(rebuildPlayerVisuals: didChangePlayerRadius)
        developerTuningCopyConfirmation = nil
        rebuildArena()
        layoutLabels()
        rebuildUI()
    }

    func copyChangedTuningParameters() {
        let changedCount = gameTuning.changedParameters().count
        UIPasteboard.general.string = gameTuning.sourceSnapshot(changedOnly: true)
        developerTuningCopyConfirmation = "COPIED \(changedCount)"
        AppDiagnostics.logger(.app).info("dev.tuning_copied", metadata: [
            "parameters": "\(changedCount)"
        ])
        rebuildUI()
    }

    func resetTuningParameters() {
        gameTuningStore.reset()
        gameTuning = .defaults
        developerTuningPageIndex = 0
        developerTuningSelectedGroup = nil
        developerTuningSelectedSubgroup = nil
        developerTuningChangedOnly = false
        developerTuningCopyConfirmation = "RESET"
        applyGameTuning(rebuildPlayerVisuals: true)
        rebuildArena()
        layoutLabels()
        rebuildUI()
        AppDiagnostics.logger(.app).notice("dev.tuning_reset")
    }

    func performLocalOptionToggle(_ action: ArenaControlAction) {
        switch action {
        case .toggleAudio:
            localOptions.audioEnabled.toggle()
            localOptionsStore.options = localOptions
            syncAudioOption()
            rebuildUI()
        case .toggleHaptics:
            localOptions.hapticsEnabled.toggle()
            localOptionsStore.options = localOptions
            syncHapticsOption()
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
            AppDiagnostics.logger(.app).notice("options.theme_changed", metadata: [
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

    func exportDiagnostics() {
        diagnosticsDelegate?.arenaSceneRequestsDiagnosticsExport(self, snapshot: diagnosticSnapshot())
    }

    func resetMenuPreviewIfNeeded() {
        guard uiState == .postRun || runController.phase == .gameOver else {
            return
        }

        runController = ClassicRunController(configuration: runController.configuration)
        resetGameplayObjects()
        readyHoldController.reset()
        deathReplayTrace.reset()
        lastDeathCollisionSnapshot = nil
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
    }

    var selectedModeIsAvailable: Bool {
        modeRowsByKind[selectedMode]?.isAvailable == true
    }

    var modeRowsByKind: [ArenaModeKind: ArenaModeRow] {
        Dictionary(
            uniqueKeysWithValues: ArenaMenuContent
                .modeRows(profile: runProfile, selectedMode: selectedMode)
                .map { ($0.kind, $0) }
        )
    }

    var calibrationText: String {
        "\(presetDisplayTitle(tiltSettingsStore.settings.calibration.preset)) CALIBRATION"
    }

    func resetLocalDataOrArmConfirmation() {
        guard resetDataArmed else {
            resetDataArmed = true
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
        lastProgressionResult = nil
        selectedMode = .classic
        resetDataArmed = false
        AppDiagnostics.logger(.profile).warning("profile.reset")
        applyThemeChange()
    }

    func logFinishedRun(isNewBest: Bool) {
        guard let summary = runController.finalizedSummary else {
            AppDiagnostics.logger(.run).error("run.finished_missing_summary")
            return
        }

        AppDiagnostics.logger(.run).notice("run.finished", metadata: [
            "mode": "\(summary.mode.rawValue)",
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
            selectedMode: selectedMode.rawValue,
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
                bestScore: runProfile.bestScore,
                highestCombo: runProfile.highestCombo,
                longestSurvivalTime: runProfile.longestSurvivalTime,
                totalRuns: runProfile.totalRuns,
                totalEnemiesDestroyed: runProfile.totalEnemiesDestroyed,
                unlockedWeaponCount: runProfile.unlockedWeapons.count,
                earnedAwardCount: runProfile.earnedAwardIDs.count
            )
        )
    }

    func addReadyStartCircle(at point: CGPoint) {
        let radius = readyHoldController.configuration.startCircleRadius
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.position = point
        circle.zPosition = ArenaUIZPosition.content
        circle.strokeColor = theme.playerAccentColor.withAlphaComponent(0.68)
        circle.fillColor = theme.playerAccentColor.withAlphaComponent(0.04)
        circle.lineWidth = 2
        circle.glowWidth = 1
        uiRoot.addChild(circle)

        let progress = SKShapeNode(circleOfRadius: radius + 8)
        progress.position = point
        progress.zPosition = ArenaUIZPosition.progress
        progress.strokeColor = theme.playerColor.withAlphaComponent(0.66)
        progress.fillColor = .clear
        progress.lineWidth = 2
        progress.glowWidth = 0.65
        uiRoot.addChild(progress)
        readyProgressRing = progress

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 18
        label.fontColor = theme.playerColor
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = point
        label.zPosition = ArenaUIZPosition.label
        uiRoot.addChild(label)
        readyStatusLabel = label

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
            uiRoot.addChild(tick)
        }
    }

    func updateReadyProgressDisplay(_ state: ReadyStartHoldState) {
        let progress = state.progressFraction(requiredDuration: readyHoldController.configuration.requiredDuration)
        readyProgressRing?.setScale(0.55 + CGFloat(progress) * 0.45)
        readyProgressRing?.alpha = 0.35 + CGFloat(progress) * 0.65

        if state.isInsideCircle {
            let remaining = max(0, readyHoldController.configuration.requiredDuration - state.elapsed)
            readyStatusLabel?.text = String(format: "%.1f", remaining)
        } else {
            readyStatusLabel?.text = "CENTER"
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
            uiRoot.addChild(dot)
        }

        let pickup = SKShapeNode(circleOfRadius: 9)
        pickup.position = CGPoint(x: center.x + 52, y: center.y - 36)
        pickup.zPosition = ArenaUIZPosition.preview
        pickup.fillColor = theme.pickupAmber.withAlphaComponent(0.25)
        pickup.strokeColor = theme.pickupAmber
        pickup.lineWidth = 2
        uiRoot.addChild(pickup)
    }

    func addDeathReplayTrace() {
        guard deathReplayTrace.samples.count >= 2 else {
            return
        }

        let path = CGMutablePath()
        path.move(to: deathReplayTrace.samples[0].position)
        for sample in deathReplayTrace.samples.dropFirst() {
            path.addLine(to: sample.position)
        }

        let line = SKShapeNode(path: path)
        line.zPosition = ArenaUIZPosition.content
        line.strokeColor = theme.playerAccentColor.withAlphaComponent(0.3)
        line.lineWidth = 2
        line.glowWidth = theme.kind == .darkTacticalRadar ? 0.45 : 0
        uiRoot.addChild(line)
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
        uiRoot.addChild(ring)

        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: position.x - 22, y: position.y))
        crossPath.addLine(to: CGPoint(x: position.x + 22, y: position.y))
        crossPath.move(to: CGPoint(x: position.x, y: position.y - 22))
        crossPath.addLine(to: CGPoint(x: position.x, y: position.y + 22))
        let cross = SKShapeNode(path: crossPath)
        cross.strokeColor = theme.enemyColor
        cross.lineWidth = 1.5
        cross.zPosition = ArenaUIZPosition.content
        uiRoot.addChild(cross)

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
        uiRoot.addChild(enemy)

        let impactPath = CGMutablePath()
        impactPath.move(to: snapshot.playerPosition)
        impactPath.addLine(to: snapshot.enemyPosition)
        let impactLine = SKShapeNode(path: impactPath)
        impactLine.zPosition = ArenaUIZPosition.content
        impactLine.strokeColor = theme.enemyColor.withAlphaComponent(0.55)
        impactLine.lineWidth = 1.2
        uiRoot.addChild(impactLine)
    }

    func addMenuChrome(title: String, layout: ArenaLandscapeUILayout) -> CGRect {
        addMenuBackdrop(layout: layout)
        addBackButton(
            frame: CGRect(
                x: layout.safeRect.minX + 14,
                y: layout.safeRect.maxY - 48,
                width: 42,
                height: 34
            )
        )
        addTitle(title, at: CGPoint(x: layout.safeRect.minX + 68, y: layout.safeRect.maxY - 31))
        addDividerLine(
            from: CGPoint(x: layout.safeRect.minX + 14, y: layout.safeRect.maxY - 62),
            to: CGPoint(x: layout.safeRect.maxX - 14, y: layout.safeRect.maxY - 62),
            color: theme.panelStrokeColor.withAlphaComponent(0.72)
        )

        return menuContentFrame(layout: layout)
    }

    func menuContentFrame(layout: ArenaLandscapeUILayout) -> CGRect {
        CGRect(
            x: layout.safeRect.minX + 14,
            y: layout.safeRect.minY + 16,
            width: max(0, layout.safeRect.width - 28),
            height: max(0, layout.safeRect.height - 76)
        )
    }

    func addMenuBackdrop(layout: ArenaLandscapeUILayout) {
        let backdrop = SKShapeNode(rect: layout.safeRect, cornerRadius: 10)
        backdrop.zPosition = ArenaUIZPosition.scrim
        backdrop.fillColor = theme.panelFillColor
        backdrop.strokeColor = theme.panelStrokeColor.withAlphaComponent(0.65)
        backdrop.lineWidth = 1.2
        uiRoot.addChild(backdrop)
    }

    func renderSelectedModeSummary(in frame: CGRect) {
        guard let row = modeRowsByKind[selectedMode] else {
            return
        }

        addPanel(frame: frame, stroke: theme.playerAccentColor.withAlphaComponent(0.62))
        addSectionLabel("SELECTED MODE", at: CGPoint(x: frame.minX + 14, y: frame.maxY - 24))
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 54),
            fontSize: 18,
            color: theme.playerColor,
            alignment: .left
        )
        addSmallLabel(
            row.subtitle.uppercased(),
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 78),
            color: theme.borderColor,
            alignment: .left
        )
        let metadataY = frame.minY + 66
        addLabel(
            row.progressText,
            at: CGPoint(x: frame.minX + 14, y: metadataY),
            fontSize: 10,
            color: theme.playerAccentColor,
            alignment: .left
        )
        addButton(
            "PLAY",
            frame: CGRect(x: frame.minX + 14, y: frame.minY + 14, width: frame.width - 28, height: 40),
            action: .play,
            style: .primary
        )
    }

    func renderActiveUnlockBanner(in frame: CGRect) {
        addPanel(frame: frame, stroke: theme.playerAccentColor.withAlphaComponent(0.55))
        addSectionLabel("NEXT UNLOCK", at: CGPoint(x: frame.minX + 14, y: frame.midY + 7))
        addLabel(
            ArenaMenuContent.activeUnlockText(profile: runProfile),
            at: CGPoint(x: frame.minX + 132, y: frame.midY - 1),
            fontSize: 13,
            color: theme.playerAccentColor,
            alignment: .left
        )
    }

    func addModeRow(_ row: ArenaModeRow, frame: CGRect) {
        let selected = row.kind == selectedMode
        let detailFontSize: CGFloat = frame.width < 340 ? 10 : 12
        addPanel(
            frame: frame,
            stroke: selected ? theme.playerAccentColor.withAlphaComponent(0.85) : theme.borderColor.withAlphaComponent(0.35),
            fill: selected ? theme.playerAccentColor.withAlphaComponent(0.09) : theme.backgroundColor.withAlphaComponent(0.55)
        )
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 16),
            fontSize: 15,
            color: row.isAvailable ? theme.playerColor : theme.borderColor.withAlphaComponent(0.75),
            alignment: .left
        )
        addLabel(
            row.subtitle,
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 12),
            fontSize: detailFontSize,
            color: theme.borderColor,
            alignment: .left
        )
        addSmallLabel(
            row.statusText,
            at: CGPoint(x: frame.maxX - 14, y: frame.maxY - 16),
            color: row.isAvailable ? theme.playerAccentColor : theme.borderColor,
            alignment: .right
        )
        addLabel(
            row.progressText,
            at: CGPoint(x: frame.maxX - 14, y: frame.minY + 12),
            fontSize: detailFontSize,
            color: theme.borderColor,
            alignment: .right
        )
        uiHitTargets.append(ArenaControlHitTarget(action: .selectMode(row.kind), frame: frame))
    }

    func addAwardRow(_ row: ArenaAwardRow, frame: CGRect) {
        addPanel(frame: frame, stroke: row.isComplete ? theme.playerAccentColor : theme.borderColor.withAlphaComponent(0.35))
        let fontSize: CGFloat = frame.width < 170 ? 10 : 12
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 12, y: frame.maxY - 17),
            fontSize: fontSize,
            color: row.isComplete ? theme.playerAccentColor : theme.playerColor,
            alignment: .left
        )
        addLabel(
            row.progressText,
            at: CGPoint(x: frame.maxX - 12, y: frame.maxY - 17),
            fontSize: fontSize,
            color: theme.borderColor,
            alignment: .right
        )
        addProgressBar(
            frame: CGRect(x: frame.minX + 12, y: frame.minY + 9, width: frame.width - 24, height: 5),
            fraction: row.progressFraction
        )
    }

    func addWeaponCodexRow(_ row: WeaponCodexRow, frame: CGRect) {
        let strokeColor = row.isUnlocked
            ? theme.playerAccentColor.withAlphaComponent(0.58)
            : theme.borderColor.withAlphaComponent(0.28)
        let fillColor = row.isUnlocked
            ? theme.playerAccentColor.withAlphaComponent(0.06)
            : theme.backgroundColor.withAlphaComponent(0.46)
        addPanel(frame: frame, stroke: strokeColor, fill: fillColor)

        let compact = frame.height < 42
        let iconRadius = min(compact ? 8 : 10, max(6, frame.height * 0.22))
        let iconPosition = CGPoint(x: frame.minX + 14, y: frame.maxY - (compact ? 10 : 13))
        addWeaponCodexIcon(kind: row.kind, position: iconPosition, radius: iconRadius, isUnlocked: row.isUnlocked)

        let titleX = iconPosition.x + iconRadius + 8
        let titleWidth = max(30, frame.maxX - titleX - 48)
        addLabel(
            truncatedMenuText(row.title, fontSize: compact ? 7.4 : 8.4, width: titleWidth),
            at: CGPoint(x: titleX, y: iconPosition.y),
            fontSize: compact ? 7.4 : 8.4,
            color: row.isUnlocked ? theme.playerColor : theme.borderColor.withAlphaComponent(0.78),
            alignment: .left
        )

        addLabel(
            row.statusText,
            at: CGPoint(x: frame.maxX - 8, y: iconPosition.y),
            fontSize: compact ? 5.8 : 6.6,
            color: row.isUnlocked ? theme.playerAccentColor : theme.borderColor.withAlphaComponent(0.72),
            alignment: .right
        )

        addLabel(
            truncatedMenuText(row.description.uppercased(), fontSize: compact ? 5.8 : 6.6, width: frame.width - 18),
            at: CGPoint(x: frame.minX + 9, y: frame.midY - (compact ? 1 : 2)),
            fontSize: compact ? 5.8 : 6.6,
            color: theme.playerColor.withAlphaComponent(row.isUnlocked ? 0.78 : 0.48),
            alignment: .left
        )

        addLabel(
            truncatedMenuText(row.unlockText, fontSize: compact ? 5.8 : 6.4, width: frame.width - 18),
            at: CGPoint(x: frame.minX + 9, y: frame.minY + (compact ? 8 : 10)),
            fontSize: compact ? 5.8 : 6.4,
            color: theme.playerAccentColor.withAlphaComponent(row.isUnlocked ? 0.82 : 0.52),
            alignment: .left
        )
    }

    func addWeaponCodexIcon(
        kind: WeaponKind,
        position: CGPoint,
        radius: CGFloat,
        isUnlocked: Bool
    ) {
        let color = theme.playerAccentColor
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = position
        ring.zPosition = ArenaUIZPosition.content
        ring.fillColor = color.withAlphaComponent(isUnlocked ? 0.12 : 0.03)
        ring.strokeColor = color.withAlphaComponent(isUnlocked ? 0.7 : 0.24)
        ring.lineWidth = 0.9
        uiRoot.addChild(ring)

        let icon = SKSpriteNode(texture: WeaponSpriteSheet.texture(for: kind, role: .icon))
        icon.position = position
        icon.zPosition = ArenaUIZPosition.label
        icon.size = CGSize(width: radius * 1.65, height: radius * 1.65)
        icon.alpha = isUnlocked ? 0.92 : 0.35
        icon.blendMode = .alpha
        uiRoot.addChild(icon)
    }

    func addToggle(title: String, isOn: Bool, frame: CGRect, action: ArenaControlAction) {
        addButton(
            "\(title) \(isOn ? "ON" : "OFF")",
            frame: frame,
            action: action,
            style: isOn ? .primary : .secondary
        )
    }

    func addBackButton(frame: CGRect) {
        addButton(
            "<",
            frame: frame,
            action: .back,
            style: .secondary
        )
    }

    func addScrim(alpha: CGFloat) {
        let scrim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        scrim.zPosition = ArenaUIZPosition.scrim
        scrim.fillColor = SKColor.black.withAlphaComponent(alpha)
        scrim.strokeColor = .clear
        uiRoot.addChild(scrim)
    }

    func addPanel(
        frame: CGRect,
        stroke: SKColor? = nil,
        fill: SKColor? = nil
    ) {
        let panel = SKShapeNode(rect: frame, cornerRadius: 8)
        panel.zPosition = ArenaUIZPosition.panel
        panel.fillColor = fill ?? theme.panelFillColor
        panel.strokeColor = stroke ?? theme.panelStrokeColor
        panel.lineWidth = 1
        uiRoot.addChild(panel)
    }

    func addProgressBar(frame: CGRect, fraction: Double) {
        let background = SKShapeNode(rect: frame, cornerRadius: 2)
        background.zPosition = ArenaUIZPosition.control
        background.fillColor = theme.borderColor.withAlphaComponent(0.18)
        background.strokeColor = .clear
        uiRoot.addChild(background)

        let fillWidth = max(0, frame.width * CGFloat(min(1, max(0, fraction))))
        guard fillWidth > 0 else {
            return
        }

        let fill = SKShapeNode(
            rect: CGRect(x: frame.minX, y: frame.minY, width: fillWidth, height: frame.height),
            cornerRadius: 2
        )
        fill.zPosition = ArenaUIZPosition.controlFill
        fill.fillColor = theme.playerAccentColor.withAlphaComponent(0.85)
        fill.strokeColor = .clear
        uiRoot.addChild(fill)
    }

    func addDividerLine(from start: CGPoint, to end: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        let line = SKShapeNode(path: path)
        line.zPosition = ArenaUIZPosition.panel
        line.strokeColor = color
        line.lineWidth = 1
        uiRoot.addChild(line)
    }

    func addButton(
        _ title: String,
        frame: CGRect,
        action: ArenaControlAction,
        style: ArenaButtonStyle
    ) {
        let fill: SKColor
        let stroke: SKColor
        let text: SKColor

        switch style {
        case .primary:
            fill = theme.playerAccentColor.withAlphaComponent(0.22)
            stroke = theme.playerAccentColor.withAlphaComponent(0.95)
            text = theme.playerColor
        case .secondary:
            fill = theme.borderColor.withAlphaComponent(0.13)
            stroke = theme.borderColor.withAlphaComponent(0.68)
            text = theme.playerColor.withAlphaComponent(0.76)
        case .danger:
            fill = theme.enemyColor.withAlphaComponent(0.12)
            stroke = theme.enemyColor.withAlphaComponent(0.72)
            text = theme.enemyColor.withAlphaComponent(0.9)
        }

        let button = SKShapeNode(rect: frame, cornerRadius: 7)
        button.zPosition = ArenaUIZPosition.control
        button.fillColor = fill
        button.strokeColor = stroke
        button.lineWidth = 1
        uiRoot.addChild(button)

        addLabel(
            title,
            at: CGPoint(x: frame.midX, y: frame.midY - 1),
            fontSize: 14,
            color: text,
            alignment: .center
        )
        uiHitTargets.append(ArenaControlHitTarget(action: action, frame: frame))
    }

    func addTitle(_ text: String, at position: CGPoint) {
        addLabel(text, at: position, fontSize: 22, color: theme.playerColor, alignment: .left)
    }

    func addSmallLabel(
        _ text: String,
        at position: CGPoint,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        addLabel(text, at: position, fontSize: 12, color: color, alignment: alignment)
    }

    func addSectionLabel(_ text: String, at position: CGPoint) {
        addLabel(
            text,
            at: position,
            fontSize: 10,
            color: theme.borderColor.withAlphaComponent(0.82),
            alignment: .left
        )
    }

    func addLabel(
        _ text: String,
        at position: CGPoint,
        fontSize: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        uiRoot.addChild(makeLabel(text, at: position, fontSize: fontSize, color: color, alignment: alignment))
    }

    func makeLabel(
        _ text: String,
        at position: CGPoint,
        fontSize: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: fontSize >= 16 ? "Menlo-Bold" : "Menlo")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = ArenaUIZPosition.label
        return label
    }

    func presetTitle(_ preset: TiltCalibrationPreset) -> String {
        switch preset {
        case .standard:
            return "STD"
        case .flatTable:
            return "TABLE"
        case .reclined:
            return "RECL"
        case .custom:
            return "CUSTOM"
        }
    }

    func presetDisplayTitle(_ preset: TiltCalibrationPreset) -> String {
        switch preset {
        case .standard:
            return "STANDARD"
        case .flatTable:
            return "TABLE"
        case .reclined:
            return "RECLINED"
        case .custom:
            return "CUSTOM"
        }
    }
}

#if DEBUG
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
        self.selectedMode = selectedMode
        self.resetDataArmed = resetDataArmed
        optionsReturnState = .home
        calibrationReturnState = .home
        developerReturnState = .home
        developerTuningPageIndex = 0
        developerTuningSelectedGroup = nil
        developerTuningSelectedSubgroup = nil
        developerTuningChangedOnly = false
        developerTuningCopyConfirmation = nil
        gameTuning = .defaults
        applyGameTuning(rebuildPlayerVisuals: true)
        gameCenterStatusMessage = nil
        lastProgressionResult = nil
        lastDeathCollisionSnapshot = nil
        hasPersistedFinalRun = false
        runController = ClassicRunController()
        readyHoldController.reset()
        deathReplayTrace.reset()
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
            finishSeededRunVisualSnapshot(profile: profile, selectedMode: selectedMode)
            show(.postRun)
        case .home, .modeSelect, .awards, .weaponCodex, .options, .developerTuning, .calibrationPreview:
            show(state)
        }
    }

    private func prepareSeededRunVisualSnapshot(profile: RunProfile, selectedMode: ArenaModeKind) {
        self.runProfile = profile
        self.selectedMode = selectedMode
        previousBestScore = profile.bestScore
        lastProgressionResult = nil
        lastDeathCollisionSnapshot = nil
        hasPersistedFinalRun = false
        runController = ClassicRunController(configuration: runController.configuration)
        runController.start()
        runController.update(deltaTime: 38.4)
        _ = runController.recordItemPickup(pickupID: 1)
        runController.recordEnemyKills(count: 14, weaponKind: .chainLightning)
        deathReplayTrace.reset()
        seedDeathReplayTraceForSnapshot()
        resetGameplayObjects()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
    }

    private func finishSeededRunVisualSnapshot(profile: RunProfile, selectedMode: ArenaModeKind) {
        runController.endRun(
            at: Date(timeIntervalSince1970: 1_800),
            mode: selectedMode
        )
        guard let summary = runController.finalizedSummary else {
            return
        }

        var updatedProfile = profile
        let result = updatedProfile.record(summary)
        runProfile = updatedProfile
        lastProgressionResult = result
        hasPersistedFinalRun = true

        let playerPosition = movementController.state.position
        lastDeathCollisionSnapshot = DeathCollisionSnapshot(
            playerPosition: playerPosition,
            enemyPosition: CGPoint(x: playerPosition.x + 24, y: playerPosition.y - 10),
            enemyRadius: 12
        )
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
            deathReplayTrace.record(
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
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(
            size: size,
            arenaRect: currentGameplayBounds
        )
        addChild(arenaRoot)
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

    func prepareActiveRunForTesting() {
        localOptions = ArenaLocalOptions(
            audioEnabled: false,
            hapticsEnabled: false,
            themeKind: localOptions.themeKind
        )
        syncAudioOption()
        syncHapticsOption()
        preparePreRun()
        startRun()
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

    func grantPostWeaponSafetyForTesting(_ weaponKind: WeaponKind = .chainLightning) {
        grantPostWeaponSafety(for: weaponKind)
    }

    func advancePostWeaponSafetyForTesting(deltaTime: TimeInterval) {
        updatePostWeaponSafety(deltaTime: deltaTime)
    }

    func detectPlayerCollisionForTesting(playerPosition: CGPoint) {
        detectPlayerCollision(playerPosition: playerPosition)
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

    func playSeekerSwarmForTesting(enemyIDs: Set<Int>, from playerPosition: CGPoint) {
        playSeekerSwarm(
            enemyIDs: enemyIDs,
            from: playerPosition,
            configuration: weaponResolver.configuration
        )
    }

    func activateGravityWellForTesting(
        center: CGPoint,
        enemyIDs: Set<Int>,
        configuration: StartingWeaponConfiguration
    ) {
        activateGravityWell(at: center, enemyIDs: enemyIDs, configuration: configuration)
    }

    func resolveSeekerExplosionForTesting(at target: WeaponImpactTarget) {
        resolveSeekerExplosion(at: target, resolver: weaponResolver)
    }

    var enemyIDsForTesting: Set<Int> {
        Set(enemies.map(\.id))
    }

    var enemyNodeCountForTesting: Int {
        enemyNodes.count
    }

    var playerPositionForTesting: CGPoint {
        movementController.state.position
    }

    var isRunGameOverForTesting: Bool {
        runController.phase == .gameOver
    }

    var isWeaponEffectPlaybackPausedForTesting: Bool {
        weaponEffectsRoot.isPaused
    }

    var weaponEffectNodeCountForTesting: Int {
        weaponEffectsRoot.children.count
    }

    var developerTuningPageIndexForTesting: Int {
        developerTuningPageIndex
    }

    var devTuningPageCountForTesting: Int {
        let pageSize = developerTuningPageSize(in: menuContentFrame(layout: currentLandscapeLayout()))
        let parameters = currentDeveloperTuningMenu().parameters
        return max(1, Int(ceil(Double(parameters.count) / Double(pageSize))))
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
        uiHitTargets.filter { $0.action == .openClassicLeaderboard }.count
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

    func toggleDeveloperTuningChangedOnlyForTesting() {
        performDeveloperTuningAction(.toggleDeveloperTuningChangedOnly)
    }

    func adjustTuningParameterForTesting(id: String, direction: GameTuningAdjustmentDirection) {
        performDeveloperTuningAction(.adjustTuningParameter(id, direction))
    }
}
#endif

private extension ArenaScene {
    func activateShockwaveWave(
        at center: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        shockwaveWaveStates.append(
            ShockwaveWaveState(
                center: center,
                maximumRadius: configuration.shockwaveRadius,
                expansionDuration: configuration.shockwaveExpansionDuration,
                holdDuration: configuration.shockwaveHoldDuration
            )
        )
        playShockwaveEffect(
            at: center,
            radius: configuration.shockwaveRadius,
            duration: configuration.shockwaveExpansionDuration,
            holdDuration: configuration.shockwaveHoldDuration
        )
    }

    func updateShockwaveWaves(deltaTime: TimeInterval) {
        guard !shockwaveWaveStates.isEmpty else {
            return
        }

        var activeStates: [ShockwaveWaveState] = []
        var didCompleteWave = false
        for var state in shockwaveWaveStates {
            let frame = state.update(deltaTime: deltaTime, enemies: enemies)
            destroyEnemies(ids: frame.destroyedEnemyIDs, weaponKind: .shockwave)
            if !frame.isComplete {
                activeStates.append(state)
            } else {
                didCompleteWave = true
            }
        }
        shockwaveWaveStates = activeStates
        if didCompleteWave {
            grantPostWeaponSafety(for: .shockwave)
        }
    }

    func activateFreezeBurstWave(
        at center: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        freezeBurstWaveStates.append(
            FreezeBurstWaveState(
                center: center,
                maximumRadius: configuration.freezeBurstRadius,
                duration: configuration.freezeExpansionDuration,
                freezeDuration: configuration.freezeDuration,
                thawGraceDuration: configuration.freezeThawGraceDuration
            )
        )
        playFreezeBurstEffect(
            at: center,
            radius: configuration.freezeBurstRadius,
            duration: configuration.freezeExpansionDuration
        )
    }

    func updateFreezeBurstWaves(deltaTime: TimeInterval) {
        guard !freezeBurstWaveStates.isEmpty else {
            return
        }

        var activeStates: [FreezeBurstWaveState] = []
        var didCompleteWave = false
        for var state in freezeBurstWaveStates {
            let frame = state.update(deltaTime: deltaTime, enemies: enemies)
            freezeEnemies(
                ids: frame.frozenEnemyIDs,
                duration: state.freezeDuration,
                thawGraceDuration: state.thawGraceDuration
            )
            if !frame.isComplete {
                activeStates.append(state)
            } else {
                didCompleteWave = true
            }
        }
        freezeBurstWaveStates = activeStates
        if didCompleteWave {
            grantPostWeaponSafety(for: .freezeBurst)
        }
    }

    func activatePowerWave(
        at position: CGPoint,
        configuration: StartingWeaponConfiguration
    ) {
        powerWaveState.activate(configuration: configuration)
        playPowerWaveChargeEffect(
            at: position,
            direction: aimDirectionState.resolvedDirection(),
            duration: configuration.powerWaveChargeDuration
        )
    }

    func updatePowerWave(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard powerWaveState.isActive else {
            return
        }

        let frame = powerWaveState.update(
            deltaTime: deltaTime,
            playerPosition: playerPosition,
            direction: aimDirectionState.resolvedDirection(),
            playableRect: currentPlayableRect,
            enemies: enemies,
            configuration: weaponResolver.configuration
        )

        if frame.isCharging {
            updatePowerWaveChargeEffect(
                at: playerPosition,
                direction: aimDirectionState.resolvedDirection()
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

        destroyEnemies(ids: frame.destroyedEnemyIDs, weaponKind: .powerWave)
        if frame.isComplete {
            grantPostWeaponSafety(for: .powerWave)
        }
    }

    func activateGravityWell(
        at center: CGPoint,
        enemyIDs: Set<Int>,
        configuration: StartingWeaponConfiguration
    ) {
        let state = GravityWellState(
            center: center,
            enemyIDs: enemyIDs,
            timeRemaining: configuration.gravityWellPullDuration,
            activationDelayRemaining: configuration.gravityWellActivationDelay,
            pullRadius: configuration.gravityWellRadius,
            pullDuration: configuration.gravityWellPullDuration,
            clearRadius: configuration.gravityWellClearRadius
        )
        gravityWellState = state
        playGravityWellEffect(
            at: center,
            radius: configuration.gravityWellRadius,
            duration: state.totalTimeRemaining
        )
        destroyGravityWellCenterEnemies(state)
    }

    func updateGravityWell(deltaTime: TimeInterval) {
        guard var state = gravityWellState else {
            return
        }

        destroyGravityWellCenterEnemies(state)
        let pullDelta = state.consumePullDelta(deltaTime: deltaTime)
        let pullDuration = max(state.pullDuration, 0.001)
        let pullDistance = state.pullRadius / CGFloat(pullDuration) * CGFloat(pullDelta)

        if pullDistance > 0 {
            for index in enemies.indices where state.enemyIDs.contains(enemies[index].id) {
                enemies[index].pullToward(state.center, distance: pullDistance)
                enemyNodes[enemies[index].id]?.apply(enemies[index])
            }
            destroyGravityWellCenterEnemies(state)
        }

        if state.isComplete {
            completeGravityWell(state)
        } else {
            gravityWellState = state
        }
    }

    func destroyGravityWellCenterEnemies(_ state: GravityWellState) {
        destroyEnemies(
            ids: state.collapseTargets(enemies: enemies),
            weaponKind: .gravityWell
        )
    }

    func completeGravityWell(_ state: GravityWellState) {
        gravityWellState = nil
        gravityWellEffectNode?.removeFromParent()
        gravityWellEffectNode = nil

        let destroyedIDs = state.collapseTargets(enemies: enemies)
        let targets = impactTargets(forEnemyIDs: destroyedIDs)
        playGravityWellCollapseEffect(
            at: state.center,
            clearRadius: state.clearRadius,
            targets: targets
        ) { [weak self] enemyIDs in
            self?.destroyEnemies(ids: enemyIDs, weaponKind: .gravityWell)
        }
        grantPostWeaponSafety(for: .gravityWell)
    }

    func deactivateGravityWell() {
        gravityWellState = nil
        gravityWellEffectNode?.removeFromParent()
        gravityWellEffectNode = nil
    }

    func freezeEnemies(ids enemyIDs: Set<Int>, duration: TimeInterval, thawGraceDuration: TimeInterval) {
        guard !enemyIDs.isEmpty, duration > 0 else {
            return
        }
        for index in enemies.indices where enemyIDs.contains(enemies[index].id) {
            enemies[index].freeze(duration: duration, thawGraceDuration: thawGraceDuration)
            enemyNodes[enemies[index].id]?.apply(enemies[index])
            playFreezeAppliedEffect(at: enemies[index].position, radius: enemies[index].radius)
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
                    canShatterOnContact($0) && playerCircle.intersects($0.collisionCircle)
                }
                .map(\.id)
        )

        guard !shatterIDs.isEmpty else {
            return
        }
        let shatteredEnemies = enemies.filter { shatterIDs.contains($0.id) }
        let splitChildren = splitterChildren(from: shatteredEnemies)
        let shatterPositions = shatteredEnemies.map(\.position)
        playFrozenShatterEffect(at: shatterPositions, color: theme.playerColor)
        let previousComboMultiplier = runController.comboMultiplier
        let weaponComboEvent = runController.recordEnemyKills(count: shatterIDs.count, weaponKind: .freezeBurst)
        playEnemyClearHaptics(killCount: shatterIDs.count, previousComboMultiplier: previousComboMultiplier)
        playEnemyClearAudio(killCount: shatterIDs.count, previousComboMultiplier: previousComboMultiplier)
        if let weaponComboEvent {
            recordWeaponComboFeedback(
                weaponComboEvent,
                previousComboMultiplier: previousComboMultiplier,
                clearPositions: shatterPositions
            )
        }
        if shatterIDs.count >= gameTuning.feedback.multiKillShakeThreshold {
            playScreenShake(
                amplitude: gameTuning.feedback.multiKillShakeAmplitude,
                duration: gameTuning.feedback.multiKillShakeDuration
            )
        }
        removeEnemies(ids: shatterIDs)
        addSplitterChildren(splitChildren)
    }

    private func recordWeaponComboFeedback(
        _ event: WeaponComboEvent,
        previousComboMultiplier: Int,
        clearPositions: [CGPoint]
    ) {
        AppDiagnostics.logger(.weapon).notice("weapon.combo.resolved", metadata: [
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

    func canShatterOnContact(_ enemy: ArenaEnemy) -> Bool {
        enemy.isThawing
    }
}

private struct ArenaControlHitTarget {
    let action: ArenaControlAction
    let frame: CGRect
}

private struct DeveloperTuningMenu {
    let groups: [String]
    let selectedGroup: String?
    let subgroups: [String]
    let selectedSubgroup: String?
    let parameters: [GameTuningParameterSpec]
}

private struct DeveloperTuningFrames {
    let group: CGRect
    let subgroup: CGRect
    let parameters: CGRect
}

private enum ArenaControlAction: Equatable {
    case play
    case playAgain
    case openModes
    case openAwards
    case openWeaponCodex
    case openOptions
    case openDeveloperTuning
    case openCalibrationPreview
    case home
    case back
    case selectMode(ArenaModeKind)
    case resume
    case calibrate
    case endRun
    case sensitivityDown
    case sensitivityUp
    case preset(TiltCalibrationPreset)
    case toggleAudio
    case toggleHaptics
    case selectTheme(ArenaThemeKind)
    case resetData
    case exportDiagnostics
    case openClassicLeaderboard
    case developerTuningPreviousPage
    case developerTuningNextPage
    case selectTuningGroup(String)
    case selectTuningSubgroup(String)
    case toggleDeveloperTuningChangedOnly
    case adjustTuningParameter(String, GameTuningAdjustmentDirection)
    case copyTuningParameters
    case resetTuningParameters
}

private enum ArenaButtonStyle {
    case primary
    case secondary
    case danger
}

private enum ArenaUIZPosition {
    static let scrim: CGFloat = 0
    static let preview: CGFloat = 4
    static let content: CGFloat = 8
    static let progress: CGFloat = 12
    static let panel: CGFloat = 16
    static let control: CGFloat = 24
    static let controlFill: CGFloat = 25
    static let label: CGFloat = 32
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
