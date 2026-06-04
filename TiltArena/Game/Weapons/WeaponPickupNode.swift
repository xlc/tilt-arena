import SpriteKit

@MainActor
final class WeaponPickupNode: SKNode {
    private let haloNode: SKShapeNode
    private let chargeRingNode: SKShapeNode
    private let overchargeRingNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let badgeNode: SKShapeNode
    private let chargeTickContainer: SKNode
    private let iconNode: SKSpriteNode
    private var theme: ArenaTheme

    init(pickup: WeaponPickup, theme: ArenaTheme) {
        haloNode = SKShapeNode()
        chargeRingNode = SKShapeNode()
        overchargeRingNode = SKShapeNode()
        ringNode = SKShapeNode()
        badgeNode = SKShapeNode()
        chargeTickContainer = SKNode()
        iconNode = SKSpriteNode()
        self.theme = theme
        super.init()

        zPosition = 14

        addChild(haloNode)
        addChild(chargeRingNode)
        addChild(overchargeRingNode)
        addChild(ringNode)
        addChild(badgeNode)
        addChild(chargeTickContainer)
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
        haloNode.strokeColor = color.withAlphaComponent(0.1 + chargeLevel * 0.04)
        haloNode.lineWidth = 2
        haloNode.fillColor = .clear
        haloNode.glowWidth = 0.8 + chargeLevel * 0.25

        chargeRingNode.path = Self.circlePath(radius: radius * (1.44 + chargeLevel * 0.1))
        chargeRingNode.strokeColor = color.withAlphaComponent(0.3 + chargeLevel * 0.11)
        chargeRingNode.lineWidth = 1 + chargeLevel * 0.42
        chargeRingNode.fillColor = .clear
        chargeRingNode.glowWidth = 0.75 + chargeLevel * 0.38

        overchargeRingNode.path = Self.circlePath(radius: radius * 1.78)
        overchargeRingNode.strokeColor = theme.playerColor.withAlphaComponent(0.64)
        overchargeRingNode.lineWidth = 1
        overchargeRingNode.fillColor = .clear
        overchargeRingNode.glowWidth = 1.15

        ringNode.path = Self.circlePath(radius: radius * 1.16)
        ringNode.strokeColor = color.withAlphaComponent(0.46 + chargeLevel * 0.1)
        ringNode.lineWidth = 1.2 + chargeLevel * 0.2
        ringNode.fillColor = .clear
        ringNode.glowWidth = 0.35 + chargeLevel * 0.18

        badgeNode.path = Self.circlePath(radius: radius * 0.94)
        badgeNode.fillColor = color.withAlphaComponent(0.08 + chargeLevel * 0.04)
        badgeNode.strokeColor = theme.playerColor.withAlphaComponent(0.38 + chargeLevel * 0.1)
        badgeNode.lineWidth = 0.9 + chargeLevel * 0.12
        badgeNode.glowWidth = 0.2 + chargeLevel * 0.2

        iconNode.texture = Self.iconTexture(for: pickup.kind)
        iconNode.size = CGSize(width: radius * 2.12, height: radius * 2.12)
        iconNode.alpha = 0.94
        iconNode.colorBlendFactor = 0
        iconNode.blendMode = .alpha

        applyChargeAppearance(for: pickup)
    }

    private func applyChargeAppearance(for pickup: WeaponPickup) {
        chargeRingNode.isHidden = pickup.chargeTier == .base
        overchargeRingNode.isHidden = pickup.chargeTier != .overcharged
        chargeTickContainer.isHidden = pickup.chargeTier == .base
        chargeTickContainer.removeAllChildren()
        chargeTickContainer.zRotation = 0

        guard pickup.chargeTier > .base else {
            return
        }

        let color = Self.color(for: pickup.kind, theme: theme)
        let tickCount = pickup.chargeTier == .overcharged ? 10 : 6
        let innerRadius = pickup.radius * (1.28 + CGFloat(pickup.chargeTier.rawValue) * 0.08)
        let outerRadius = pickup.radius * (1.48 + CGFloat(pickup.chargeTier.rawValue) * 0.11)

        for index in 0..<tickCount {
            let angle = CGFloat(index) * (2 * .pi / CGFloat(tickCount))
            let tick = SKShapeNode(path: Self.chargeTickPath(
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                angle: angle
            ))
            tick.strokeColor = pickup.chargeTier == .overcharged && index.isMultiple(of: 2)
                ? theme.playerColor.withAlphaComponent(0.72)
                : color.withAlphaComponent(pickup.chargeTier == .overcharged ? 0.76 : 0.58)
            tick.lineWidth = pickup.chargeTier == .overcharged ? 1.15 : 0.9
            tick.lineCap = .round
            tick.glowWidth = pickup.chargeTier == .overcharged ? 0.75 : 0.45
            chargeTickContainer.addChild(tick)
        }
    }

    private func startIdleAnimation(for chargeTier: WeaponPickupChargeTier) {
        haloNode.removeAction(forKey: "pickup.idle.halo")
        chargeRingNode.removeAction(forKey: "pickup.idle.charge")
        overchargeRingNode.removeAction(forKey: "pickup.idle.overcharge")
        chargeTickContainer.removeAction(forKey: "pickup.idle.ticks.spin")
        chargeTickContainer.removeAction(forKey: "pickup.idle.ticks.pulse")
        ringNode.removeAction(forKey: "pickup.idle.ring")
        iconNode.removeAction(forKey: "pickup.idle.icon")

        haloNode.alpha = 1
        haloNode.setScale(1)
        chargeRingNode.alpha = 1
        chargeRingNode.setScale(1)
        overchargeRingNode.alpha = 1
        overchargeRingNode.setScale(1)
        chargeTickContainer.alpha = 1
        chargeTickContainer.setScale(1)
        chargeTickContainer.zRotation = 0
        ringNode.alpha = 1
        ringNode.setScale(1)
        iconNode.alpha = 0.94
        iconNode.setScale(1)

        haloNode.run(Self.breatheAction(scale: 1.035, lowAlpha: 0.24, duration: 0.82), withKey: "pickup.idle.halo")
        if chargeTier > .base {
            chargeRingNode.run(
                Self.breatheAction(
                    scale: chargeTier == .overcharged ? 1.065 : 1.045,
                    lowAlpha: chargeTier == .overcharged ? 0.5 : 0.42,
                    duration: 0.72
                ),
                withKey: "pickup.idle.charge"
            )
            chargeTickContainer.run(
                Self.scalePulseAction(scale: chargeTier == .overcharged ? 1.04 : 1.02, duration: 0.76),
                withKey: "pickup.idle.ticks.pulse"
            )
            chargeTickContainer.run(
                .repeatForever(.rotate(byAngle: .pi * 2, duration: chargeTier == .overcharged ? 2.2 : 3.4)),
                withKey: "pickup.idle.ticks.spin"
            )
        }
        if chargeTier == .overcharged {
            overchargeRingNode.run(
                Self.breatheAction(scale: 1.08, lowAlpha: 0.36, duration: 0.86),
                withKey: "pickup.idle.overcharge"
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

    private static func chargeTickPath(innerRadius: CGFloat, outerRadius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius))
        path.addLine(to: CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius))
        return path
    }
}
