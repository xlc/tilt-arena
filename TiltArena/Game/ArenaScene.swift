// swiftlint:disable file_length
import SpriteKit

// swiftlint:disable:next type_body_length
final class ArenaScene: SKScene {
    let theme = ArenaTheme.darkTacticalRadar
    private let tiltSettingsStore = TiltSettingsStore()
    private let runProfileStore = RunProfileStore()
    private let localOptionsStore = ArenaLocalOptionsStore()
    private var arenaRoot = SKNode()
    private let uiRoot = SKNode()
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    var movementController = PlayerMovementController()
    private var runController = ClassicRunController()
    private var runProfile = RunProfile()
    private var localOptions = ArenaLocalOptions()
    private var uiState: ArenaUISceneState = .home
    private var optionsReturnState: ArenaUISceneState = .home
    private var selectedMode: ArenaModeKind = .classic
    private var previousBestScore = 0
    private var resetDataArmed = false
    private var hasPersistedFinalRun = false
    private var readyHoldController = ReadyStartHoldController()
    private var readyStartPoint = CGPoint.zero
    private var readyProgressRing: SKShapeNode?
    private var readyStatusLabel: SKLabelNode?
    private var spawnDirector = EnemySpawnDirector()
    private let pickupSpawnConfiguration = PickupSpawnConfiguration()
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
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let bestMarkerLabel = SKLabelNode(fontNamed: "Menlo")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let pauseControlNode = SKNode()
    private let pauseIconNode = SKNode()
    private let hudMargin: CGFloat = 24
    private let pauseControlSize = CGSize(width: 48, height: 48)
    private var uiHitTargets: [ArenaControlHitTarget] = []
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
        rebuildArena()
        if flameTrailEffectNode.parent == nil { addChild(flameTrailEffectNode) }
        configureLabels()
        configurePauseControl()
        configureUIRoot()
        placePlayer(resetPosition: true)
        updateRunDisplay()
        rebuildUI()
        tiltInputController.start()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
        placePlayer(resetPosition: playerNode == nil || uiState == .home)
        if uiState == .preRun {
            readyStartPoint = movementController.state.position
            readyHoldController.reset()
        }
        layoutLabels()
        layoutPauseControl()
        rebuildUI()
    }

    override func willMove(from view: SKView) {
        tiltInputController.stop()
        lastUpdateTime = nil
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

        switch uiState {
        case .preRun:
            updatePreRun(deltaTime: deltaTime)
        case .activeGameplay:
            updateGameplay(deltaTime: deltaTime)
        case .home, .modeSelect, .awards, .options, .pause, .postRun:
            break
        }
    }

    func recalibrateTiltControls() {
        tiltInputController.recalibrateToCurrentAttitude()
        updateRunDisplay()
        rebuildUI()
    }

    func refreshSafeAreaLayout() {
        layoutLabels()
        layoutPauseControl()
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
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(size: size)
        addChild(arenaRoot)
    }

    private func configureUIRoot() {
        guard uiRoot.parent == nil else {
            return
        }

        uiRoot.zPosition = 70
        addChild(uiRoot)
    }

    private func placePlayer(resetPosition: Bool) {
        ensurePlayerNodes()

        let state = resetPosition
            ? movementController.reset(in: size)
            : movementController.clampToArena(size)

        applyPlayerState(state, resetTrail: true)
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
            movementController.configuration.maximumSpeed(in: size)
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
        addPauseControlBackground()
        configurePauseIcon()
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

    private func updatePreRun(deltaTime: TimeInterval) {
        let input = tiltInputController.update(deltaTime: deltaTime)
        let state = movementController.update(input: input, deltaTime: deltaTime, arenaSize: size)
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

        let input = tiltInputController.update(deltaTime: deltaTime)
        let state = movementController.update(input: input, deltaTime: deltaTime, arenaSize: size)
        applyPlayerState(state, resetTrail: false)
        updateActiveRun(deltaTime: deltaTime, playerPosition: state.position)
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
    }

    private func startRun() {
        runController.start()
        readyHoldController.reset()
        resetActiveRun()
        show(.activeGameplay)
    }

    private func pauseRun() {
        runController.pause()
        tiltInputController.resetSmoothedInput()
        show(.pause)
    }

    private func resumeRun() {
        tiltInputController.resetSmoothedInput()
        runController.resume()
        show(.activeGameplay)
    }

    private func finishRun(playFeedback: Bool = true) {
        previousBestScore = runProfile.bestScore
        runController.endRun()
        persistFinalRunIfNeeded()
        if playFeedback {
            playDeathFeedback()
        }
        show(.postRun)
    }

    private func resetActiveRun() {
        hasPersistedFinalRun = false
        resetGameplayObjects()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
        updateRunDisplay()
    }

    private func resetGameplayObjects() {
        enemies.removeAll()
        enemyNodes.values.forEach { $0.removeFromParent() }
        enemyNodes.removeAll()
        enemyTelegraphNodes.values.forEach { $0.removeFromParent() }
        enemyTelegraphNodes.removeAll()
        formationEnemyIDs.removeAll()
        spawnDirector.reset()

        pickups.removeAll()
        pickupNodes.values.forEach { $0.removeFromParent() }
        pickupNodes.removeAll()
        pickupPlanner.reset(configuration: pickupSpawnConfiguration)
        deactivateRazorShield()
        frozenCrasherTimeRemaining = 0
        flameTrailState.reset()
        flameTrailEffectNode.reset()
        deactivateGravityWell()
    }

    private func resetPlayerFeedback() {
        playerNode?.removeAllActions()
        playerNode?.alpha = 1
        playerNode?.setScale(1)
    }

    private func updateActiveRun(deltaTime: TimeInterval, playerPosition: CGPoint) {
        runController.update(deltaTime: deltaTime)
        spawnEnemiesIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        spawnPickupIfNeeded(deltaTime: deltaTime, playerPosition: playerPosition)
        collectPickups(playerPosition: playerPosition)
        advanceEnemies(deltaTime: deltaTime, playerPosition: playerPosition)
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
        let playableRect = movementController.configuration.playableRect(in: size)
        let frame = spawnDirector.update(
            deltaTime: deltaTime,
            survivalTime: runController.survivalTime,
            activeEnemies: enemies,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickups.map(\.collisionCircle)
        )

        removeEnemyTelegraphs(ids: frame.telegraphIDsToRemove)
        showEnemyTelegraphs(frame.telegraphsToShow)
        addSpawnedEnemies(frame.newEnemies)
    }

    private func addSpawnedEnemies(_ spawnedEnemies: [ArenaEnemy]) {
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
        let playableRect = movementController.configuration.playableRect(in: size)
        let enemyCircles = enemies.map(\.collisionCircle)

        guard let pickup = pickupPlanner.update(
            deltaTime: deltaTime,
            phase: runController.phase,
            activePickupCount: pickups.count,
            playableRect: playableRect,
            playerPosition: playerPosition,
            enemyCircles: enemyCircles,
            configuration: pickupSpawnConfiguration
        ) else {
            return
        }

        pickups.append(pickup)

        let node = WeaponPickupNode(pickup: pickup, theme: theme)
        pickupNodes[pickup.id] = node
        addChild(node)
    }

    private func advanceEnemies(deltaTime: TimeInterval, playerPosition: CGPoint) {
        for index in enemies.indices {
            enemies[index].advance(toward: playerPosition, deltaTime: deltaTime)
            enemyNodes[enemies[index].id]?.apply(enemies[index])
        }
    }

    private func cullExitedLinearPatternEnemies() {
        let playableRect = movementController.configuration.playableRect(in: size)
        let cullingRect = playableRect.insetBy(
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

    private func collectPickups(playerPosition: CGPoint) {
        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: movementController.configuration.visualRadius
        )
        let collectedPickups = pickups.filter { playerCircle.intersects($0.collisionCircle) }

        guard !collectedPickups.isEmpty else {
            return
        }

        for pickup in collectedPickups {
            if isDangerGrab(pickup) {
                runController.recordDangerGrab(pickupID: pickup.id)
            }

            removePickup(id: pickup.id)
            applyWeapon(pickup.kind, playerPosition: playerPosition)
        }
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
        case .novaBomb:
            playNovaBombEffect()
        }

        destroyEnemies(ids: resolution.destroyedEnemyIDs, weaponKind: kind)
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

        runController.recordEnemyKills(count: enemyIDs.count, weaponKind: weaponKind)
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
            node.strokeColor = theme.pickupBlue.withAlphaComponent(0.9)
            node.fillColor = .clear
            node.lineWidth = 2
            node.glowWidth = 4
            node.zPosition = 19
            addChild(node)
            razorShieldNode = node
        }

        razorShieldNode?.position = playerPosition
        razorShieldNode?.isHidden = false
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
            deactivateRazorShield()
        }
    }

    private func deactivateRazorShield() {
        razorShieldTimeRemaining = 0
        razorShieldNode?.removeFromParent()
        razorShieldNode = nil
    }

    private func updateFlameTrail(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let frame = flameTrailState.update(deltaTime: deltaTime, playerPosition: playerPosition, enemies: enemies)
        destroyEnemies(ids: frame.burnedEnemyIDs, weaponKind: .flameTrail)
        flameTrailEffectNode.apply(segments: frame.segments)
    }

    private func detectPlayerCollision(playerPosition: CGPoint) {
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

    private func updateRunDisplay() {
        timerLabel.alpha = uiState == .pause || uiState == .postRun ? 0.55 : 1

        switch uiState {
        case .home, .modeSelect, .awards, .options:
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

        for enemy in enemies where nearMissCircle.intersects(enemy.collisionCircle) {
            guard !hitCircle.intersects(enemy.collisionCircle) else {
                continue
            }

            runController.recordNearMiss(enemyID: enemy.id)
        }
    }

    private func isDangerGrab(_ pickup: WeaponPickup) -> Bool {
        enemies.contains { enemy in
            let dangerDistance = runController.configuration.dangerGrabEnemyDistance
                + pickup.radius
                + enemy.radius
            return squaredDistance(from: pickup.position, to: enemy.position) <= dangerDistance * dangerDistance
        }
    }

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func persistFinalRunIfNeeded() {
        guard !hasPersistedFinalRun, let summary = runController.finalizedSummary else {
            return
        }

        runProfile = runProfileStore.record(summary)
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
        for xOffset in [CGFloat(-5.5), CGFloat(5.5)] {
            let bar = SKShapeNode(rectOf: CGSize(width: 5, height: 18), cornerRadius: 1.5)
            bar.position = CGPoint(x: xOffset, y: 0)
            bar.fillColor = theme.playerColor
            bar.strokeColor = theme.playerColor
            pauseIconNode.addChild(bar)
        }

        pauseControlNode.addChild(pauseIconNode)
    }
}

private extension ArenaScene {
    func show(_ state: ArenaUISceneState) {
        if state != .options {
            resetDataArmed = false
        }

        uiState = state
        updateRunDisplay()
        rebuildUI()
    }

    func rebuildUI() {
        uiRoot.removeAllChildren()
        uiHitTargets.removeAll()
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

    func renderHome() {
        let layout = currentLandscapeLayout()
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
            frame: layout.lowerRightButtonFrame,
            action: .play,
            style: .primary
        )

        let buttonSize = CGSize(width: 108, height: 38)
        addButton(
            "MODES",
            frame: layout.bottomButtonFrame(index: 0, count: 3, buttonSize: buttonSize),
            action: .openModes,
            style: .secondary
        )
        addButton(
            "AWARDS",
            frame: layout.bottomButtonFrame(index: 1, count: 3, buttonSize: buttonSize),
            action: .openAwards,
            style: .secondary
        )
        addButton(
            "OPTIONS",
            frame: layout.bottomButtonFrame(index: 2, count: 3, buttonSize: buttonSize),
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

        addButton(
            "CALIBRATE",
            frame: CGRect(x: left.minX + 14, y: left.maxY - 62, width: 148, height: 40),
            action: .calibrate,
            style: .primary
        )
        let settings = tiltSettingsStore.settings
        addSmallLabel(
            "SENSITIVITY \(String(format: "%.1f", settings.clampedSensitivity))",
            at: CGPoint(x: left.minX + 14, y: left.maxY - 90),
            color: theme.borderColor,
            alignment: .left
        )
        addButton(
            "-",
            frame: CGRect(x: left.minX + 14, y: left.maxY - 140, width: 44, height: 36),
            action: .sensitivityDown,
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: left.minX + 70, y: left.maxY - 140, width: 44, height: 36),
            action: .sensitivityUp,
            style: .secondary
        )

        let presetY = left.maxY - 196
        for (index, preset) in [TiltCalibrationPreset.standard, .flatTable, .reclined].enumerated() {
            let frame = CGRect(
                x: left.minX + 14 + CGFloat(index) * 82,
                y: presetY,
                width: 74,
                height: 34
            )
            addButton(
                presetTitle(preset),
                frame: frame,
                action: .preset(preset),
                style: settings.calibration.preset == preset ? .primary : .secondary
            )
        }

        addToggle(
            title: "AUDIO",
            isOn: localOptions.audioEnabled,
            frame: CGRect(x: right.minX + 14, y: right.maxY - 62, width: 132, height: 38),
            action: .toggleAudio
        )
        addToggle(
            title: "HAPTICS",
            isOn: localOptions.hapticsEnabled,
            frame: CGRect(x: right.minX + 14, y: right.maxY - 112, width: 132, height: 38),
            action: .toggleHaptics
        )
        addToggle(
            title: "EFFECTS",
            isOn: !localOptions.reducedEffects,
            frame: CGRect(x: right.minX + 14, y: right.maxY - 162, width: 132, height: 38),
            action: .toggleEffects
        )
        addButton(
            resetDataArmed ? "CONFIRM RESET" : "RESET DATA",
            frame: CGRect(x: right.minX + 14, y: right.minY + 12, width: 156, height: 34),
            action: .resetData,
            style: .danger
        )
    }

    func renderPreRun() {
        let layout = currentLandscapeLayout()
        addButton(
            "CAL",
            frame: CGRect(x: layout.safeRect.maxX - 112, y: layout.safeRect.maxY - 40, width: 48, height: 36),
            action: .calibrate,
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
            action: .calibrate,
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
        addDeathClarityMarker(at: movementController.state.position)

        let right = layout.rightColumnFrame(width: 230)
        addPanel(frame: right)
        let highlights = ArenaMenuContent.postRunHighlights(
            summary: summary,
            profile: runProfile,
            previousBestScore: previousBestScore
        )
        for (index, text) in highlights.enumerated() {
            addSmallLabel(
                text,
                at: CGPoint(x: right.minX + 14, y: right.maxY - 28 - CGFloat(index) * 26),
                color: index == 0 ? theme.playerAccentColor : theme.borderColor,
                alignment: .left
            )
        }

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
        case .play:
            if selectedModeIsAvailable {
                preparePreRun()
            }
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
        case .home:
            resetMenuPreviewIfNeeded()
            show(.home)
        case .back:
            show(uiState == .options ? optionsReturnState : .home)
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
        case .sensitivityDown:
            tiltSettingsStore.updateSensitivity(tiltSettingsStore.settings.clampedSensitivity - 0.1)
            rebuildUI()
        case .sensitivityUp:
            tiltSettingsStore.updateSensitivity(tiltSettingsStore.settings.clampedSensitivity + 0.1)
            rebuildUI()
        case let .preset(preset):
            tiltSettingsStore.selectPreset(preset)
            rebuildUI()
        case .toggleAudio:
            localOptions.audioEnabled.toggle()
            localOptionsStore.options = localOptions
            rebuildUI()
        case .toggleHaptics:
            localOptions.hapticsEnabled.toggle()
            localOptionsStore.options = localOptions
            rebuildUI()
        case .toggleEffects:
            localOptions.reducedEffects.toggle()
            localOptionsStore.options = localOptions
            rebuildUI()
        case .resetData:
            resetLocalDataOrArmConfirmation()
        }
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
        selectedMode = .classic
        resetDataArmed = false
        rebuildUI()
        updateRunDisplay()
    }

    func addReadyStartCircle(at point: CGPoint) {
        let radius = readyHoldController.configuration.startCircleRadius
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.position = point
        circle.strokeColor = theme.playerAccentColor.withAlphaComponent(0.9)
        circle.fillColor = theme.playerAccentColor.withAlphaComponent(0.06)
        circle.lineWidth = 2
        circle.glowWidth = 5
        uiRoot.addChild(circle)

        let progress = SKShapeNode(circleOfRadius: radius + 8)
        progress.position = point
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
        uiRoot.addChild(label)
        readyStatusLabel = label

        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 2) {
            let tick = SKShapeNode(rectOf: CGSize(width: 3, height: 12), cornerRadius: 1)
            tick.position = CGPoint(
                x: point.x + cos(angle) * (radius + 16),
                y: point.y + sin(angle) * (radius + 16)
            )
            tick.zRotation = angle
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
            dot.fillColor = theme.enemyColor.withAlphaComponent(0.5)
            dot.strokeColor = theme.enemyColor.withAlphaComponent(0.75)
            dot.lineWidth = 1
            uiRoot.addChild(dot)
        }

        let pickup = SKShapeNode(circleOfRadius: 9)
        pickup.position = CGPoint(x: center.x + 52, y: center.y - 36)
        pickup.fillColor = theme.pickupAmber.withAlphaComponent(0.25)
        pickup.strokeColor = theme.pickupAmber
        pickup.lineWidth = 2
        uiRoot.addChild(pickup)
    }

    func addDeathClarityMarker(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.position = position
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
            fraction: row.progressFraction,
            placeholder: row.isPlaceholderProgress
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
        scrim.fillColor = SKColor.black.withAlphaComponent(alpha)
        scrim.strokeColor = .clear
        uiRoot.addChild(scrim)
    }

    func addPanel(
        frame: CGRect,
        stroke: SKColor = SKColor(red: 0.37, green: 0.66, blue: 0.78, alpha: 0.35),
        fill: SKColor = SKColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 0.62)
    ) {
        let panel = SKShapeNode(rect: frame, cornerRadius: 8)
        panel.fillColor = fill
        panel.strokeColor = stroke
        panel.lineWidth = 1
        uiRoot.addChild(panel)
    }

    func addProgressBar(frame: CGRect, fraction: Double, placeholder: Bool) {
        let background = SKShapeNode(rect: frame, cornerRadius: 2)
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
        fill.fillColor = (placeholder ? theme.pickupAmber : theme.playerAccentColor).withAlphaComponent(0.85)
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
        let label = SKLabelNode(fontNamed: fontSize >= 16 ? "Menlo-Bold" : "Menlo")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        uiRoot.addChild(label)
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
        runController.recordFrozenShatters(count: shatterIDs.count, weaponKind: .freezeBurst)
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
    case resetData
}

private enum ArenaButtonStyle {
    case primary
    case secondary
    case danger
}
