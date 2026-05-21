import SpriteKit

@MainActor
final class PlayerTrailNode: SKShapeNode {
    private var points: [CGPoint] = []
    private let maximumPoints = 18

    init(theme: ArenaTheme) {
        super.init()

        zPosition = 8
        applyTheme(theme)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlayerTrailNode does not support storyboard initialization.")
    }

    func applyTheme(_ theme: ArenaTheme) {
        strokeColor = theme.playerAccentColor.withAlphaComponent(0.65)
        fillColor = .clear
        lineCap = .round
        lineJoin = .round
        lineWidth = 3
        glowWidth = 2
    }

    func reset(to position: CGPoint) {
        points = [position]
        path = nil
    }

    func record(position: CGPoint, speedFraction: CGFloat) {
        if let lastPoint = points.last, hypot(position.x - lastPoint.x, position.y - lastPoint.y) < 1 {
            return
        }

        points.append(position)

        if points.count > maximumPoints {
            points.removeFirst(points.count - maximumPoints)
        }

        lineWidth = 2 + min(1, max(0, speedFraction)) * 2
        path = makePath()
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
