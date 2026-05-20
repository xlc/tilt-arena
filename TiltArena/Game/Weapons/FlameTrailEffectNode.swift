import SpriteKit

@MainActor
final class FlameTrailEffectNode: SKNode {
    private let theme: ArenaTheme
    private var segmentNodes: [Int: SKShapeNode] = [:]

    init(theme: ArenaTheme) {
        self.theme = theme
        super.init()
        zPosition = 12
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FlameTrailEffectNode does not support storyboard initialization.")
    }

    func apply(segments: [FlameTrailSegment]) {
        let activeIDs = Set(segments.map(\.id))

        for id in Array(segmentNodes.keys) where !activeIDs.contains(id) {
            segmentNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for segment in segments {
            let node = segmentNodes[segment.id] ?? makeSegmentNode(radius: segment.radius)
            segmentNodes[segment.id] = node

            if node.parent == nil {
                addChild(node)
            }

            node.position = segment.position
            node.alpha = 0.2 + 0.55 * segment.remainingFraction
            node.setScale(0.75 + 0.25 * segment.remainingFraction)
        }
    }

    func reset() {
        segmentNodes.removeAll()
        removeAllChildren()
    }

    private func makeSegmentNode(radius: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        let orangeFill = SKColor(red: 1.0, green: 0.46, blue: 0.12, alpha: 0.24)
        node.fillColor = orangeFill
        node.strokeColor = theme.pickupAmber.withAlphaComponent(0.9)
        node.lineWidth = 1.4
        node.glowWidth = 2
        return node
    }
}
