import SpriteKit

@MainActor
final class WeaponPickupNode: SKNode {
    private let haloNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let badgeNode: SKShapeNode
    private let iconNode: SKSpriteNode
    private var theme: ArenaTheme

    init(pickup: WeaponPickup, theme: ArenaTheme) {
        haloNode = SKShapeNode()
        ringNode = SKShapeNode()
        badgeNode = SKShapeNode()
        iconNode = SKSpriteNode()
        self.theme = theme
        super.init()

        zPosition = 14

        applyAppearance(for: pickup.kind, radius: pickup.radius)
        addChild(haloNode)
        addChild(ringNode)
        addChild(badgeNode)
        addChild(iconNode)
        startIdleAnimation()
        apply(pickup)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("WeaponPickupNode does not support storyboard initialization.")
    }

    func apply(_ pickup: WeaponPickup) {
        position = pickup.position
    }

    func applyTheme(_ theme: ArenaTheme, pickup: WeaponPickup) {
        self.theme = theme
        applyAppearance(for: pickup.kind, radius: pickup.radius)
        startIdleAnimation()
    }

    private func applyAppearance(for kind: WeaponKind, radius: CGFloat) {
        let color = Self.color(for: kind, theme: theme)

        haloNode.path = Self.circlePath(radius: radius * 1.34)
        haloNode.strokeColor = color.withAlphaComponent(0.1)
        haloNode.lineWidth = 2
        haloNode.fillColor = .clear
        haloNode.glowWidth = 0.8

        ringNode.path = Self.circlePath(radius: radius * 1.16)
        ringNode.strokeColor = color.withAlphaComponent(0.46)
        ringNode.lineWidth = 1.2
        ringNode.fillColor = .clear
        ringNode.glowWidth = 0.35

        badgeNode.path = Self.circlePath(radius: radius * 0.94)
        badgeNode.fillColor = color.withAlphaComponent(0.08)
        badgeNode.strokeColor = theme.playerColor.withAlphaComponent(0.38)
        badgeNode.lineWidth = 0.9
        badgeNode.glowWidth = 0.2

        iconNode.texture = Self.iconTexture(for: kind)
        iconNode.size = CGSize(width: radius * 2.12, height: radius * 2.12)
        iconNode.alpha = 0.94
        iconNode.colorBlendFactor = 0
        iconNode.blendMode = .alpha
    }

    private func startIdleAnimation() {
        haloNode.removeAction(forKey: "pickup.idle.halo")
        ringNode.removeAction(forKey: "pickup.idle.ring")
        iconNode.removeAction(forKey: "pickup.idle.icon")

        haloNode.alpha = 1
        haloNode.setScale(1)
        ringNode.alpha = 1
        ringNode.setScale(1)
        iconNode.alpha = 0.94
        iconNode.setScale(1)

        haloNode.run(Self.breatheAction(scale: 1.035, lowAlpha: 0.24, duration: 0.82), withKey: "pickup.idle.halo")
        ringNode.run(Self.breatheAction(scale: 1.02, lowAlpha: 0.54, duration: 0.64), withKey: "pickup.idle.ring")
        iconNode.run(Self.scalePulseAction(scale: 1.01, duration: 0.68), withKey: "pickup.idle.icon")
    }

    private static func breatheAction(scale: CGFloat, lowAlpha: CGFloat, duration: TimeInterval) -> SKAction {
        .repeatForever(.sequence([
            .group([
                .scale(to: scale, duration: duration),
                .fadeAlpha(to: lowAlpha, duration: duration)
            ]),
            .group([
                .scale(to: 1, duration: duration),
                .fadeAlpha(to: 1, duration: duration)
            ])
        ]))
    }

    private static func scalePulseAction(scale: CGFloat, duration: TimeInterval) -> SKAction {
        .repeatForever(.sequence([
            .scale(to: scale, duration: duration),
            .scale(to: 1, duration: duration)
        ]))
    }

    private static func iconTexture(for kind: WeaponKind) -> SKTexture {
        SKTexture(
            rect: WeaponSpriteSheet.textureRect(for: kind, role: .icon),
            in: SKTexture(imageNamed: WeaponSpriteSheet.assetName)
        )
    }

    private static func color(for kind: WeaponKind, theme: ArenaTheme) -> SKColor {
        switch kind {
        case .shockwave, .flameTrail, .powerWave, .novaBomb:
            return theme.pickupAmber
        case .seekerSwarm, .gravityWell, .warpDash:
            return theme.pickupViolet
        case .razorShield, .freezeBurst, .chainLightning, .ricochetLance:
            return theme.pickupBlue
        }
    }

    private static func circlePath(radius: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }
}
