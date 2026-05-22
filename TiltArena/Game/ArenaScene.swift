// swiftlint:disable file_length
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

// swiftlint:disable:next type_body_length
final class ArenaScene: SKScene {
    weak var orientationDelegate: ArenaSceneOrientationDelegate?
    weak var diagnosticsDelegate: ArenaSceneDiagnosticsDelegate?
    var theme: ArenaTheme {
        localOptions.themeKind.theme
    }
    private let tiltSettingsStore = TiltSettingsStore()
    private let runProfileStore = RunProfileStore()
    private let localOptionsStore = ArenaLocalOptionsStore()
    private let hapticsController = ArenaHapticsController()
    private var arenaRoot = SKNode()
    private let uiRoot = SKNode()
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    var movementController = PlayerMovementController()
    private var runController = ClassicRunController()
    private var runProfile = RunProfile()
    private var localOptions = ArenaLocalOptions()
    private var uiState: ArenaUISceneState = .home
    private var optionsReturnState: ArenaUISceneState = .home
    private var calibrationReturnState: ArenaUISceneState = .home
    private var selectedMode: ArenaModeKind = .classic
    private var previousBestScore = 0
    private var lastProgressionResult: ArenaProgressionResult?
    private var resetDataArmed = false
    private var hasPersistedFinalRun = false
    private var readyHoldController = ReadyStartHoldController()
    private var readyStartPoint = CGPoint.zero
    private var readyProgressRing: SKShapeNode?
    private var readyStatusLabel: SKLabelNode?
    private var spawnDirector = EnemySpawnDirector()
    private var pickupSpawnConfiguration = PickupSpawnConfiguration()
    private var pickupPlanner = PickupSpawnPlanner()
    let weaponResolver = StartingWeaponResolver()
    private var enemies: [ArenaEnemy] = []
    private var enemyNodes: [Int: EnemyNode] = [:]
    private var enemyTelegraphNodes: [Int: EnemyTelegraphNode] = [:]
    private var formationEnemyIDs: [Int: Set<Int>] = [:]
    private var pickups: [WeaponPickup] = []
    private var pickupNodes: [Int: WeaponPickupNode] = [:]
    private var playerNode: PlayerCraftNode?
    private var playerTrailNode: PlayerTrailNode?
    private var razorShieldTimeRemaining: TimeInterval = 0
    private var razorShieldNode: SKShapeNode?
    private var frozenCrasherTimeRemaining: TimeInterval = 0
    private var flameTrailState = FlameTrailState()
    private lazy var flameTrailEffectNode = FlameTrailEffectNode(theme: theme)
    private var gravityWellState: GravityWellState?
    var gravityWellEffectNode: SKNode?
    private var warpDashState = WarpDashState()
    private var warpDashInvulnerabilityTimeRemaining: TimeInterval = 0
    private var decoyBeaconState = DecoyBeaconState()
    var decoyBeaconEffectNode: SKNode?
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let bestMarkerLabel = SKLabelNode(fontNamed: "Menlo")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let pauseControlNode = SKNode()
    private let pauseIconNode = SKNode()
#if DEBUG
    private let debugStatsLabel = SKLabelNode(fontNamed: "Menlo")
    private var debugStatsElapsed: TimeInterval = 0
    private var debugStatsLogElapsed: TimeInterval = 0
    private var debugStatsFrameCount = 0
#endif
    private let hudMargin: CGFloat = 24
    private let pauseControlSize = CGSize(width: 48, height: 48)
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
        super.init(size: size)
        anchorPoint = .zero
        backgroundColor = theme.backgroundColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ArenaScene does not support storyboard initialization.")
    }

    override func didMove(to view: SKView) {
        runProfile = runProfileStore.profile
        localOptions = localOptionsStore.options
        syncHapticsOption()
        backgroundColor = theme.backgroundColor
        rebuildArena()
        if flameTrailEffectNode.parent == nil { addChild(flameTrailEffectNode) }
        configureLabels()
        configurePauseControl()
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
        layoutPauseControl()
        layoutDebugStats()
        rebuildUI()
        AppDiagnostics.logger(.scene).info("scene.resized", metadata: [
            "width": "\(Int(size.width.rounded()))",
            "height": "\(Int(size.height.rounded()))"
        ])
    }

    override func willMove(from view: SKView) {
        orientationDelegate?.arenaSceneRequestsOrientationUnlock(self)
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
        case .home, .modeSelect, .awards, .pause, .postRun:
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
        layoutPauseControl()
        layoutDebugStats()
        rebuildUI()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else {
            return
        }

        if uiState == .activeGameplay, touches.contains(where: isPauseControlTouch) {
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
        playerNode?.apply(state: state)

        let speedFraction = state.velocity.length / max(
            1,
            movementController.configuration.maximumSpeed(in: currentGameplayBounds)
        )

        if resetTrail {
            playerTrailNode?.reset(to: state.position)
        } else {
            playerTrailNode?.record(position: state.position, speedFraction: speedFraction)
        }
    }

    private func configureLabels() {
        configureLabel(timerLabel, fontSize: 16, color: theme.borderColor)
        timerLabel.horizontalAlignmentMode = .left
        timerLabel.verticalAlignmentMode = .top

        configureLabel(bestMarkerLabel, fontSize: 12, color: theme.borderColor)
        bestMarkerLabel.horizontalAlignmentMode = .right
        bestMarkerLabel.verticalAlignmentMode = .center

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

    private func configurePauseControl() {
        guard pauseControlNode.parent == nil else {
            return
        }

        pauseControlNode.zPosition = 60
        rebuildPauseControlAppearance()
        addChild(pauseControlNode)
        layoutPauseControl()
        updatePauseControl()
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.zPosition = 50
    }

    private func layoutLabels() {
        let layout = currentHUDLayout()

        timerLabel.position = layout.timerPosition
        bestMarkerLabel.position = CGPoint(
            x: layout.pauseControlPosition.x - pauseControlSize.width,
            y: layout.pauseControlPosition.y
        )
        comboLabel.position = layout.comboPosition
    }

    private func layoutPauseControl() {
        pauseControlNode.position = currentHUDLayout().pauseControlPosition
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
            margin: hudMargin,
            pauseControlSize: pauseControlSize
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
        currentLandscapeLayout().safeRect
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
        let input = tiltInputController.update(deltaTime: deltaTime, orientation: currentTiltScreenOrientation)
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

        let input = tiltInputController.update(deltaTime: deltaTime, orientation: currentTiltScreenOrientation)
        warpDashState.record(input: input)
        let state = movementController.update(input: input, deltaTime: deltaTime, arenaBounds: currentGameplayBounds)
        applyPlayerState(state, resetTrail: false)
        updateActiveRun(deltaTime: deltaTime, playerPosition: state.position)
    }

    private func updateCalibrationPreview(deltaTime: TimeInterval) {
        let input = tiltInputController.update(deltaTime: deltaTime, orientation: currentTiltScreenOrientation)
        let state = calibrationPreviewMovementController.update(
            input: input,
            deltaTime: deltaTime,
            arenaBounds: currentGameplayBounds
        )

        applyCalibrationPreviewState(state, resetTrail: false)
        updateTiltReadoutDisplay(deltaTime: deltaTime)
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
        _ = calibrationPreviewMovementController.reset(in: currentGameplayBounds)
    }

    private func applyCalibrationPreviewState(_ state: PlayerMovementState, resetTrail: Bool) {
        calibrationPreviewPlayerNode?.apply(state: state)

        let speedFraction = state.velocity.length / max(
            1,
            calibrationPreviewMovementController.configuration.maximumSpeed(in: currentGameplayBounds)
        )

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
        hapticsController.prepare()
        show(.activeGameplay)
        AppDiagnostics.logger(.run).notice("run.started", metadata: [
            "mode": "\(selectedMode.rawValue)"
        ])
    }

    private func pauseRun() {
        runController.pause()
        tiltInputController.resetSmoothedInput()
        show(.pause)
        AppDiagnostics.logger(.run).info("run.paused", metadata: [
            "score": "\(runController.score)",
            "survivalTime": "\(runController.survivalTime)"
        ])
    }

    private func resumeRun() {
        tiltInputController.resetSmoothedInput()
        runController.resume()
        show(.activeGameplay)
        AppDiagnostics.logger(.run).info("run.resumed", metadata: [
            "score": "\(runController.score)",
            "survivalTime": "\(runController.survivalTime)"
        ])
    }

    private func finishRun(playFeedback: Bool = true) {
        previousBestScore = runProfile.bestScore
        runController.endRun(mode: selectedMode)
        let isNewBest = (runController.finalizedSummary?.score ?? runController.score) > previousBestScore
        persistFinalRunIfNeeded()
        if playFeedback {
            playDeathFeedback()
            playHaptic(.death)
        }
        if isNewBest {
            playHaptic(.newBest)
        }
        show(.postRun)
        logFinishedRun(isNewBest: isNewBest)
    }

    private func resetActiveRun() {
        hasPersistedFinalRun = false
        lastProgressionResult = nil
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
        deactivateRazorShield()
        frozenCrasherTimeRemaining = 0
        flameTrailState.reset()
        flameTrailEffectNode.reset()
        deactivateGravityWell()
        warpDashState.reset()
        warpDashInvulnerabilityTimeRemaining = 0
        decoyBeaconState.reset()
        deactivateDecoyBeaconEffect()
    }

    private func applySelectedModeRunSettings() -> ArenaModeRunSettings {
        let settings = ArenaModeRules.runSettings(for: selectedMode, profile: runProfile)
        spawnDirector.configuration = settings.enemySpawnConfiguration
        pickupSpawnConfiguration = settings.pickupSpawnConfiguration
        return settings
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
        rebuildPauseControlAppearance()
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
            playGravityWellEffect(at: gravityWellState.center, duration: gravityWellState.timeRemaining)
        }

        if decoyBeaconState.isActive, let center = decoyBeaconState.center {
            playDecoyBeaconEffect(at: center, duration: decoyBeaconState.timeRemaining)
        }
    }

    private func updateActiveRun(deltaTime: TimeInterval, playerPosition initialPlayerPosition: CGPoint) {
        var playerPosition = initialPlayerPosition

        runController.update(deltaTime: deltaTime)
        updateWarpDashInvulnerability(deltaTime: deltaTime)
        spawnEnemiesIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        spawnPickupIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        playerPosition = collectPickups(playerPosition: playerPosition)
        advanceEnemies(deltaTime: deltaTime, playerPosition: playerPosition)
        updateDecoyBeacon(deltaTime: deltaTime)
        updateGravityWell(deltaTime: deltaTime)
        removeExpiredEnemies()
        cullExitedLinearPatternEnemies()
        updateRazorShield(deltaTime: deltaTime, playerPosition: playerPosition)
        shatterFrozenContactEnemies(playerPosition: playerPosition)
        updateFrozenCrasher(deltaTime: deltaTime)
        updateFlameTrail(deltaTime: deltaTime, playerPosition: playerPosition)
        recordNearMisses(playerPosition: playerPosition)
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

        guard let pickup = pickupPlanner.update(
            deltaTime: deltaTime,
            phase: runController.phase,
            activePickupCount: pickups.count,
            playableRect: currentPlayableRect,
            playerPosition: playerPosition,
            enemyCircles: enemyCircles,
            configuration: pickupSpawnConfiguration
        ) else {
            return
        }

        pickups.append(pickup)
        AppDiagnostics.logger(.weapon).info("pickup.spawned", metadata: [
            "id": "\(pickup.id)",
            "kind": "\(pickup.kind.rawValue)"
        ])

        let node = WeaponPickupNode(pickup: pickup, theme: theme)
        pickupNodes[pickup.id] = node
        addChild(node)
    }

    private func advanceEnemies(deltaTime: TimeInterval, playerPosition: CGPoint) {
        for index in enemies.indices {
            let targetPosition = decoyBeaconState.targetPosition(
                for: enemies[index],
                fallback: playerPosition
            )
            enemies[index].advance(toward: targetPosition, deltaTime: deltaTime)
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
        removeFormationEnemies(ids: expiredEnemyIDs, awardCompletion: false)

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
            let creditedDangerGrab: Bool
            if isDangerGrab(pickup) {
                creditedDangerGrab = runController.recordDangerGrab(pickupID: pickup.id)
            } else {
                creditedDangerGrab = false
            }
            playHaptic(creditedDangerGrab ? .dangerPickup : .pickup)
            AppDiagnostics.logger(.weapon).notice("pickup.collected", metadata: [
                "id": "\(pickup.id)",
                "kind": "\(pickup.kind.rawValue)",
                "dangerGrab": "\(creditedDangerGrab)"
            ])

            removePickup(id: pickup.id)
            applyWeapon(pickup.kind, playerPosition: currentPlayerPosition)
            currentPlayerPosition = movementController.state.position
        }

        return currentPlayerPosition
    }

    private func removePickup(id: Int) {
        pickups.removeAll { $0.id == id }
        pickupNodes.removeValue(forKey: id)?.removeFromParent()
    }

    private func applyWeapon(_ kind: WeaponKind, playerPosition: CGPoint) {
        let resolution = weaponResolver.resolve(
            kind: kind,
            playerPosition: playerPosition,
            enemies: enemies
        )

        switch kind {
        case .shockwave:
            playShockwaveEffect(at: playerPosition)
        case .seekerSwarm:
            let targetPositions = positions(forEnemyIDs: resolution.destroyedEnemyIDs)
            playSeekerSwarmEffect(from: playerPosition, to: targetPositions)
        case .razorShield:
            activateRazorShield(at: playerPosition)
        case .freezeBurst:
            freezeEnemies(ids: resolution.frozenEnemyIDs, duration: weaponResolver.configuration.freezeDuration)
            frozenCrasherTimeRemaining = max(
                frozenCrasherTimeRemaining,
                weaponResolver.configuration.frozenCrasherDuration
            )
            playFreezeBurstEffect(at: playerPosition)
        case .gravityWell:
            activateGravityWell(
                at: playerPosition,
                enemyIDs: resolution.gravityWellEnemyIDs
            )
        case .chainLightning:
            let targetPositions = positions(forEnemyIDs: resolution.chainLightningEnemyIDs)
            playChainLightningEffect(
                from: playerPosition,
                through: targetPositions,
                accentColor: theme.playerAccentColor,
                coreColor: theme.playerColor
            )
        case .flameTrail:
            flameTrailState.activate(at: playerPosition)
            flameTrailEffectNode.apply(segments: flameTrailState.segments)
        case .warpDash:
            performWarpDash(from: playerPosition)
        case .decoyBeacon:
            activateDecoyBeacon(at: playerPosition)
        case .novaBomb:
            playNovaBombEffect()
        }

        destroyEnemies(ids: resolution.destroyedEnemyIDs, weaponKind: kind)
        AppDiagnostics.logger(.weapon).notice("weapon.resolved", metadata: [
            "kind": "\(kind.rawValue)",
            "destroyed": "\(resolution.destroyedEnemyIDs.count)",
            "frozen": "\(resolution.frozenEnemyIDs.count)",
            "gravityTargets": "\(resolution.gravityWellEnemyIDs.count)"
        ])
    }

    private func positions(forEnemyIDs enemyIDs: Set<Int>) -> [CGPoint] {
        enemies.compactMap { enemyIDs.contains($0.id) ? $0.position : nil }
    }

    private func positions(forEnemyIDs enemyIDs: [Int]) -> [CGPoint] {
        let positionsByID = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0.position) })
        return enemyIDs.compactMap { positionsByID[$0] }
    }

    private func destroyEnemies(ids enemyIDs: Set<Int>, weaponKind: WeaponKind?) {
        guard !enemyIDs.isEmpty else {
            return
        }

        let previousComboMultiplier = runController.comboMultiplier
        runController.recordEnemyKills(count: enemyIDs.count, weaponKind: weaponKind)
        playEnemyClearHaptics(killCount: enemyIDs.count, previousComboMultiplier: previousComboMultiplier)
        removeEnemies(ids: enemyIDs)
    }

    private func removeEnemies(ids enemyIDs: Set<Int>) {
        enemies.removeAll { enemyIDs.contains($0.id) }
        removeFormationEnemies(ids: enemyIDs, awardCompletion: true)

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

    private func removeFormationEnemies(ids enemyIDs: Set<Int>, awardCompletion: Bool) {
        for formationID in formationEnemyIDs.keys.sorted() {
            guard var remainingEnemyIDs = formationEnemyIDs[formationID] else {
                continue
            }

            remainingEnemyIDs.subtract(enemyIDs)

            if remainingEnemyIDs.isEmpty {
                formationEnemyIDs.removeValue(forKey: formationID)

                if awardCompletion {
                    runController.recordFormationBonus()
                }
            } else {
                formationEnemyIDs[formationID] = remainingEnemyIDs
            }
        }
    }

    private func activateRazorShield(at playerPosition: CGPoint) {
        razorShieldTimeRemaining = weaponResolver.configuration.razorShieldDuration

        if razorShieldNode == nil {
            let node = SKShapeNode(circleOfRadius: weaponResolver.configuration.razorShieldRadius)
            node.zPosition = 19
            styleRazorShieldNode(node)
            addChild(node)
            razorShieldNode = node
        }

        razorShieldNode?.position = playerPosition
        razorShieldNode?.isHidden = false
    }

    private func styleRazorShieldNode(_ node: SKShapeNode) {
        node.strokeColor = theme.pickupBlue.withAlphaComponent(0.9)
        node.fillColor = .clear
        node.lineWidth = 2
        node.glowWidth = 4
    }

    private func updateRazorShield(deltaTime: TimeInterval, playerPosition: CGPoint) {
        guard razorShieldTimeRemaining > 0 else {
            deactivateRazorShield()
            return
        }

        razorShieldNode?.position = playerPosition

        let targetIDs = weaponResolver.shieldTargets(
            playerPosition: playerPosition,
            enemies: enemies
        )
        destroyEnemies(ids: targetIDs, weaponKind: .razorShield)

        razorShieldTimeRemaining = max(0, razorShieldTimeRemaining - max(0, deltaTime))

        if razorShieldTimeRemaining == 0 {
            deactivateRazorShield(emitHaptic: true)
        }
    }

    private func deactivateRazorShield(emitHaptic: Bool = false) {
        let hadActiveShield = razorShieldNode != nil || razorShieldTimeRemaining > 0
        razorShieldTimeRemaining = 0
        razorShieldNode?.removeFromParent()
        razorShieldNode = nil

        if emitHaptic, hadActiveShield, runController.phase == .active {
            playHaptic(.shieldExpired)
        }
    }

    private func updateFlameTrail(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let frame = flameTrailState.update(deltaTime: deltaTime, playerPosition: playerPosition, enemies: enemies)
        destroyEnemies(ids: frame.burnedEnemyIDs, weaponKind: .flameTrail)
        flameTrailEffectNode.apply(segments: frame.segments)
    }

    private func performWarpDash(from startPosition: CGPoint) {
        let state = movementController.dash(
            direction: warpDashState.resolvedDirection(),
            distance: warpDashDistance(),
            arenaBounds: currentGameplayBounds
        )

        applyPlayerState(state, resetTrail: false)
        warpDashInvulnerabilityTimeRemaining = max(
            warpDashInvulnerabilityTimeRemaining,
            weaponResolver.configuration.warpDashInvulnerabilityDuration
        )
        playWarpDashEffect(from: startPosition, to: state.position)
    }

    private func warpDashDistance() -> CGFloat {
        min(currentPlayableRect.width, currentPlayableRect.height)
            * max(0, weaponResolver.configuration.warpDashDistanceFractionOfShortSide)
    }

    private func updateWarpDashInvulnerability(deltaTime: TimeInterval) {
        guard warpDashInvulnerabilityTimeRemaining > 0 else {
            return
        }

        warpDashInvulnerabilityTimeRemaining = max(
            0,
            warpDashInvulnerabilityTimeRemaining - max(0, deltaTime)
        )
    }

    private func detectPlayerCollision(playerPosition: CGPoint) {
        guard warpDashInvulnerabilityTimeRemaining == 0 else {
            return
        }

        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )

        guard enemies.contains(where: { playerCircle.intersects($0.collisionCircle) }) else {
            return
        }

        finishRun()
    }

    private func playDeathFeedback() {
        let pulse = SKAction.group([
            .scale(to: 1.45, duration: 0.08),
            .fadeAlpha(to: 0.35, duration: 0.08)
        ])
        let settle = SKAction.scale(to: 1.0, duration: 0.08)

        playerNode?.run(.sequence([pulse, settle]))
    }

    private func syncHapticsOption() {
        hapticsController.isEnabled = localOptions.hapticsEnabled
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

    private func updateRunDisplay() {
        timerLabel.alpha = uiState == .pause || uiState == .postRun ? 0.55 : 1

        switch uiState {
        case .home, .modeSelect, .awards, .options, .calibrationPreview:
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

        updatePauseControl()
    }

    private func formatSurvivalTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }

    private func formatCombo() -> String {
        guard runController.currentCombo > 0 else {
            return ""
        }

        return String(
            format: "COMBO %d  x%d  %.1fs",
            runController.currentCombo,
            runController.comboMultiplier,
            runController.comboTimeRemaining
        )
    }

    private func isPauseControlTouch(_ touch: UITouch) -> Bool {
        pauseControlFrame.contains(touch.location(in: self))
    }

    private var pauseControlFrame: CGRect {
        CGRect(
            x: pauseControlNode.position.x - pauseControlSize.width / 2,
            y: pauseControlNode.position.y - pauseControlSize.height / 2,
            width: pauseControlSize.width,
            height: pauseControlSize.height
        )
    }

    private func updatePauseControl() {
        pauseControlNode.isHidden = uiState != .activeGameplay || runController.phase != .active
    }

    private func recordNearMisses(playerPosition: CGPoint) {
        let hitCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )
        let nearMissCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius + runController.configuration.nearMissEdgeGap
        )

        var didRecordNearMiss = false

        for enemy in enemies where nearMissCircle.intersects(enemy.collisionCircle) {
            guard !hitCircle.intersects(enemy.collisionCircle) else {
                continue
            }

            didRecordNearMiss = runController.recordNearMiss(enemyID: enemy.id) || didRecordNearMiss
        }

        if didRecordNearMiss {
            playHaptic(.nearMiss)
        }
    }

    private func isDangerGrab(_ pickup: WeaponPickup) -> Bool {
        enemies.contains { enemy in
            let dangerDistance = runController.configuration.dangerGrabEnemyDistance
                + pickup.radius
                + enemy.radius
            return ArenaGeometry.squaredDistance(from: pickup.position, to: enemy.position) <= dangerDistance * dangerDistance
        }
    }

    private func persistFinalRunIfNeeded() {
        guard !hasPersistedFinalRun, let summary = runController.finalizedSummary else {
            return
        }

        let result = runProfileStore.record(summary)
        runProfile = result.profile
        lastProgressionResult = result
        hasPersistedFinalRun = true
    }

    private func addPauseControlBackground() {
        let background = SKShapeNode(rectOf: pauseControlSize, cornerRadius: 8)
        background.fillColor = theme.borderColor.withAlphaComponent(0.12)
        background.strokeColor = theme.borderColor.withAlphaComponent(0.55)
        background.lineWidth = 1
        pauseControlNode.addChild(background)
    }

    private func configurePauseIcon() {
        pauseIconNode.removeAllChildren()
        for xOffset in [CGFloat(-5.5), CGFloat(5.5)] {
            let bar = SKShapeNode(rectOf: CGSize(width: 5, height: 18), cornerRadius: 1.5)
            bar.position = CGPoint(x: xOffset, y: 0)
            bar.fillColor = theme.playerColor
            bar.strokeColor = theme.playerColor
            pauseIconNode.addChild(bar)
        }

        pauseControlNode.addChild(pauseIconNode)
    }

    private func rebuildPauseControlAppearance() {
        pauseControlNode.removeAllChildren()
        addPauseControlBackground()
        configurePauseIcon()
    }
}

private extension ArenaScene {
    func show(_ state: ArenaUISceneState) {
        if state != .options {
            resetDataArmed = false
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

    var shouldLockCurrentOrientation: Bool {
        switch uiState {
        case .calibrationPreview, .preRun, .activeGameplay, .pause, .postRun:
            return true
        case .options:
            return optionsReturnState.requiresLockedRunOrientation
        case .home, .modeSelect, .awards:
            return false
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

        switch uiState {
        case .home:
            renderHome()
        case .modeSelect:
            renderModeSelect()
        case .awards:
            renderAwards()
        case .options:
            renderOptions()
        case .calibrationPreview:
            renderCalibrationPreview()
        case .preRun:
            renderPreRun()
        case .activeGameplay:
            break
        case .pause:
            renderPause()
        case .postRun:
            renderPostRun()
        }

        updateRunDisplay()
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
        let rows = TiltReadoutFormatter.rows(
            for: tiltInputController.readout(orientation: orientation),
            fallbackOrientation: orientation
        )

        for (label, row) in zip(tiltReadoutValueLabels, rows) {
            label.text = row.value
        }
    }

    func renderHome() {
        let layout = currentLandscapeLayout()
        let bottomButtonSize = CGSize(width: 108, height: 38)
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
        addPreviewThreats(in: layout.safeRect)
        addButton(
            "PLAY",
            frame: layout.stackedLowerRightButtonFrame(aboveBottomControlHeight: bottomButtonSize.height),
            action: .play,
            style: .primary
        )

        addButton(
            "MODES",
            frame: layout.bottomButtonFrame(index: 0, count: 3, buttonSize: bottomButtonSize),
            action: .openModes,
            style: .secondary
        )
        addButton(
            "AWARDS",
            frame: layout.bottomButtonFrame(index: 1, count: 3, buttonSize: bottomButtonSize),
            action: .openAwards,
            style: .secondary
        )
        addButton(
            "OPTIONS",
            frame: layout.bottomButtonFrame(index: 2, count: 3, buttonSize: bottomButtonSize),
            action: .openOptions,
            style: .secondary
        )
    }

    func renderModeSelect() {
        let layout = currentLandscapeLayout()
        addBackButton(layout: layout)
        addTitle("MODES", at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 48))

        let rows = ArenaMenuContent.modeRows(profile: runProfile, selectedMode: selectedMode)
        let rowWidth = layout.safeRect.width * 0.62
        let rowHeight: CGFloat = 58
        let rowStartY = layout.safeRect.maxY - 118

        for (index, row) in rows.enumerated() {
            let frame = CGRect(
                x: layout.safeRect.minX,
                y: rowStartY - CGFloat(index) * (rowHeight + 14),
                width: rowWidth,
                height: rowHeight
            )
            addModeRow(row, frame: frame)
        }

        addButton(
            "PLAY",
            frame: layout.lowerRightButtonFrame,
            action: .play,
            style: .primary
        )
        addSmallLabel(
            "LOCAL ONLY",
            at: CGPoint(x: layout.safeRect.maxX, y: layout.lowerRightButtonFrame.maxY + 20),
            color: theme.borderColor,
            alignment: .right
        )
    }

    func renderAwards() {
        let layout = currentLandscapeLayout()
        addBackButton(layout: layout)
        addTitle("AWARDS", at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 48))

        let rows = ArenaMenuContent.awardRows(profile: runProfile)
        let columnWidth = layout.safeRect.width * 0.34
        let rowHeight: CGFloat = 48
        let leftX = layout.safeRect.minX
        let rightX = leftX + columnWidth + 18
        let startY = layout.safeRect.maxY - 118

        for (index, row) in rows.enumerated() {
            let column = index / 3
            let rowIndex = index % 3
            let x = column == 0 ? leftX : rightX
            let frame = CGRect(
                x: x,
                y: startY - CGFloat(rowIndex) * (rowHeight + 14),
                width: columnWidth,
                height: rowHeight
            )
            addAwardRow(row, frame: frame)
        }

        let highlightFrame = layout.rightColumnFrame(width: 190)
        addPanel(frame: highlightFrame, stroke: theme.playerAccentColor.withAlphaComponent(0.42))
        addSmallLabel(
            "ACTIVE UNLOCK",
            at: CGPoint(x: highlightFrame.minX + 14, y: highlightFrame.maxY - 24),
            color: theme.borderColor,
            alignment: .left
        )
        addLabel(
            ArenaMenuContent.activeUnlockText(profile: runProfile),
            at: CGPoint(x: highlightFrame.minX + 14, y: highlightFrame.maxY - 54),
            fontSize: 15,
            color: theme.playerAccentColor,
            alignment: .left
        )
        addSmallLabel(
            "LOCAL PROGRESS ONLY",
            at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.minY + 16),
            color: theme.borderColor,
            alignment: .left
        )
    }

    func renderOptions() {
        let layout = currentLandscapeLayout()
        addBackButton(layout: layout)
        addTitle("OPTIONS", at: CGPoint(x: layout.safeRect.minX, y: layout.safeRect.maxY - 48))

        let left = layout.leftColumnFrame(width: 270)
        let right = layout.rightColumnFrame(width: 270)
        addPanel(frame: left)
        addPanel(frame: right)

        renderTiltOptions(in: left)
        renderLocalOptions(in: right)
    }

    func renderCalibrationPreview() {
        let layout = currentLandscapeLayout()
        let worldNode = SKNode()
        worldNode.zPosition = ArenaUIZPosition.preview
        uiRoot.addChild(worldNode)

        let previewArena = ArenaThemeRenderer(theme: theme).makeArenaBackground(
            size: size,
            arenaRect: layout.safeRect
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

        let controlsWidth = min(292, max(260, layout.safeRect.width * 0.38))
        let controlsHeight: CGFloat = 238
        let controlsFrame = CGRect(
            x: layout.safeRect.minX,
            y: layout.safeRect.maxY - controlsHeight,
            width: controlsWidth,
            height: controlsHeight
        )

        addPanel(
            frame: controlsFrame,
            fill: theme.panelFillColor.withAlphaComponent(0.9)
        )
        addBackButton(layout: layout)
        addTitle(
            "CALIBRATE",
            at: CGPoint(x: controlsFrame.minX + 56, y: controlsFrame.maxY - 21)
        )
        renderCalibrationControls(in: controlsFrame)
        addSmallLabel(
            calibrationText,
            at: CGPoint(x: layout.safeRect.maxX, y: layout.safeRect.minY + 16),
            color: theme.borderColor,
            alignment: .right
        )
    }

    func renderCalibrationControls(in frame: CGRect) {
        let settings = tiltSettingsStore.settings
        addButton(
            "SET",
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 72, width: 82, height: 34),
            action: .calibrate,
            style: .primary
        )
        addSmallLabel(
            "SENSITIVITY \(String(format: "%.1f", settings.clampedSensitivity))",
            at: CGPoint(x: frame.minX + 112, y: frame.maxY - 55),
            color: theme.borderColor,
            alignment: .left
        )
        addButton(
            "-",
            frame: CGRect(x: frame.minX + 112, y: frame.maxY - 90, width: 44, height: 30),
            action: .sensitivityDown,
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: frame.minX + 168, y: frame.maxY - 90, width: 44, height: 30),
            action: .sensitivityUp,
            style: .secondary
        )

        let presetY = frame.maxY - 128
        for (index, preset) in [TiltCalibrationPreset.standard, .flatTable, .reclined].enumerated() {
            let buttonFrame = CGRect(
                x: frame.minX + 14 + CGFloat(index) * 82,
                y: presetY,
                width: 74,
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
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: 96
        ))
    }

    func renderTiltOptions(in frame: CGRect) {
        addButton(
            "CALIBRATE",
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 54, width: 148, height: 34),
            action: .openCalibrationPreview,
            style: .primary
        )
        let settings = tiltSettingsStore.settings
        addSmallLabel(
            "SENSITIVITY \(String(format: "%.1f", settings.clampedSensitivity))",
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 84),
            color: theme.borderColor,
            alignment: .left
        )
        addButton(
            "-",
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 124, width: 44, height: 30),
            action: .sensitivityDown,
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: frame.minX + 70, y: frame.maxY - 124, width: 44, height: 30),
            action: .sensitivityUp,
            style: .secondary
        )

        let presetY = frame.maxY - 162
        for (index, preset) in [TiltCalibrationPreset.standard, .flatTable, .reclined].enumerated() {
            let buttonFrame = CGRect(
                x: frame.minX + 14 + CGFloat(index) * 82,
                y: presetY,
                width: 74,
                height: 34
            )
            addButton(
                presetTitle(preset),
                frame: buttonFrame,
                action: .preset(preset),
                style: settings.calibration.preset == preset ? .primary : .secondary
            )
        }

        renderTiltReadout(in: frame)
    }

    func renderTiltReadout(in frame: CGRect) {
        tiltReadoutValueLabels.removeAll()
        let rows = TiltReadoutFormatter.rows(
            for: nil,
            fallbackOrientation: currentTiltScreenOrientation
        )
        let startY = frame.minY + 58
        let rowSpacing: CGFloat = 12

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
        addToggle(
            title: "AUDIO",
            isOn: localOptions.audioEnabled,
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 54, width: 132, height: 34),
            action: .toggleAudio
        )
        addToggle(
            title: "HAPTICS",
            isOn: localOptions.hapticsEnabled,
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 96, width: 132, height: 34),
            action: .toggleHaptics
        )
        addToggle(
            title: "EFFECTS",
            isOn: !localOptions.reducedEffects,
            frame: CGRect(x: frame.minX + 14, y: frame.maxY - 138, width: 132, height: 34),
            action: .toggleEffects
        )
        addButton(
            "LOGS",
            frame: CGRect(x: frame.maxX - 104, y: frame.maxY - 138, width: 90, height: 34),
            action: .exportDiagnostics,
            style: .secondary
        )
        addSmallLabel(
            "THEME",
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 70),
            color: theme.borderColor,
            alignment: .left
        )

        for (index, themeKind) in ArenaThemeKind.allCases.enumerated() {
            addButton(
                themeKind.shortTitle,
                frame: CGRect(
                    x: frame.minX + 14 + CGFloat(index) * 70,
                    y: frame.minY + 26,
                    width: 62,
                    height: 30
                ),
                action: .selectTheme(themeKind),
                style: localOptions.themeKind == themeKind ? .primary : .secondary
            )
        }

        addButton(
            resetDataArmed ? "CONFIRM" : "RESET",
            frame: CGRect(x: frame.maxX - 104, y: frame.minY + 26, width: 90, height: 30),
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
        addDeathClarityMarker(at: movementController.state.position)
        renderPostRunHighlights(summary: summary, in: layout.rightColumnFrame(width: 230))
        renderPostRunButtons(layout: layout)
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
    }

    func renderPostRunHighlights(summary: RunSummary?, in frame: CGRect) {
        addPanel(frame: frame)
        let highlights = ArenaMenuContent.postRunHighlights(
            summary: summary,
            profile: runProfile,
            previousBestScore: previousBestScore,
            progressionResult: lastProgressionResult
        )
        for (index, text) in highlights.enumerated() {
            addSmallLabel(
                text,
                at: CGPoint(x: frame.minX + 14, y: frame.maxY - 28 - CGFloat(index) * 26),
                color: index == 0 ? theme.playerAccentColor : theme.borderColor,
                alignment: .left
            )
        }
    }

    func renderPostRunButtons(layout: ArenaLandscapeUILayout) {
        addButton(
            "PLAY AGAIN",
            frame: layout.lowerRightButtonFrame,
            action: .playAgain,
            style: .primary
        )
        let buttonSize = CGSize(width: 112, height: 36)
        addButton(
            "MODES",
            frame: layout.bottomButtonFrame(index: 0, count: 2, buttonSize: buttonSize),
            action: .openModes,
            style: .secondary
        )
        addButton(
            "HOME",
            frame: layout.bottomButtonFrame(index: 1, count: 2, buttonSize: buttonSize),
            action: .home,
            style: .secondary
        )
    }

    func perform(_ action: ArenaControlAction) {
        switch action {
        case .play, .playAgain, .openModes, .openAwards, .openOptions, .openCalibrationPreview, .home, .back:
            performNavigationAction(action)
        case .selectMode, .resume, .calibrate, .endRun:
            performRunControlAction(action)
        case .exportDiagnostics:
            exportDiagnostics()
        case .sensitivityDown, .sensitivityUp, .preset, .toggleAudio, .toggleHaptics, .toggleEffects, .selectTheme,
                .resetData:
            performOptionsAction(action)
        }
    }

    func performNavigationAction(_ action: ArenaControlAction) {
        switch action {
        case .play where selectedModeIsAvailable:
            preparePreRun()
        case .playAgain:
            preparePreRun()
        case .openModes:
            resetMenuPreviewIfNeeded()
            show(.modeSelect)
        case .openAwards:
            show(.awards)
        case .openOptions:
            optionsReturnState = uiState
            show(.options)
        case .openCalibrationPreview:
            enterCalibrationPreview()
        case .home:
            resetMenuPreviewIfNeeded()
            show(.home)
        case .back where uiState == .calibrationPreview:
            tiltInputController.resetSmoothedInput()
            show(calibrationReturnState)
        case .back:
            show(uiState == .options ? optionsReturnState : .home)
        default:
            break
        }
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
        case .toggleAudio, .toggleHaptics, .toggleEffects:
            performLocalOptionToggle(action)
        case .selectTheme, .resetData:
            performLocalDataAction(action)
        default:
            break
        }
    }

    func performLocalOptionToggle(_ action: ArenaControlAction) {
        switch action {
        case .toggleAudio:
            localOptions.audioEnabled.toggle()
            localOptionsStore.options = localOptions
            rebuildUI()
        case .toggleHaptics:
            localOptions.hapticsEnabled.toggle()
            localOptionsStore.options = localOptions
            syncHapticsOption()
            rebuildUI()
        case .toggleEffects:
            localOptions.reducedEffects.toggle()
            localOptionsStore.options = localOptions
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
        "CAL \(tiltSettingsStore.settings.calibration.preset.rawValue.uppercased())"
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
                reducedEffects: localOptions.reducedEffects,
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
        circle.strokeColor = theme.playerAccentColor.withAlphaComponent(0.9)
        circle.fillColor = theme.playerAccentColor.withAlphaComponent(0.06)
        circle.lineWidth = 2
        circle.glowWidth = 5
        uiRoot.addChild(circle)

        let progress = SKShapeNode(circleOfRadius: radius + 8)
        progress.position = point
        progress.zPosition = ArenaUIZPosition.progress
        progress.strokeColor = theme.playerColor.withAlphaComponent(0.85)
        progress.fillColor = .clear
        progress.lineWidth = 2
        progress.glowWidth = 3
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
            CGPoint(x: 142, y: -58),
            CGPoint(x: -92, y: -74)
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

    func addDeathClarityMarker(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = position
        ring.zPosition = ArenaUIZPosition.content
        ring.strokeColor = theme.enemyColor.withAlphaComponent(0.9)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 4
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
    }

    func addModeRow(_ row: ArenaModeRow, frame: CGRect) {
        let selected = row.kind == selectedMode
        addPanel(
            frame: frame,
            stroke: selected ? theme.playerAccentColor.withAlphaComponent(0.85) : theme.borderColor.withAlphaComponent(0.35),
            fill: selected ? theme.playerAccentColor.withAlphaComponent(0.09) : theme.backgroundColor.withAlphaComponent(0.55)
        )
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 22),
            fontSize: 17,
            color: row.isAvailable ? theme.playerColor : theme.borderColor.withAlphaComponent(0.75),
            alignment: .left
        )
        addSmallLabel(
            row.subtitle,
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 17),
            color: theme.borderColor,
            alignment: .left
        )
        addSmallLabel(
            row.statusText,
            at: CGPoint(x: frame.maxX - 14, y: frame.maxY - 22),
            color: row.isAvailable ? theme.playerAccentColor : theme.borderColor,
            alignment: .right
        )
        addSmallLabel(
            row.progressText,
            at: CGPoint(x: frame.maxX - 14, y: frame.minY + 17),
            color: theme.borderColor,
            alignment: .right
        )
        uiHitTargets.append(ArenaControlHitTarget(action: .selectMode(row.kind), frame: frame))
    }

    func addAwardRow(_ row: ArenaAwardRow, frame: CGRect) {
        addPanel(frame: frame, stroke: row.isComplete ? theme.playerAccentColor : theme.borderColor.withAlphaComponent(0.35))
        addSmallLabel(
            row.title,
            at: CGPoint(x: frame.minX + 12, y: frame.maxY - 17),
            color: row.isComplete ? theme.playerAccentColor : theme.playerColor,
            alignment: .left
        )
        addSmallLabel(
            row.progressText,
            at: CGPoint(x: frame.maxX - 12, y: frame.maxY - 17),
            color: theme.borderColor,
            alignment: .right
        )
        addProgressBar(
            frame: CGRect(x: frame.minX + 12, y: frame.minY + 9, width: frame.width - 24, height: 5),
            fraction: row.progressFraction
        )
    }

    func addToggle(title: String, isOn: Bool, frame: CGRect, action: ArenaControlAction) {
        addButton(
            "\(title) \(isOn ? "ON" : "OFF")",
            frame: frame,
            action: action,
            style: isOn ? .primary : .secondary
        )
    }

    func addBackButton(layout: ArenaLandscapeUILayout) {
        addButton(
            "<",
            frame: CGRect(x: layout.safeRect.minX, y: layout.safeRect.maxY - 38, width: 42, height: 34),
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
            fill = theme.playerAccentColor.withAlphaComponent(0.16)
            stroke = theme.playerAccentColor.withAlphaComponent(0.95)
            text = theme.playerColor
        case .secondary:
            fill = theme.borderColor.withAlphaComponent(0.09)
            stroke = theme.borderColor.withAlphaComponent(0.55)
            text = theme.borderColor
        case .danger:
            fill = theme.enemyColor.withAlphaComponent(0.08)
            stroke = theme.enemyColor.withAlphaComponent(0.55)
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
            return "FLAT"
        case .reclined:
            return "RECL"
        case .custom:
            return "CUSTOM"
        }
    }
}

private extension ArenaScene {
    func activateDecoyBeacon(at position: CGPoint) {
        decoyBeaconState.activate(at: position)
        guard decoyBeaconState.isActive else {
            deactivateDecoyBeaconEffect()
            return
        }

        playDecoyBeaconEffect(
            at: position,
            duration: decoyBeaconState.configuration.duration
        )
    }

    func updateDecoyBeacon(deltaTime: TimeInterval) {
        let frame = decoyBeaconState.update(deltaTime: deltaTime, enemies: enemies)

        guard let explosionCenter = frame.explosionCenter else {
            return
        }

        playDecoyBeaconExplosionEffect(
            at: explosionCenter,
            radius: decoyBeaconState.configuration.explosionRadius
        )
        destroyEnemies(ids: frame.destroyedEnemyIDs, weaponKind: .decoyBeacon)
    }

    func activateGravityWell(at center: CGPoint, enemyIDs: Set<Int>) {
        gravityWellState = GravityWellState(
            center: center,
            enemyIDs: enemyIDs,
            timeRemaining: weaponResolver.configuration.gravityWellPullDuration
        )
        playGravityWellEffect(at: center)
    }

    func updateGravityWell(deltaTime: TimeInterval) {
        guard var state = gravityWellState else {
            return
        }

        let clampedDelta = max(0, deltaTime)
        let pullDuration = max(weaponResolver.configuration.gravityWellPullDuration, 0.001)
        let pullDistance = weaponResolver.configuration.gravityWellRadius / CGFloat(pullDuration) * CGFloat(clampedDelta)

        for index in enemies.indices where state.enemyIDs.contains(enemies[index].id) {
            enemies[index].pullToward(state.center, distance: pullDistance)
            enemyNodes[enemies[index].id]?.apply(enemies[index])
        }

        state.timeRemaining = max(0, state.timeRemaining - clampedDelta)

        guard state.timeRemaining == 0 else {
            gravityWellState = state
            return
        }

        completeGravityWell(state)
    }

    func completeGravityWell(_ state: GravityWellState) {
        gravityWellState = nil
        gravityWellEffectNode?.removeFromParent()
        gravityWellEffectNode = nil

        let clearCircle = CollisionCircle(
            center: state.center,
            radius: weaponResolver.configuration.gravityWellClearRadius
        )
        let destroyedIDs = Set(
            enemies
                .filter { state.enemyIDs.contains($0.id) && !$0.isFrozen && clearCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )
        destroyEnemies(ids: destroyedIDs, weaponKind: .gravityWell)
    }

    func deactivateGravityWell() {
        gravityWellState = nil
        gravityWellEffectNode?.removeFromParent()
        gravityWellEffectNode = nil
    }

    func freezeEnemies(ids enemyIDs: Set<Int>, duration: TimeInterval) {
        guard !enemyIDs.isEmpty, duration > 0 else {
            return
        }
        for index in enemies.indices where enemyIDs.contains(enemies[index].id) {
            enemies[index].freeze(duration: duration)
            enemyNodes[enemies[index].id]?.apply(enemies[index])
        }
    }

    func updateFrozenCrasher(deltaTime: TimeInterval) {
        guard frozenCrasherTimeRemaining > 0 else {
            return
        }

        frozenCrasherTimeRemaining = max(0, frozenCrasherTimeRemaining - max(0, deltaTime))
    }

    func shatterFrozenContactEnemies(playerPosition: CGPoint) {
        guard frozenCrasherTimeRemaining > 0 else {
            return
        }
        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )
        let shatterIDs = Set(
            enemies
                .filter { $0.isFrozen && playerCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )

        guard !shatterIDs.isEmpty else {
            return
        }
        playFrozenShatterEffect(at: positions(forEnemyIDs: shatterIDs), color: theme.playerColor)
        let previousComboMultiplier = runController.comboMultiplier
        runController.recordFrozenShatters(count: shatterIDs.count, weaponKind: .freezeBurst)
        playEnemyClearHaptics(killCount: shatterIDs.count, previousComboMultiplier: previousComboMultiplier)
        removeEnemies(ids: shatterIDs)
    }
}

private struct ArenaControlHitTarget {
    let action: ArenaControlAction
    let frame: CGRect
}

private enum ArenaControlAction: Equatable {
    case play
    case playAgain
    case openModes
    case openAwards
    case openOptions
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
    case toggleEffects
    case selectTheme(ArenaThemeKind)
    case resetData
    case exportDiagnostics
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

private extension ArenaUISceneState {
    var diagnosticName: String {
        switch self {
        case .home:
            return "home"
        case .modeSelect:
            return "modeSelect"
        case .awards:
            return "awards"
        case .options:
            return "options"
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
