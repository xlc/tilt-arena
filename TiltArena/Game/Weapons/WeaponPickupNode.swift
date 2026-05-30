import SpriteKit

@MainActor
final class WeaponPickupNode: SKNode {
    private let haloNode: SKShapeNode
    private let chargeRingNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let badgeNode: SKShapeNode
    private let iconNode: SKSpriteNode
    private var theme: ArenaTheme

    init(pickup: WeaponPickup, theme: ArenaTheme) {
        haloNode = SKShapeNode()
        chargeRingNode = SKShapeNode()
        ringNode = SKShapeNode()
        badgeNode = SKShapeNode()
        iconNode = SKSpriteNode()
        self.theme = theme
        super.init()

        zPosition = 14

        addChild(haloNode)
        addChild(chargeRingNode)
        addChild(ringNode)
        addChild(badgeNode)
        addChild(iconNode)
        apply(pickup)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("WeaponPickupNode does not support storyboard initialization.")
    }

    func apply(_ pickup: WeaponPickup) {
        position = pickup.position
        applyAppearance(for: pickup)
        startIdleAnimation(for: pickup.chargeTier)
    }

    func applyTheme(_ theme: ArenaTheme, pickup: WeaponPickup) {
        self.theme = theme
        applyAppearance(for: pickup)
        startIdleAnimation(for: pickup.chargeTier)
    }

    private func applyAppearance(for pickup: WeaponPickup) {
        let color = Self.color(for: pickup.kind, theme: theme)
        let radius = pickup.radius
        let chargeLevel = CGFloat(pickup.chargeTier.rawValue)

        haloNode.path = Self.circlePath(radius: radius * 1.34)
        haloNode.strokeColor = color.withAlphaComponent(0.1)
        haloNode.lineWidth = 2
        haloNode.fillColor = .clear
        haloNode.glowWidth = 0.8

        chargeRingNode.path = Self.circlePath(radius: radius * (1.45 + chargeLevel * 0.12))
        chargeRingNode.strokeColor = color.withAlphaComponent(0.28 + chargeLevel * 0.08)
        chargeRingNode.lineWidth = 0.9 + chargeLevel * 0.35
        chargeRingNode.fillColor = .clear
        chargeRingNode.glowWidth = 0.7 + chargeLevel * 0.25

        ringNode.path = Self.circlePath(radius: radius * 1.16)
        ringNode.strokeColor = color.withAlphaComponent(0.46 + chargeLevel * 0.08)
        ringNode.lineWidth = 1.2 + chargeLevel * 0.2
        ringNode.fillColor = .clear
        ringNode.glowWidth = 0.35

        badgeNode.path = Self.circlePath(radius: radius * 0.94)
        badgeNode.fillColor = color.withAlphaComponent(0.08 + chargeLevel * 0.03)
        badgeNode.strokeColor = theme.playerColor.withAlphaComponent(0.38)
        badgeNode.lineWidth = 0.9
        badgeNode.glowWidth = 0.2

        iconNode.texture = Self.iconTexture(for: pickup.kind)
        iconNode.size = CGSize(width: radius * 2.12, height: radius * 2.12)
        iconNode.alpha = 0.94
        iconNode.colorBlendFactor = 0
        iconNode.blendMode = .alpha

        applyChargeAppearance(for: pickup)
    }

    private func applyChargeAppearance(for pickup: WeaponPickup) {
        chargeRingNode.isHidden = pickup.chargeTier == .base
    }

    private func startIdleAnimation(for chargeTier: WeaponPickupChargeTier) {
        haloNode.removeAction(forKey: "pickup.idle.halo")
        chargeRingNode.removeAction(forKey: "pickup.idle.charge")
        ringNode.removeAction(forKey: "pickup.idle.ring")
        iconNode.removeAction(forKey: "pickup.idle.icon")

        haloNode.alpha = 1
        haloNode.setScale(1)
        chargeRingNode.alpha = 1
        chargeRingNode.setScale(1)
        ringNode.alpha = 1
        ringNode.setScale(1)
        iconNode.alpha = 0.94
        iconNode.setScale(1)

        haloNode.run(Self.breatheAction(scale: 1.035, lowAlpha: 0.24, duration: 0.82), withKey: "pickup.idle.halo")
        if chargeTier > .base {
            chargeRingNode.run(
                Self.breatheAction(scale: 1.045, lowAlpha: 0.42, duration: 0.72),
                withKey: "pickup.idle.charge"
            )
        }
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
        WeaponSpriteSheet.texture(for: kind, role: .icon)
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
