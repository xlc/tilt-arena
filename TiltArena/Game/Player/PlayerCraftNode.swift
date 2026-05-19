import SpriteKit

@MainActor
final class PlayerCraftNode: SKNode {
    private let bodyNode: SKShapeNode
    private let coreNode: SKShapeNode

    init(theme: ArenaTheme, visualRadius: CGFloat) {
        bodyNode = SKShapeNode(path: Self.makeBodyPath(radius: visualRadius))
        coreNode = SKShapeNode(circleOfRadius: visualRadius * 0.2)
        super.init()

        zPosition = 20

        bodyNode.fillColor = theme.playerColor
        bodyNode.strokeColor = theme.playerAccentColor
        bodyNode.lineWidth = 1.4
        bodyNode.lineJoin = .round
        bodyNode.glowWidth = 1.5
        addChild(bodyNode)

        coreNode.fillColor = theme.playerAccentColor
        coreNode.strokeColor = .clear
        coreNode.position = CGPoint(x: 0, y: -visualRadius * 0.03)
        coreNode.glowWidth = 3
        addChild(coreNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerCraftNode does not support storyboard initialization.")
    }

    func apply(state: PlayerMovementState) {
        position = state.position

        guard state.velocity.length > 2 else {
            return
        }

        zRotation = atan2(state.velocity.dy, state.velocity.dx) - (.pi / 2)
    }

    private static func makeBodyPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: -radius * 0.72, y: -radius * 0.68))
        path.addLine(to: CGPoint(x: 0, y: -radius * 0.34))
        path.addLine(to: CGPoint(x: radius * 0.72, y: -radius * 0.68))
        path.closeSubpath()
        return path
    }
}
