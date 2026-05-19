import SpriteKit

final class ArenaScene: SKScene {
    private let theme = ArenaTheme.darkTacticalRadar
    private let tiltSettingsStore = TiltSettingsStore()
    private var arenaRoot = SKNode()
    private lazy var tiltInputController = TiltInputController(settingsStore: tiltSettingsStore)
    private var movementController = PlayerMovementController()
    private var playerNode: PlayerCraftNode?
    private var playerTrailNode: PlayerTrailNode?
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
        placePlayer(resetPosition: true)
        tiltInputController.start()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
        placePlayer(resetPosition: playerNode == nil)
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

        let input = tiltInputController.update(deltaTime: deltaTime)
        let state = movementController.update(input: input, deltaTime: deltaTime, arenaSize: size)
        applyPlayerState(state, resetTrail: false)
    }

    func recalibrateTiltControls() {
        tiltInputController.recalibrateToCurrentAttitude()
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
}
