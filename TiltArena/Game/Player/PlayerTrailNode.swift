import SpriteKit

@MainActor
final class PlayerTrailNode: SKNode {
    private let glowNode = SKShapeNode()
    private let coreNode = SKShapeNode()
    private var points: [CGPoint] = []
    private let maximumPoints = 22

    init(theme: ArenaTheme) {
        super.init()

        zPosition = 8
        addChild(glowNode)
        addChild(coreNode)
        applyTheme(theme)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerTrailNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        glowNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.25)
        glowNode.fillColor = .clear
        glowNode.lineCap = .round
        glowNode.lineJoin = .round
        glowNode.lineWidth = 7
        glowNode.glowWidth = 5

        coreNode.strokeColor = theme.playerAccentColor.withAlphaComponent(0.78)
        coreNode.fillColor = .clear
        coreNode.lineCap = .round
        coreNode.lineJoin = .round
        coreNode.lineWidth = 3
        coreNode.glowWidth = 2
    }

    func reset(to position: CGPoint) {
        points = [position]
        glowNode.path = nil
        coreNode.path = nil
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
        glowNode.lineWidth = 5 + clampedSpeed * 4
        coreNode.lineWidth = 2 + clampedSpeed * 2.5
        let trailPath = makePath()
        glowNode.path = trailPath
        coreNode.path = trailPath
    }

    private func makePath() -> CGPath? {
        guard let firstPoint = points.first, points.count > 1 else {
            return nil
        }

        let path = CGMutablePath()
        path.move(to: firstPoint)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }
}
