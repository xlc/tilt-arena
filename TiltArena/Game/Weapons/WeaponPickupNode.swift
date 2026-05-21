import SpriteKit

@MainActor
final class WeaponPickupNode: SKNode {
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode

    init(pickup: WeaponPickup, theme: ArenaTheme) {
        bodyNode = SKShapeNode(path: Self.makeDiamondPath(radius: pickup.radius))
        ringNode = SKShapeNode(circleOfRadius: pickup.radius * 1.45)
        super.init()

        zPosition = 14

        let color = Self.color(for: pickup.kind, theme: theme)
        ringNode.strokeColor = color.withAlphaComponent(0.45)
        ringNode.lineWidth = 1
        ringNode.fillColor = .clear
        ringNode.glowWidth = 1
        addChild(ringNode)

        bodyNode.fillColor = color.withAlphaComponent(0.9)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.8)
        bodyNode.lineWidth = 1.1
        bodyNode.glowWidth = 2
        addChild(bodyNode)

        apply(pickup)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("WeaponPickupNode does not support storyboard initialization.")
    }

    func apply(_ pickup: WeaponPickup) {
        position = pickup.position
    }

    private static func color(for kind: WeaponKind, theme: ArenaTheme) -> SKColor {
        switch kind {
        case .shockwave:
            return theme.pickupAmber
        case .seekerSwarm:
            return theme.pickupViolet
        case .razorShield:
            return theme.pickupBlue
        case .freezeBurst:
            return theme.pickupBlue
        case .gravityWell:
            return theme.pickupViolet
        case .chainLightning:
            return theme.pickupBlue
        case .flameTrail:
            return theme.pickupAmber
        case .warpDash:
            return theme.pickupViolet
        case .novaBomb:
            return theme.pickupAmber
        }
    }

    private static func makeDiamondPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius * 0.78, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius * 0.78, y: 0))
        path.closeSubpath()
        return path
    }
}
