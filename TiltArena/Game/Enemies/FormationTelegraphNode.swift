import SpriteKit

@MainActor
final class FormationTelegraphNode: SKNode {
    init(telegraph: FormationTelegraph, theme: ArenaTheme) {
        super.init()

        zPosition = 14

        let path = CGMutablePath()
        for segment in telegraph.segments {
            appendDashes(from: segment.start, to: segment.end, to: path)
        }

        let lineNode = SKShapeNode(path: path)
        lineNode.strokeColor = theme.enemyColor.withAlphaComponent(0.58)
        lineNode.lineWidth = 2
        lineNode.glowWidth = 2
        addChild(lineNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FormationTelegraphNode does not support storyboard initialization.")
    }

    private func appendDashes(from start: CGPoint, to end: CGPoint, to path: CGMutablePath) {
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
