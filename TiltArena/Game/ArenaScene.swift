import SpriteKit

final class ArenaScene: SKScene {
    let theme = ArenaTheme.darkTacticalRadar
    private let tiltSettingsStore = TiltSettingsStore()
    private let runProfileStore = RunProfileStore()
    private var arenaRoot = SKNode()
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    var movementController = PlayerMovementController()
    private var runController = ClassicRunController()
    private var runProfile = RunProfile()
    private var hasPersistedFinalRun = false
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
    private let centerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let detailLabel = SKLabelNode(fontNamed: "Menlo")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let pauseControlNode = SKNode()
    private let pauseIconNode = SKNode()
    private let resumeIconNode = SKShapeNode()
    private let hudMargin: CGFloat = 24
    private let pauseControlSize = CGSize(width: 48, height: 48)
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
        rebuildArena()
        if flameTrailEffectNode.parent == nil { addChild(flameTrailEffectNode) }
        configureLabels()
        configurePauseControl()
        placePlayer(resetPosition: true)
        updateRunDisplay()
        tiltInputController.start()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
        placePlayer(resetPosition: playerNode == nil)
        layoutLabels()
        layoutPauseControl()
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

        guard runController.phase == .active else {
            return
        }

        let input = tiltInputController.update(deltaTime: deltaTime)
        let state = movementController.update(input: input, deltaTime: deltaTime, arenaSize: size)
        applyPlayerState(state, resetTrail: false)
        updateActiveRun(deltaTime: deltaTime, playerPosition: state.position)
    }

    func recalibrateTiltControls() {
        tiltInputController.recalibrateToCurrentAttitude()
    }

    func refreshSafeAreaLayout() {
        layoutLabels()
        layoutPauseControl()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else {
            return
        }

        if touches.contains(where: isPauseControlTouch) {
            togglePauseControl()
            return
        }

        switch runController.phase {
        case .preRun:
            startRun()
        case .gameOver:
            restartRun()
        case .active, .paused:
            break
        }
    }

    private func rebuildArena() {
        arenaRoot.removeFromParent()
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(size: size)
        addChild(arenaRoot)
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

        configureLabel(centerLabel, fontSize: 22, color: theme.playerColor)
        centerLabel.horizontalAlignmentMode = .center
        centerLabel.verticalAlignmentMode = .center

        configureLabel(detailLabel, fontSize: 14, color: theme.borderColor)
        detailLabel.horizontalAlignmentMode = .center
        detailLabel.verticalAlignmentMode = .center

        configureLabel(comboLabel, fontSize: 14, color: theme.playerAccentColor)
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.verticalAlignmentMode = .bottom

        [timerLabel, centerLabel, detailLabel, comboLabel].forEach { label in
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
        configureResumeIcon()
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
        centerLabel.position = layout.centerPosition
        detailLabel.position = layout.detailPosition
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

    private func startRun() {
        runController.start()
        resetActiveRun()
    }

    private func restartRun() {
        runController.restart()
        resetActiveRun()
    }

    private func togglePauseControl() {
        switch runController.phase {
        case .active:
            pauseRun()
        case .paused:
            resumeRun()
        case .preRun, .gameOver:
            break
        }
    }

    private func pauseRun() {
        runController.pause()
        tiltInputController.resetSmoothedInput()
        updateRunDisplay()
    }

    private func resumeRun() {
        tiltInputController.resetSmoothedInput()
        runController.resume()
        updateRunDisplay()
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

    private func finishRun() {
        runController.endRun()
        persistFinalRunIfNeeded()
        playDeathFeedback()
        updateRunDisplay()
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
        switch runController.phase {
        case .preRun:
            timerLabel.text = "BEST \(runProfile.bestScore)"
            centerLabel.text = "TAP TO START"
            detailLabel.text = "CLASSIC SURVIVAL"
            comboLabel.text = ""
        case .active:
            timerLabel.text = "SCORE \(runController.score)  \(formatSurvivalTime(runController.survivalTime))"
            centerLabel.text = ""
            detailLabel.text = ""
            comboLabel.text = formatCombo()
        case .paused:
            timerLabel.text = "SCORE \(runController.score)  \(formatSurvivalTime(runController.survivalTime))"
            centerLabel.text = "PAUSED"
            detailLabel.text = ""
            comboLabel.text = formatCombo()
        case .gameOver:
            timerLabel.text = "BEST \(runProfile.bestScore)"

            if let summary = runController.finalizedSummary {
                centerLabel.text = "GAME OVER  \(summary.score)"
                detailLabel.text = "TIME \(formatSurvivalTime(summary.survivalTime))  MAX COMBO \(summary.maxCombo)  PLAY AGAIN"
                comboLabel.text = "KILLS \(summary.enemiesDestroyed)  WEAPON \(formatWeapon(summary.bestWeapon))"
            } else {
                centerLabel.text = "GAME OVER"
                detailLabel.text = "\(formatSurvivalTime(runController.survivalTime))  PLAY AGAIN"
                comboLabel.text = ""
            }
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

    private func formatWeapon(_ weaponKind: WeaponKind?) -> String {
        weaponKind?.displayName.uppercased() ?? "NONE"
    }

    private func isPauseControlTouch(_ touch: UITouch) -> Bool {
        switch runController.phase {
        case .active, .paused:
            return pauseControlFrame.contains(touch.location(in: self))
        case .preRun, .gameOver:
            return false
        }
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
        switch runController.phase {
        case .active:
            pauseControlNode.isHidden = false
            pauseIconNode.isHidden = false
            resumeIconNode.isHidden = true
        case .paused:
            pauseControlNode.isHidden = false
            pauseIconNode.isHidden = true
            resumeIconNode.isHidden = false
        case .preRun, .gameOver:
            pauseControlNode.isHidden = true
        }
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

    private func configureResumeIcon() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -5, y: -10))
        path.addLine(to: CGPoint(x: -5, y: 10))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.closeSubpath()

        resumeIconNode.path = path
        resumeIconNode.fillColor = theme.playerColor
        resumeIconNode.strokeColor = theme.playerColor
        pauseControlNode.addChild(resumeIconNode)
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
