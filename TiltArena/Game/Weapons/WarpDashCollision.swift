import CoreGraphics

enum WarpDashCollision {
    static func sweptTargets(
        from start: CGPoint,
        to end: CGPoint,
        playerRadius: CGFloat,
        enemies: [ArenaEnemy]
    ) -> Set<Int> {
        Set(
            enemies
                .filter { enemy in
                    segmentIntersectsCircle(
                        start: start,
                        end: end,
                        circle: CollisionCircle(
                            center: enemy.position,
                            radius: max(0, playerRadius) + enemy.radius
                        )
                    )
                }
                .map(\.id)
        )
    }

    static func contactTargets(
        playerPosition: CGPoint,
        playerRadius: CGFloat,
        enemies: [ArenaEnemy]
    ) -> Set<Int> {
        let playerCircle = CollisionCircle(center: playerPosition, radius: max(0, playerRadius))
        return Set(enemies.filter { playerCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private static func segmentIntersectsCircle(start: CGPoint, end: CGPoint, circle: CollisionCircle) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let segmentLengthSquared = dx * dx + dy * dy

        guard segmentLengthSquared > 0 else {
            return CollisionCircle(center: start, radius: 0).intersects(circle)
        }

        let rawProjection = ((circle.center.x - start.x) * dx + (circle.center.y - start.y) * dy)
            / segmentLengthSquared
        let projection = min(1, max(0, rawProjection))
        let closestPoint = CGPoint(
            x: start.x + dx * projection,
            y: start.y + dy * projection
        )
        let radius = max(0, circle.radius)
        return ArenaGeometry.squaredDistance(from: closestPoint, to: circle.center) <= radius * radius
    }
}
