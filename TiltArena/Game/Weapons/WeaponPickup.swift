import CoreGraphics

struct WeaponPickup: Equatable, Identifiable {
    let id: Int
    let kind: WeaponKind
    let position: CGPoint
    let radius: CGFloat

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }
}
