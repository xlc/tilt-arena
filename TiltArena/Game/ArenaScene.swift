import SpriteKit

final class ArenaScene: SKScene {
    private let theme = ArenaTheme.darkTacticalRadar
    private let tiltSettingsStore = TiltSettingsStore()
    private var arenaRoot = SKNode()
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    private var movementController = PlayerMovementController()
    private var runController = ClassicRunController()
    private var spawnPlanner = ChaserSpawnPlanner()
    private var enemies: [ChaserEnemy] = []
    private var enemyNodes: [Int: ChaserEnemyNode] = [:]
    private var playerNode: PlayerCraftNode?
    private var playerTrailNode: PlayerTrailNode?
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let centerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let detailLabel = SKLabelNode(fontNamed: "Menlo")
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
        rebuildArena()
        configureLabels()
        placePlayer(resetPosition: true)
        updateRunDisplay()
        tiltInputController.start()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
        placePlayer(resetPosition: playerNode == nil)
        layoutLabels()
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touches.isEmpty else {
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

        [timerLabel, centerLabel, detailLabel].forEach { label in
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
        timerLabel.position = CGPoint(x: 24, y: max(24, size.height - 24))
        centerLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        detailLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 12)
    }

    private func startRun() {
        runController.start()
        resetGameplayObjects()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
        updateRunDisplay()
    }

    private func restartRun() {
        runController.restart()
        resetGameplayObjects()
        placePlayer(resetPosition: true)
        resetPlayerFeedback()
        updateRunDisplay()
    }

    private func resetGameplayObjects() {
        enemies.removeAll()
        enemyNodes.values.forEach { $0.removeFromParent() }
        enemyNodes.removeAll()
        spawnPlanner.reset()
    }

    private func resetPlayerFeedback() {
        playerNode?.removeAllActions()
        playerNode?.alpha = 1
        playerNode?.setScale(1)
    }

    private func updateActiveRun(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let spawnCount = runController.update(deltaTime: deltaTime, activeEnemyCount: enemies.count)
        spawnChasers(count: spawnCount, playerPosition: playerPosition)
        advanceChasers(deltaTime: deltaTime, playerPosition: playerPosition)
        detectPlayerCollision(playerPosition: playerPosition)
        updateRunDisplay()
    }

    private func spawnChasers(count: Int, playerPosition: CGPoint) {
        guard count > 0 else {
            return
        }

        let playableRect = movementController.configuration.playableRect(in: size)

        for _ in 0..<count {
            guard let enemy = spawnPlanner.spawnChaser(
                in: playableRect,
                avoiding: playerPosition,
                configuration: runController.configuration
            ) else {
                continue
            }

            enemies.append(enemy)

            let node = ChaserEnemyNode(enemy: enemy, theme: theme)
            enemyNodes[enemy.id] = node
            addChild(node)
        }
    }

    private func advanceChasers(deltaTime: TimeInterval, playerPosition: CGPoint) {
        for index in enemies.indices {
            enemies[index].advance(toward: playerPosition, deltaTime: deltaTime)
            enemyNodes[enemies[index].id]?.apply(enemies[index])
        }
    }

    private func detectPlayerCollision(playerPosition: CGPoint) {
        let playerCircle = CollisionCircle(
            center: playerPosition,
            radius: runController.configuration.playerHitRadius
        )

        guard enemies.contains(where: { playerCircle.intersects($0.collisionCircle) }) else {
            return
        }

        runController.endRun()
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
            timerLabel.text = formatSurvivalTime(0)
            centerLabel.text = "TAP TO START"
            detailLabel.text = "CLASSIC SURVIVAL"
        case .active:
            timerLabel.text = formatSurvivalTime(runController.survivalTime)
            centerLabel.text = ""
            detailLabel.text = ""
        case .paused:
            timerLabel.text = formatSurvivalTime(runController.survivalTime)
            centerLabel.text = "PAUSED"
            detailLabel.text = ""
        case .gameOver:
            timerLabel.text = formatSurvivalTime(runController.survivalTime)
            centerLabel.text = "GAME OVER"
            detailLabel.text = "\(formatSurvivalTime(runController.survivalTime))  TAP TO RESTART"
        }
    }

    private func formatSurvivalTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }
}
