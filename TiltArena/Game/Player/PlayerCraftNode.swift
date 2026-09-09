import SpriteKit

@MainActor
final class PlayerCraftNode: SKNode {
    private let comboArcNode = SKShapeNode()
    private let weaponPrimerArcNode = SKShapeNode()
    private let outlineNode: SKShapeNode
    private let bodyNode: SKShapeNode
    private let coreNode: SKShapeNode
    private let engineNode: SKShapeNode
    private let visualRadius: CGFloat
    private(set) var showsCollisionProtection = false

    init(theme: ArenaTheme, visualRadius: CGFloat) {
        outlineNode = SKShapeNode(path: Self.makeBodyPath(radius: visualRadius * 1.13))
        bodyNode = SKShapeNode(path: Self.makeBodyPath(radius: visualRadius))
        coreNode = SKShapeNode(circleOfRadius: visualRadius * 0.23)
        engineNode = SKShapeNode(ellipseOf: CGSize(width: visualRadius * 0.34, height: visualRadius * 0.2))
        self.visualRadius = visualRadius
        super.init()

        zPosition = 20
        bodyNode.zPosition = 0.1
        coreNode.zPosition = 0.2
        engineNode.zPosition = 0.3

        configureProgressArc(comboArcNode, lineWidth: 1.4, glowWidth: 0.8)
        configureProgressArc(weaponPrimerArcNode, lineWidth: 1.1, glowWidth: 0.6)
        applyTheme(theme)
        addChild(comboArcNode)
        addChild(weaponPrimerArcNode)
        addChild(outlineNode)
        addChild(bodyNode)
        addChild(coreNode)
        addChild(engineNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerCraftNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        comboArcNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.88)

        outlineNode.fillColor = .clear
        outlineNode.strokeColor = theme.backgroundColor.withAlphaComponent(0.88)
        outlineNode.lineWidth = 2.6
        outlineNode.lineJoin = .round
        outlineNode.glowWidth = 0.2

        bodyNode.fillColor = theme.playerColor
        bodyNode.strokeColor = theme.playerAccentColor
        bodyNode.lineWidth = 1.35
        bodyNode.lineJoin = .round
        bodyNode.glowWidth = theme.kind == .darkTacticalRadar ? 0.7 : 0

        coreNode.fillColor = theme.playerAccentColor
        coreNode.strokeColor = .clear
        coreNode.position = CGPoint(x: 0, y: -visualRadius * 0.03)
        coreNode.glowWidth = 0.3

        engineNode.fillColor = theme.playerAccentColor.withAlphaComponent(0.66)
        engineNode.strokeColor = .clear
        engineNode.position = CGPoint(x: 0, y: -visualRadius * 0.54)
        engineNode.glowWidth = 0.85
        updateProtectionSurface(theme)
    }

    func applyCollisionProtection(_ isProtected: Bool, theme: ArenaTheme) {
        guard showsCollisionProtection != isProtected else { return }
        showsCollisionProtection = isProtected
        updateProtectionSurface(theme)
    }

    private func updateProtectionSurface(_ theme: ArenaTheme) {
        // A hollow craft with a strong outline signals immunity without another ring
        // or a color-only distinction. Keep the core and motion accent visible.
        outlineNode.strokeColor = showsCollisionProtection
            ? theme.playerColor : theme.backgroundColor.withAlphaComponent(0.88)
        bodyNode.fillColor = showsCollisionProtection ? theme.backgroundColor : theme.playerColor
    }

    func applyComboEffect(
        comboProgress: CGFloat,
        comboMultiplier: Int,
        weaponPrimerProgress: CGFloat,
        weaponPrimerFamily: WeaponComboFamily?,
        theme: ArenaTheme,
        isPaused: Bool
    ) {
        updateProgressArc(
            comboArcNode,
            radius: visualRadius * 1.62,
            progress: comboProgress
        )
        comboArcNode.lineWidth = min(
            2.8,
            1.25 + CGFloat(max(1, comboMultiplier) - 1) * 0.3
        )
        comboArcNode.glowWidth = min(
            2.2,
            0.65 + CGFloat(max(1, comboMultiplier) - 1) * 0.28
        )

        updateProgressArc(
            weaponPrimerArcNode,
            radius: visualRadius * 2.04,
            progress: weaponPrimerProgress
        )
        if let weaponPrimerFamily {
            weaponPrimerArcNode.strokeColor = theme
                .weaponComboColor(for: weaponPrimerFamily)
                .withAlphaComponent(0.78)
        }

        let effectAlpha: CGFloat = isPaused ? 0.38 : 1
        comboArcNode.alpha = effectAlpha
        weaponPrimerArcNode.alpha = effectAlpha
    }

    func apply(state: PlayerMovementState, speedFraction rawSpeedFraction: CGFloat) {
        position = state.position
        let speedFraction = min(1, max(0, rawSpeedFraction))
        engineNode.alpha = 0.36 + speedFraction * 0.4
        engineNode.setScale(0.82 + speedFraction * 0.42)

        guard state.velocity.length > 2 else {
            return
        }

        zRotation = atan2(state.velocity.dy, state.velocity.dx) - (.pi / 2)
    }

    private func configureProgressArc(
        _ node: SKShapeNode,
        lineWidth: CGFloat,
        glowWidth: CGFloat
    ) {
        node.zPosition = -1
        node.fillColor = .clear
        node.lineCap = .round
        node.lineWidth = lineWidth
        node.glowWidth = glowWidth
        node.isHidden = true
    }

    private func updateProgressArc(
        _ node: SKShapeNode,
        radius: CGFloat,
        progress rawProgress: CGFloat
    ) {
        let progress = min(1, max(0, rawProgress))
        node.isHidden = progress == 0
        guard progress > 0 else {
            return
        }

        node.path = Self.makeProgressArc(radius: radius, progress: progress)
    }

    private static func makeProgressArc(radius: CGFloat, progress: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let startAngle = CGFloat.pi / 2
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: startAngle,
            endAngle: startAngle + 2 * .pi * progress,
            clockwise: false
        )
        return path
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
