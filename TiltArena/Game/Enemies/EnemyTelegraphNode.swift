import SpriteKit

@MainActor
final class EnemyTelegraphNode: SKNode {
    private let glowNode: SKShapeNode
    private let lineNode: SKShapeNode

    init(telegraph: EnemyTelegraph, theme: ArenaTheme) {
        let path = CGMutablePath()
        for segment in telegraph.segments {
            Self.appendDashes(from: segment.start, to: segment.end, to: path)
        }
        glowNode = SKShapeNode(path: path)
        lineNode = SKShapeNode(path: path)

        super.init()

        zPosition = 14
        applyTheme(theme)
        addChild(glowNode)
        addChild(lineNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyTelegraphNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.strokeColor = theme.enemyColor.withAlphaComponent(0.3)
        glowNode.lineWidth = 7
        glowNode.glowWidth = 5
        glowNode.lineCap = .round

        lineNode.strokeColor = theme.enemyColor.withAlphaComponent(0.84)
        lineNode.lineWidth = 2.8
        lineNode.glowWidth = 2.8
        lineNode.lineCap = .round
    }

    private static func appendDashes(from start: CGPoint, to end: CGPoint, to path: CGMutablePath) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)

        guard length > 0 else {
            return
        }

        let dashLength: CGFloat = 14
        let gapLength: CGFloat = 9
        let stepLength = dashLength + gapLength
        let unitX = dx / length
        let unitY = dy / length
        var offset: CGFloat = 0

        while offset < length {
            let dashEndOffset = min(length, offset + dashLength)
            path.move(to: CGPoint(x: start.x + unitX * offset, y: start.y + unitY * offset))
            path.addLine(to: CGPoint(x: start.x + unitX * dashEndOffset, y: start.y + unitY * dashEndOffset))
            offset += stepLength
        }
    }
}
