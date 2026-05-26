import SpriteKit

@MainActor
final class EnemyNode: SKNode {
    private let dangerHaloNode: SKShapeNode
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let markerNode: SKShapeNode
    private let highlightNode: SKShapeNode
    private var theme: ArenaTheme
    private var visualSignature: VisualSignature?

    init(enemy: ArenaEnemy, theme: ArenaTheme) {
        dangerHaloNode = SKShapeNode()
        bodyNode = SKShapeNode()
        ringNode = SKShapeNode()
        markerNode = SKShapeNode()
        highlightNode = SKShapeNode()
        self.theme = theme
        super.init()

        zPosition = 15

        dangerHaloNode.fillColor = .clear
        addChild(dangerHaloNode)

        ringNode.fillColor = .clear
        addChild(ringNode)

        addChild(bodyNode)
        addChild(highlightNode)
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
        dangerHaloNode.path = Self.circlePath(radius: enemy.radius * 1.24)
        bodyNode.path = Self.bodyPath(for: enemy, radius: enemy.radius)
        ringNode.path = Self.circlePath(radius: enemy.radius * 1.45)
        highlightNode.path = Self.circlePath(radius: enemy.radius * 0.22)
        highlightNode.position = CGPoint(x: -enemy.radius * 0.24, y: enemy.radius * 0.28)

        if let markerPath = Self.markerPath(for: enemy, radius: enemy.radius) {
            markerNode.path = markerPath
            markerNode.isHidden = false
        } else {
            markerNode.path = nil
            markerNode.isHidden = true
        }
        markerNode.fillColor = .clear
        highlightNode.strokeColor = .clear
        resetThawAnimation()
        applyBaseStyle()
        applyRoleStyle(enemy)

        if enemy.isFrozen {
            applyFrozenStyle()
        } else if enemy.isThawing {
            applyThawingStyle()
            startThawAnimation()
        }

        let isNormalChaser = !enemy.isMineDot && !enemy.isHunterDot && !enemy.isPaddleTrap && !enemy.isShatterableFrozen
        dangerHaloNode.isHidden = isNormalChaser
        ringNode.isHidden = isNormalChaser
        highlightNode.isHidden = isNormalChaser

        if isNormalChaser {
            bodyNode.strokeColor = theme.enemyColor.withAlphaComponent(0.52)
            bodyNode.lineWidth = 0.8
            bodyNode.glowWidth = 0
        }
    }

    func applyBaseStyle() {
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.58)
        dangerHaloNode.lineWidth = 2
        dangerHaloNode.glowWidth = 0.6
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        markerNode.lineWidth = 1.8
        markerNode.lineCap = .round
        markerNode.lineJoin = .round
        markerNode.glowWidth = 0.45
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.42)
        ringNode.lineWidth = 1.1
        ringNode.glowWidth = 0.45
        bodyNode.fillColor = theme.enemyColor
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        bodyNode.lineWidth = 1.5
        bodyNode.glowWidth = 0.7
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.24)
        highlightNode.isHidden = false
        highlightNode.alpha = 1
    }

    func applyRoleStyle(_ enemy: ArenaEnemy) {
        if enemy.isMineDot {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.78)
            ringNode.lineWidth = 1.8
            ringNode.glowWidth = 0.55
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.48)
            bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
            bodyNode.glowWidth = 0.5
        } else if enemy.isHunterDot {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.76)
            ringNode.lineWidth = 1.7
            ringNode.glowWidth = 0.55
            bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.84)
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.88)
        } else if enemy.isPaddleTrap {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.62)
            ringNode.lineWidth = 1.5
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.82)
            bodyNode.glowWidth = 0.55
        }
    }

    func applyFrozenStyle() {
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.62)
        dangerHaloNode.lineWidth = 1.9
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.72)
        ringNode.lineWidth = 1.8
        ringNode.glowWidth = 0.9
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.55)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        bodyNode.lineWidth = 1.7
        bodyNode.glowWidth = 1
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.36)
    }

    func applyThawingStyle() {
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.42)
        dangerHaloNode.lineWidth = 1.7
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.44)
        ringNode.lineWidth = 1.4
        ringNode.glowWidth = 0.65
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.28)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.58)
        bodyNode.lineWidth = 1.5
        bodyNode.glowWidth = 0.7
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.62)
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.2)
    }

    func resetThawAnimation() {
        dangerHaloNode.removeAction(forKey: "enemy.thaw.halo")
        bodyNode.removeAction(forKey: "enemy.thaw.body")
        ringNode.removeAction(forKey: "enemy.thaw.ring")
        markerNode.removeAction(forKey: "enemy.thaw.marker")
        highlightNode.removeAction(forKey: "enemy.thaw.highlight")
        dangerHaloNode.alpha = 1
        bodyNode.alpha = 1
        ringNode.alpha = 1
        markerNode.alpha = 1
        highlightNode.alpha = 1
        dangerHaloNode.setScale(1)
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
        let haloPulse = SKAction.repeatForever(.sequence([
            .group([
                .scale(to: 1.12, duration: 0.11),
                .fadeAlpha(to: 0.42, duration: 0.11)
            ]),
            .group([
                .scale(to: 1, duration: 0.11),
                .fadeAlpha(to: 0.86, duration: 0.11)
            ])
        ]))
        let highlightPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.08),
            .fadeAlpha(to: 0.58, duration: 0.08)
        ]))

        dangerHaloNode.run(haloPulse, withKey: "enemy.thaw.halo")
        bodyNode.run(bodyPulse, withKey: "enemy.thaw.body")
        ringNode.run(ringPulse, withKey: "enemy.thaw.ring")
        markerNode.run(markerPulse, withKey: "enemy.thaw.marker")
        highlightNode.run(highlightPulse, withKey: "enemy.thaw.highlight")
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
