import CoreGraphics
import Foundation

struct ChaserEnemy: Equatable, Identifiable {
    let id: Int
    var position: CGPoint
    var radius: CGFloat
    var speed: CGFloat

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }

    mutating func advance(toward target: CGPoint, deltaTime: TimeInterval) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = hypot(dx, dy)

        guard distance > 0 else {
            return
        }

        let step = min(distance, speed * CGFloat(max(0, deltaTime)))
        position = CGPoint(
            x: position.x + (dx / distance) * step,
            y: position.y + (dy / distance) * step
        )
    }
}
