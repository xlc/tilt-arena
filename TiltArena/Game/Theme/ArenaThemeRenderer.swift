import SpriteKit

@MainActor
final class ArenaThemeRenderer {
    private let theme: ArenaTheme

    init(theme: ArenaTheme) {
        self.theme = theme
    }

    func makeArenaBackground(size: CGSize, arenaRect: CGRect? = nil) -> SKNode {
        let arenaRect = arenaRect ?? CGRect(origin: .zero, size: size)
        let root = SKNode()
        root.zPosition = -100

        root.addChild(makeBackdrop(size: size))
        root.addChild(makeGrid(in: arenaRect))
        root.addChild(makeRadarRings(in: arenaRect))
        root.addChild(makeBorder(in: arenaRect))

        return root
    }

    private func makeBackdrop(size: CGSize) -> SKNode {
        let node = SKShapeNode(rectOf: size)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.fillColor = theme.backgroundColor
        node.strokeColor = .clear
        return node
    }

    private func makeGrid(in rect: CGRect) -> SKNode {
        let path = CGMutablePath()
        let spacing: CGFloat = 48

        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }

        let node = SKShapeNode(path: path)
        node.strokeColor = theme.gridColor
        node.lineWidth = 0.6
        node.lineCap = .square
        return node
    }

    private func makeRadarRings(in rect: CGRect) -> SKNode {
        let root = SKNode()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) * 0.48

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

    private func makeBorder(in arenaRect: CGRect) -> SKNode {
        let inset: CGFloat = 14
        let rect = CGRect(
            x: arenaRect.minX + inset,
            y: arenaRect.minY + inset,
            width: max(0, arenaRect.width - inset * 2),
            height: max(0, arenaRect.height - inset * 2)
        )

        let border = SKShapeNode(rect: rect, cornerRadius: 6)
        border.strokeColor = theme.borderColor
        border.lineWidth = 1.5
        border.fillColor = .clear

        return border
    }
}
