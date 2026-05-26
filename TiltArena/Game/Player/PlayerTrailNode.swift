import SpriteKit

@MainActor
final class PlayerTrailNode: SKNode {
    private var points: [CGPoint] = []
    private var segmentNodes: [PlayerTrailSegmentNode] = []
    private var theme: ArenaTheme
    private let maximumPoints = 22

    init(theme: ArenaTheme) {
        self.theme = theme
        super.init()

        zPosition = 8
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerTrailNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        self.theme = theme
        segmentNodes.forEach { $0.applyTheme(theme) }
    }

    func reset(to position: CGPoint) {
        points = [position]
        segmentNodes.forEach { $0.removeFromParent() }
        segmentNodes.removeAll()
    }

    func record(position: CGPoint, speedFraction: CGFloat) {
        if let lastPoint = points.last, hypot(position.x - lastPoint.x, position.y - lastPoint.y) < 1 {
            return
        }

        points.append(position)

        if points.count > maximumPoints {
            points.removeFirst(points.count - maximumPoints)
        }

        let clampedSpeed = min(1, max(0, speedFraction))
        rebuildSegments(speedFraction: clampedSpeed)
    }

    private func rebuildSegments(speedFraction: CGFloat) {
        let segmentCount = max(0, points.count - 1)

        while segmentNodes.count < segmentCount {
            let segmentNode = PlayerTrailSegmentNode(theme: theme)
            segmentNodes.append(segmentNode)
            addChild(segmentNode)
        }

        while segmentNodes.count > segmentCount {
            segmentNodes.removeLast().removeFromParent()
        }

        guard segmentCount > 0 else {
            return
        }

        for index in 0..<segmentCount {
            let ageFraction = CGFloat(index + 1) / CGFloat(segmentCount)
            segmentNodes[index].apply(
                from: points[index],
                to: points[index + 1],
                ageFraction: ageFraction,
                speedFraction: speedFraction
            )
        }
    }
}

@MainActor
private final class PlayerTrailSegmentNode: SKNode {
    private let glowNode = SKShapeNode()
    private let coreNode = SKShapeNode()

    init(theme: ArenaTheme) {
        super.init()

        addChild(glowNode)
        addChild(coreNode)
        applyTheme(theme)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerTrailSegmentNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.25)
        glowNode.fillColor = .clear
        glowNode.lineCap = .round
        glowNode.lineJoin = .round
        glowNode.glowWidth = 5

        coreNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.78)
        coreNode.fillColor = .clear
        coreNode.lineCap = .round
        coreNode.lineJoin = .round
        coreNode.glowWidth = 2
    }

    func apply(from start: CGPoint, to end: CGPoint, ageFraction: CGFloat, speedFraction: CGFloat) {
        let clampedAge = min(1, max(0, ageFraction))
        let clampedSpeed = min(1, max(0, speedFraction))
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let widthFraction = 0.38 + clampedAge * 0.62
        glowNode.path = path
        glowNode.lineWidth = (5 + clampedSpeed * 4) * widthFraction
        glowNode.alpha = 0.16 + clampedAge * 0.58

        coreNode.path = path
        coreNode.lineWidth = (2 + clampedSpeed * 2.5) * widthFraction
        coreNode.alpha = 0.12 + clampedAge * 0.72
    }
}
