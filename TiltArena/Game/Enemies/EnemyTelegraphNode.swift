import SpriteKit

@MainActor
final class EnemyTelegraphNode: SKNode {
    private static let maximumDashCountPerSegment = 256
    private let glowNode: SKShapeNode
    private let lineNode: SKShapeNode
    private let openingNode: SKShapeNode

    init(telegraph: EnemyTelegraph, theme: ArenaTheme) {
        let path = CGMutablePath()
        for segment in telegraph.segments {
            Self.appendDashes(from: segment.start, to: segment.end, to: path)
        }
        for body in telegraph.bodies where body.center.isFinite && body.radius.isFinite && body.radius > 0 {
            path.addEllipse(in: CGRect(
                x: body.center.x - body.radius, y: body.center.y - body.radius,
                width: body.radius * 2, height: body.radius * 2
            ))
        }
        glowNode = SKShapeNode(path: path)
        lineNode = SKShapeNode(path: path)
        let openingPath = CGMutablePath()
        if let opening = telegraph.opening {
            openingPath.move(to: opening.start)
            openingPath.addLine(to: opening.end)
        }
        openingNode = SKShapeNode(path: openingPath)

        super.init()

        zPosition = 9
        applyTheme(theme)
        addChild(glowNode)
        addChild(lineNode)
        addChild(openingNode)
        startWarningPulse()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyTelegraphNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.strokeColor = theme.enemyColor.withAlphaComponent(0.12)
        glowNode.lineWidth = 4.8
        glowNode.glowWidth = 0.85
        glowNode.lineCap = .round

        lineNode.strokeColor = theme.enemyColor.withAlphaComponent(0.58)
        lineNode.lineWidth = 1.9
        lineNode.glowWidth = 0.42
        lineNode.lineCap = .round
        lineNode.fillColor = .clear
        glowNode.fillColor = .clear
        openingNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.7)
        openingNode.lineWidth = 2
        openingNode.lineCap = .round
    }

    private func startWarningPulse() {
        glowNode.removeAction(forKey: "telegraph.warning.glow")
        lineNode.removeAction(forKey: "telegraph.warning.line")
        glowNode.alpha = 1
        lineNode.alpha = 1
        glowNode.setScale(1)

        // The dashed telegraph path is in scene coordinates, so keep the glow
        // pulse opacity-only. Scaling it would drift the warning away from the
        // actual hazard lane for paths far from the scene origin.
        glowNode.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.32, duration: 0.16),
            .fadeAlpha(to: 0.68, duration: 0.14)
        ])), withKey: "telegraph.warning.glow")

        lineNode.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.48, duration: 0.1),
            .fadeAlpha(to: 0.76, duration: 0.1),
            .wait(forDuration: 0.1)
        ])), withKey: "telegraph.warning.line")
    }

    private static func appendDashes(from start: CGPoint, to end: CGPoint, to path: CGMutablePath) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)

        guard length.isFinite, length > 0 else {
            return
        }

        let dashLength: CGFloat = 14
        let gapLength: CGFloat = 9
        let stepLength = dashLength + gapLength
        let unitX = dx / length
        let unitY = dy / length
        var offset: CGFloat = 0
        var dashCount = 0

        while offset < length, dashCount < maximumDashCountPerSegment {
            let dashEndOffset = min(length, offset + dashLength)
            path.move(to: CGPoint(x: start.x + unitX * offset, y: start.y + unitY * offset))
            path.addLine(to: CGPoint(x: start.x + unitX * dashEndOffset, y: start.y + unitY * dashEndOffset))
            offset += stepLength
            dashCount += 1
        }
    }
}
