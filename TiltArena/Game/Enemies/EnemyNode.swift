import SpriteKit

@MainActor
final class EnemyNode: SKNode {
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let markerNode: SKShapeNode
    private var theme: ArenaTheme
    private var visualSignature: VisualSignature?

    init(enemy: ArenaEnemy, theme: ArenaTheme) {
        bodyNode = SKShapeNode()
        ringNode = SKShapeNode()
        markerNode = SKShapeNode()
        self.theme = theme
        super.init()

        zPosition = 15

        ringNode.fillColor = .clear
        addChild(ringNode)

        addChild(bodyNode)
        addChild(markerNode)

        apply(enemy)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyNode does not support storyboard initialization.")
    }

    func apply(_ enemy: ArenaEnemy) {
        position = enemy.position
        let signature = VisualSignature(enemy: enemy)
        guard signature != visualSignature else {
            return
        }

        visualSignature = signature
        applyAppearance(enemy)
    }

    func applyTheme(_ theme: ArenaTheme, enemy: ArenaEnemy) {
        self.theme = theme
        visualSignature = nil
        apply(enemy)
    }
}

private extension EnemyNode {
    struct VisualSignature: Equatable {
        let role: VisualRole
        let isFrozen: Bool
        let isThawing: Bool
        let radius: CGFloat

        init(enemy: ArenaEnemy) {
            role = VisualRole(enemy: enemy)
            isFrozen = enemy.isFrozen
            isThawing = enemy.isThawing
            radius = enemy.radius
        }
    }

    enum VisualRole: Equatable {
        case chaser
        case mine
        case hunter
        case paddleTrap

        init(enemy: ArenaEnemy) {
            if enemy.isMineDot {
                self = .mine
            } else if enemy.isHunterDot {
                self = .hunter
            } else if enemy.isPaddleTrap {
                self = .paddleTrap
            } else {
                self = .chaser
            }
        }
    }
}

private extension EnemyNode {
    func applyAppearance(_ enemy: ArenaEnemy) {
        bodyNode.path = Self.bodyPath(for: enemy, radius: enemy.radius)
        ringNode.path = Self.circlePath(radius: enemy.radius * 1.45)

        if let markerPath = Self.markerPath(for: enemy, radius: enemy.radius) {
            markerNode.path = markerPath
            markerNode.isHidden = false
        } else {
            markerNode.path = nil
            markerNode.isHidden = true
        }
        markerNode.fillColor = .clear
        resetThawAnimation()
        applyBaseStyle()
        applyRoleStyle(enemy)

        if enemy.isFrozen {
            applyFrozenStyle()
        } else if enemy.isThawing {
            applyThawingStyle()
            startThawAnimation()
        }
    }

    func applyBaseStyle() {
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.9)
        markerNode.lineWidth = 1.5
        markerNode.lineCap = .round
        markerNode.lineJoin = .round
        markerNode.glowWidth = 1
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.55)
        ringNode.lineWidth = 1.1
        ringNode.glowWidth = 1
        bodyNode.fillColor = theme.enemyColor
        bodyNode.strokeColor = theme.enemyColor.withAlphaComponent(0.9)
        bodyNode.lineWidth = 1
        bodyNode.glowWidth = 3
    }

    func applyRoleStyle(_ enemy: ArenaEnemy) {
        if enemy.isMineDot {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.95)
            ringNode.lineWidth = 2
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.34)
            bodyNode.strokeColor = theme.enemyColor
            bodyNode.glowWidth = 1.5
        } else if enemy.isHunterDot {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.9)
            ringNode.lineWidth = 1.8
            ringNode.glowWidth = 2
            bodyNode.strokeColor = theme.enemyColor
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.88)
        } else if enemy.isPaddleTrap {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.7)
            ringNode.lineWidth = 1.5
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.78)
            bodyNode.glowWidth = 2
        }
    }

    func applyFrozenStyle() {
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.9)
        ringNode.lineWidth = 2
        ringNode.glowWidth = 3
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.55)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.95)
        bodyNode.glowWidth = 4
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.95)
    }

    func applyThawingStyle() {
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.58)
        ringNode.lineWidth = 1.7
        ringNode.glowWidth = 2.5
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.28)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        bodyNode.glowWidth = 3
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.75)
    }

    func resetThawAnimation() {
        bodyNode.removeAction(forKey: "enemy.thaw.body")
        ringNode.removeAction(forKey: "enemy.thaw.ring")
        markerNode.removeAction(forKey: "enemy.thaw.marker")
        bodyNode.alpha = 1
        ringNode.alpha = 1
        markerNode.alpha = 1
        ringNode.setScale(1)
    }

    func startThawAnimation() {
        let bodyPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.42, duration: 0.09),
            .fadeAlpha(to: 0.88, duration: 0.09)
        ]))
        let ringPulse = SKAction.repeatForever(.sequence([
            .group([
                .scale(to: 1.18, duration: 0.11),
                .fadeAlpha(to: 0.45, duration: 0.11)
            ]),
            .group([
                .scale(to: 1, duration: 0.11),
                .fadeAlpha(to: 0.9, duration: 0.11)
            ])
        ]))
        let markerPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.08),
            .fadeAlpha(to: 0.85, duration: 0.08)
        ]))

        bodyNode.run(bodyPulse, withKey: "enemy.thaw.body")
        ringNode.run(ringPulse, withKey: "enemy.thaw.ring")
        markerNode.run(markerPulse, withKey: "enemy.thaw.marker")
    }

    static func bodyPath(for enemy: ArenaEnemy, radius: CGFloat) -> CGPath {
        if enemy.isMineDot {
            return minePath(radius: radius)
        }

        if enemy.isHunterDot {
            return trianglePath(radius: radius)
        }

        if enemy.isPaddleTrap {
            return squarePath(radius: radius)
        }

        return circlePath(radius: radius)
    }

    static func markerPath(for enemy: ArenaEnemy, radius: CGFloat) -> CGPath? {
        if enemy.isShatterableFrozen {
            return snowflakePath(radius: radius)
        }

        if enemy.isMineDot {
            return mineMarkerPath(radius: radius)
        }

        if enemy.isHunterDot {
            return hunterMarkerPath(radius: radius)
        }

        if enemy.isPaddleTrap {
            return paddleMarkerPath(radius: radius)
        }

        return nil
    }

    static func circlePath(radius: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    static func trianglePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 1.05))
        path.addLine(to: CGPoint(x: -radius * 0.9, y: -radius * 0.72))
        path.addLine(to: CGPoint(x: radius * 0.9, y: -radius * 0.72))
        path.closeSubpath()
        return path
    }

    static func squarePath(radius: CGFloat) -> CGPath {
        let side = radius * 1.55
        return CGPath(
            rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
            transform: nil
        )
    }

    static func minePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 + .pi / 8
            let pointRadius = index.isMultiple(of: 2) ? radius * 1.08 : radius * 0.72
            let point = CGPoint(x: cos(angle) * pointRadius, y: sin(angle) * pointRadius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    static func hunterMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.36, y: -radius * 0.14))
        path.addLine(to: CGPoint(x: 0, y: radius * 0.42))
        path.addLine(to: CGPoint(x: radius * 0.36, y: -radius * 0.14))
        path.move(to: CGPoint(x: 0, y: radius * 0.42))
        path.addLine(to: CGPoint(x: 0, y: -radius * 0.48))
        return path
    }

    static func mineMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lineRadius = radius * 0.52
        path.move(to: CGPoint(x: -lineRadius, y: 0))
        path.addLine(to: CGPoint(x: lineRadius, y: 0))
        path.move(to: CGPoint(x: 0, y: -lineRadius))
        path.addLine(to: CGPoint(x: 0, y: lineRadius))
        return path
    }

    static func paddleMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let halfWidth = radius * 0.48
        for y in [-radius * 0.25, radius * 0.25] {
            path.move(to: CGPoint(x: -halfWidth, y: y))
            path.addLine(to: CGPoint(x: halfWidth, y: y))
        }
        return path
    }

    static func snowflakePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lineRadius = radius * 0.66
        for rawAngle in stride(from: 0.0, to: Double.pi, by: Double.pi / 3) {
            let angle = CGFloat(rawAngle)
            let dx = cos(angle) * lineRadius
            let dy = sin(angle) * lineRadius
            path.move(to: CGPoint(x: -dx, y: -dy))
            path.addLine(to: CGPoint(x: dx, y: dy))
        }
        return path
    }
}
