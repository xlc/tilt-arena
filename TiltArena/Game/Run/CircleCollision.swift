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

    func firstIntersectionTimeDuringMovement(
        from previousCenter: CGPoint,
        with other: CollisionCircle,
        movingFrom otherPreviousCenter: CGPoint
    ) -> CGFloat? {
        let relativeStartX = previousCenter.x - otherPreviousCenter.x
        let relativeStartY = previousCenter.y - otherPreviousCenter.y
        let relativeMovementX = (center.x - previousCenter.x) - (other.center.x - otherPreviousCenter.x)
        let relativeMovementY = (center.y - previousCenter.y) - (other.center.y - otherPreviousCenter.y)
        let radiusSum = radius + other.radius
        let radiusSumSquared = radiusSum * radiusSum
        let startDistanceSquared = relativeStartX * relativeStartX + relativeStartY * relativeStartY

        if startDistanceSquared <= radiusSumSquared {
            return 0
        }

        let relativeMovementSquared = relativeMovementX * relativeMovementX
            + relativeMovementY * relativeMovementY
        guard relativeMovementSquared > 0 else {
            return nil
        }

        let linearCoefficient = 2 * (
            relativeStartX * relativeMovementX
                + relativeStartY * relativeMovementY
        )
        let constant = startDistanceSquared - radiusSumSquared
        let discriminant = linearCoefficient * linearCoefficient
            - 4 * relativeMovementSquared * constant

        guard discriminant >= 0 else {
            return nil
        }

        let firstIntersection = (
            -linearCoefficient - sqrt(discriminant)
        ) / (2 * relativeMovementSquared)
        guard firstIntersection >= 0, firstIntersection <= 1 else {
            return nil
        }

        return firstIntersection
    }
}
