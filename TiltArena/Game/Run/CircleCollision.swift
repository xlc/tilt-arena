import CoreGraphics

struct CollisionCircle: Equatable {
    var center: CGPoint
    var radius: CGFloat

    func intersects(_ other: CollisionCircle) -> Bool {
        let dx = center.x - other.center.x
        let dy = center.y - other.center.y
        let radiusSum = radius + other.radius

        return dx * dx + dy * dy <= radiusSum * radiusSum
    }
}
