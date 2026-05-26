import SpriteKit

@MainActor
final class PlayerCraftNode: SKNode {
    private let glowNode: SKShapeNode
    private let bodyNode: SKShapeNode
    private let coreNode: SKShapeNode
    private let engineNode: SKShapeNode
    private let visualRadius: CGFloat

    init(theme: ArenaTheme, visualRadius: CGFloat) {
        glowNode = SKShapeNode(path: Self.makeBodyPath(radius: visualRadius * 1.08))
        bodyNode = SKShapeNode(path: Self.makeBodyPath(radius: visualRadius))
        coreNode = SKShapeNode(circleOfRadius: visualRadius * 0.23)
        engineNode = SKShapeNode(ellipseOf: CGSize(width: visualRadius * 0.34, height: visualRadius * 0.2))
        self.visualRadius = visualRadius
        super.init()

        zPosition = 20

        applyTheme(theme)
        addChild(glowNode)
        addChild(bodyNode)
        addChild(coreNode)
        addChild(engineNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerCraftNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.fillColor = theme.playerAccentColor.withAlphaComponent(0.1)
        glowNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.28)
        glowNode.lineWidth = 1
        glowNode.lineJoin = .round
        glowNode.glowWidth = 2

        bodyNode.fillColor = theme.playerColor
        bodyNode.strokeColor = theme.playerAccentColor
        bodyNode.lineWidth = 1.8
        bodyNode.lineJoin = .round
        bodyNode.glowWidth = 1

        coreNode.fillColor = theme.playerAccentColor
        coreNode.strokeColor = theme.playerColor.withAlphaComponent(0.86)
        coreNode.lineWidth = 0.8
        coreNode.position = CGPoint(x: 0, y: -visualRadius * 0.03)
        coreNode.glowWidth = 1.6

        engineNode.fillColor = theme.playerAccentColor.withAlphaComponent(0.58)
        engineNode.strokeColor = .clear
        engineNode.position = CGPoint(x: 0, y: -visualRadius * 0.54)
        engineNode.glowWidth = 1.2
    }

    func apply(state: PlayerMovementState, speedFraction rawSpeedFraction: CGFloat) {
        position = state.position
        let speedFraction = min(1, max(0, rawSpeedFraction))
        engineNode.alpha = 0.36 + speedFraction * 0.4
        engineNode.setScale(0.82 + speedFraction * 0.42)
        glowNode.alpha = 0.5 + speedFraction * 0.22

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
