import SpriteKit

@MainActor
final class WeaponPickupNode: SKNode {
    private let rimNode = SKShapeNode()
    private let chargeNode = SKShapeNode()
    private let iconNode = SKSpriteNode()
    private var theme: ArenaTheme

    init(pickup: WeaponPickup, theme: ArenaTheme) {
        self.theme = theme
        super.init()
        zPosition = 14
        chargeNode.zPosition = 0.1
        iconNode.zPosition = 0.2
        addChild(rimNode)
        addChild(chargeNode)
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
        apply(pickup)
    }

    private func applyAppearance(for pickup: WeaponPickup) {
        let color = theme.weaponColor(for: pickup.kind)
        let radius = pickup.radius
        let isDark = theme.kind == .darkTacticalRadar
        rimNode.path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
        rimNode.strokeColor = color
        rimNode.fillColor = theme.backgroundColor
        rimNode.lineWidth = pickup.chargeTier == .overcharged ? 2.1 : 1.5
        rimNode.glowWidth = isDark ? 0.65 : 0

        iconNode.texture = WeaponSpriteSheet.texture(for: pickup.kind)
        iconNode.size = CGSize(width: radius * 2.45, height: radius * 2.45)
        iconNode.color = color
        iconNode.colorBlendFactor = 1
        iconNode.blendMode = .alpha

        chargeNode.path = Self.chargePath(radius: radius, tier: pickup.chargeTier)
        chargeNode.isHidden = pickup.chargeTier == .base
        chargeNode.fillColor = .clear
        chargeNode.strokeColor = pickup.chargeTier == .overcharged ? theme.playerColor : color
        chargeNode.lineWidth = 1.65
        chargeNode.lineCap = .round
        chargeNode.glowWidth = isDark ? 0.4 : 0
    }

    private func startIdleAnimation(for tier: WeaponPickupChargeTier) {
        rimNode.removeAllActions()
        chargeNode.removeAllActions()
        rimNode.alpha = 1
        chargeNode.alpha = 1
        chargeNode.zRotation = 0

        // Keep the glyph and collection boundary steady while the outer charge marks move.
        rimNode.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.76, duration: 0.85),
            .fadeAlpha(to: 1, duration: 0.85)
        ])))
        guard tier > .base else { return }
        chargeNode.run(.repeatForever(.rotate(
            byAngle: .pi * 2,
            duration: tier == .overcharged ? 4 : 6
        )))
    }

    private static func chargePath(radius: CGFloat, tier: WeaponPickupChargeTier) -> CGPath {
        let path = CGMutablePath()
        guard tier > .base else { return path }
        let count = tier == .overcharged ? 4 : 2
        let arcLength: CGFloat = tier == .overcharged ? .pi / 3 : .pi / 2
        for index in 0..<count {
            let start = CGFloat(index) * .pi * 2 / CGFloat(count)
            let arcRadius = radius * 1.3
            path.move(to: CGPoint(x: cos(start) * arcRadius, y: sin(start) * arcRadius))
            path.addArc(
                center: .zero, radius: arcRadius,
                startAngle: start, endAngle: start + arcLength, clockwise: false
            )
        }
        return path
    }
}
