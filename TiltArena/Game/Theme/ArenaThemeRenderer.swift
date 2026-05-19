import SpriteKit

@MainActor
final class ArenaThemeRenderer {
    private let theme: ArenaTheme

    init(theme: ArenaTheme) {
        self.theme = theme
    }

    func makeArenaBackground(size: CGSize) -> SKNode {
        let root = SKNode()
        root.zPosition = -100

        root.addChild(makeBackdrop(size: size))
        root.addChild(makeGrid(size: size))
        root.addChild(makeRadarRings(size: size))
        root.addChild(makeBorder(size: size))

        return root
    }

    private func makeBackdrop(size: CGSize) -> SKNode {
        let node = SKShapeNode(rectOf: size)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.fillColor = theme.backgroundColor
        node.strokeColor = .clear
        return node
    }

    private func makeGrid(size: CGSize) -> SKNode {
        let path = CGMutablePath()
        let spacing: CGFloat = 48

        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        let node = SKShapeNode(path: path)
        node.strokeColor = theme.gridColor
        node.lineWidth = 0.6
        node.lineCap = .square
        return node
    }

    private func makeRadarRings(size: CGSize) -> SKNode {
        let root = SKNode()
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) * 0.48

        for index in 1...4 {
            let radius = maxRadius * CGFloat(index) / 4
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.position = center
            ring.strokeColor = theme.gridColor.withAlphaComponent(0.55)
            ring.lineWidth = 0.8
            ring.fillColor = .clear
            root.addChild(ring)
        }

        return root
    }

    private func makeBorder(size: CGSize) -> SKNode {
        let inset: CGFloat = 14
        let rect = CGRect(
            x: inset,
            y: inset,
            width: max(0, size.width - inset * 2),
            height: max(0, size.height - inset * 2)
        )

        let border = SKShapeNode(rect: rect, cornerRadius: 6)
        border.strokeColor = theme.borderColor
        border.lineWidth = 1.5
        border.fillColor = .clear

        return border
    }
}
