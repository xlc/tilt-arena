import SpriteKit

@MainActor
final class FlameTrailEffectNode: SKNode {
    private var theme: ArenaTheme
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

    func applyTheme(_ theme: ArenaTheme) {
        self.theme = theme
        for node in segmentNodes.values {
            applyAppearance(to: node)
        }
    }

    private func makeSegmentNode(radius: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        applyAppearance(to: node)
        return node
    }

    private func applyAppearance(to node: SKShapeNode) {
        node.fillColor = theme.flameTrailFillColor
        node.strokeColor = theme.pickupAmber.withAlphaComponent(0.9)
        node.lineWidth = 1.4
        node.glowWidth = 2
    }
}
