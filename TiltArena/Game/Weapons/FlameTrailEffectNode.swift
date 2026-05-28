import SpriteKit

@MainActor
final class FlameTrailEffectNode: SKNode {
    private let glowNode = SKShapeNode()
    private let bodyNode = SKShapeNode()
    private let coreNode = SKShapeNode()
    private let headSpriteNode = SKSpriteNode(texture: WeaponSpriteSheet.texture(for: .flameTrail, role: .effect))

    init(theme: ArenaTheme) {
        super.init()
        zPosition = 12
        [glowNode, bodyNode, coreNode, headSpriteNode].forEach(addChild)
        configureStrokeNode(glowNode)
        configureStrokeNode(bodyNode)
        configureStrokeNode(coreNode)
        glowNode.zPosition = 0
        bodyNode.zPosition = 1
        coreNode.zPosition = 2
        headSpriteNode.blendMode = .alpha
        headSpriteNode.zPosition = 3
        applyTheme(theme)
        clearTrail()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FlameTrailEffectNode does not support storyboard initialization.")
    }

    func apply(segments: [FlameTrailSegment]) {
        guard let newestSegment = segments.last else {
            clearTrail()
            return
        }

        let radius = max(1, segments.map(\.radius).max() ?? newestSegment.radius)
        let path = Self.trailPath(for: segments, radius: radius)
        let fraction = max(newestSegment.remainingFraction, Self.averageRemainingFraction(for: segments))

        glowNode.path = path
        bodyNode.path = path
        coreNode.path = path

        glowNode.lineWidth = radius * 2.7
        bodyNode.lineWidth = radius * 1.95
        coreNode.lineWidth = max(1, radius * 0.62)

        alpha = 0.2 + 0.58 * fraction
        glowNode.alpha = 0.28 + 0.32 * fraction
        bodyNode.alpha = 0.56 + 0.3 * fraction
        coreNode.alpha = 0.3 + 0.34 * fraction

        headSpriteNode.isHidden = false
        headSpriteNode.position = newestSegment.position
        headSpriteNode.size = CGSize(width: radius * 2.55, height: radius * 2.55)
        headSpriteNode.alpha = 0.18 + 0.38 * newestSegment.remainingFraction
        headSpriteNode.zRotation = Self.headingAngle(for: segments) - .pi / 2
    }

    func reset() {
        removeAllActions()
        clearTrail()
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.strokeColor = theme.pickupAmber.withAlphaComponent(0.22)
        glowNode.glowWidth = 1.35

        bodyNode.strokeColor = theme.flameTrailFillColor.withAlphaComponent(0.9)
        bodyNode.glowWidth = 0.85

        coreNode.strokeColor = theme.playerColor.withAlphaComponent(0.5)
        coreNode.glowWidth = 0.45

        headSpriteNode.colorBlendFactor = 0
    }

    private func clearTrail() {
        alpha = 0
        glowNode.path = nil
        bodyNode.path = nil
        coreNode.path = nil
        headSpriteNode.isHidden = true
    }

    private func configureStrokeNode(_ node: SKShapeNode) {
        node.fillColor = .clear
        node.lineCap = .round
        node.lineJoin = .round
    }

    private static func trailPath(for segments: [FlameTrailSegment], radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard let first = segments.first else {
            return path
        }

        if segments.count == 1 {
            let halfLength = max(1, radius * 0.35)
            path.move(to: CGPoint(x: first.position.x - halfLength, y: first.position.y))
            path.addLine(to: CGPoint(x: first.position.x + halfLength, y: first.position.y))
            return path
        }

        let points = segments.map(\.position)
        path.move(to: points[0])

        for index in 1..<points.count {
            let current = points[index]
            if index < points.count - 1 {
                let next = points[index + 1]
                path.addQuadCurve(to: CGPoint(
                    x: (current.x + next.x) / 2,
                    y: (current.y + next.y) / 2
                ), control: current)
            } else {
                path.addLine(to: current)
            }
        }

        return path
    }

    private static func averageRemainingFraction(for segments: [FlameTrailSegment]) -> CGFloat {
        guard !segments.isEmpty else {
            return 0
        }

        let total = segments.reduce(CGFloat(0)) { $0 + $1.remainingFraction }
        return min(1, max(0, total / CGFloat(segments.count)))
    }

    private static func headingAngle(for segments: [FlameTrailSegment]) -> CGFloat {
        guard segments.count >= 2 else {
            return .pi / 2
        }

        let previous = segments[segments.count - 2].position
        let current = segments[segments.count - 1].position
        return atan2(current.y - previous.y, current.x - previous.x)
    }
}
