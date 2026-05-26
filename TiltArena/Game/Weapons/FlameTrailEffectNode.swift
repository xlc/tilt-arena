import SpriteKit

@MainActor
final class FlameTrailEffectNode: SKNode {
    private var theme: ArenaTheme
    private var segmentNodes: [Int: FlameTrailSegmentNode] = [:]

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
            node.apply(remainingFraction: segment.remainingFraction)
        }
    }

    func reset() {
        segmentNodes.removeAll()
        removeAllChildren()
    }

    func applyTheme(_ theme: ArenaTheme) {
        self.theme = theme
        for node in segmentNodes.values {
            node.applyTheme(theme)
        }
    }

    private func makeSegmentNode(radius: CGFloat) -> FlameTrailSegmentNode {
        FlameTrailSegmentNode(radius: radius, theme: theme)
    }
}

@MainActor
private final class FlameTrailSegmentNode: SKNode {
    private let radius: CGFloat
    private let glowNode: SKShapeNode
    private let coreNode: SKShapeNode
    private let spriteNode: SKSpriteNode
    private let emberNode: SKShapeNode

    init(radius: CGFloat, theme: ArenaTheme) {
        self.radius = radius
        glowNode = SKShapeNode(circleOfRadius: radius * 1.12)
        coreNode = SKShapeNode(circleOfRadius: radius)
        spriteNode = SKSpriteNode(texture: WeaponSpriteSheet.texture(for: .flameTrail, role: .effect))
        emberNode = SKShapeNode(circleOfRadius: radius * 0.18)
        super.init()

        addChild(glowNode)
        addChild(coreNode)
        addChild(spriteNode)
        addChild(emberNode)
        spriteNode.size = CGSize(width: radius * 2.75, height: radius * 2.75)
        spriteNode.blendMode = .alpha
        spriteNode.zPosition = 1
        emberNode.position = CGPoint(x: -radius * 0.28, y: radius * 0.26)
        applyTheme(theme)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FlameTrailSegmentNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.fillColor = theme.pickupAmber.withAlphaComponent(0.07)
        glowNode.strokeColor = theme.pickupAmber.withAlphaComponent(0.24)
        glowNode.lineWidth = 1.6
        glowNode.glowWidth = 1

        coreNode.fillColor = theme.flameTrailFillColor
        coreNode.strokeColor = theme.pickupAmber.withAlphaComponent(0.74)
        coreNode.lineWidth = 1.4
        coreNode.glowWidth = 0.65

        spriteNode.colorBlendFactor = 0

        emberNode.fillColor = theme.playerColor.withAlphaComponent(0.28)
        emberNode.strokeColor = .clear
        emberNode.glowWidth = 0.4
    }

    func apply(remainingFraction: CGFloat) {
        let fraction = min(1, max(0, remainingFraction))
        alpha = 0.14 + 0.56 * fraction
        setScale(0.72 + 0.34 * fraction)
        glowNode.alpha = 0.22 + 0.3 * fraction
        coreNode.alpha = 0.42 + 0.34 * fraction
        spriteNode.alpha = 0.16 + 0.38 * fraction
        spriteNode.zRotation = fraction * .pi * 0.2
        emberNode.alpha = 0.14 + 0.48 * fraction
        emberNode.position = CGPoint(x: -radius * (0.12 + 0.2 * fraction), y: radius * 0.28)
    }
}
