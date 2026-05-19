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
    private let pauseControlNode = SKNode()
    private let pauseIconNode = SKNode()
    private let resumeIconNode = SKShapeNode()
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
        rebuildArena()
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

        [timerLabel, centerLabel, detailLabel].forEach { label in
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
        timerLabel.position = CGPoint(x: 24, y: max(24, size.height - 24))
        centerLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        detailLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 12)
    }

    private func layoutPauseControl() {
        pauseControlNode.position = CGPoint(
            x: max(pauseControlSize.width / 2, size.width - 32),
            y: max(pauseControlSize.height / 2, size.height - 32)
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

        updatePauseControl()
    }

    private func formatSurvivalTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
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
