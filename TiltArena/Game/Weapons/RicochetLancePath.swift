import CoreGraphics
import Foundation

struct RicochetLanceSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
}

struct RicochetLanceResult: Equatable {
    let segments: [RicochetLanceSegment]
    let destroyedEnemyIDs: Set<Int>
}

enum RicochetLancePath {
    private static let epsilon: CGFloat = 0.000_1

    static func resolve(
        origin: CGPoint,
        direction: CGVector,
        playableRect: CGRect,
        enemies: [ArenaEnemy],
        configuration: StartingWeaponConfiguration = StartingWeaponConfiguration()
    ) -> RicochetLanceResult {
        let segments = segments(
            origin: origin,
            direction: direction,
            playableRect: playableRect,
            maximumBounces: configuration.ricochetLanceMaximumBounces
        )
        let beamRadius = configuration.ricochetLanceBeamWidth / 2
        let destroyedEnemyIDs = Set(
            enemies
                .filter { enemy in
                    segments.contains { segment in
                        intersects(
                            enemy: enemy,
                            segment: segment,
                            beamRadius: beamRadius
                        )
                    }
                }
                .map(\.id)
        )

        return RicochetLanceResult(
            segments: segments,
            destroyedEnemyIDs: destroyedEnemyIDs
        )
    }

    static func segments(
        origin: CGPoint,
        direction rawDirection: CGVector,
        playableRect: CGRect,
        maximumBounces: Int
    ) -> [RicochetLanceSegment] {
        guard playableRect.isFinite,
              playableRect.width > 0,
              playableRect.height > 0,
              origin.isFinite else {
            return []
        }

        var start = clamped(origin, to: playableRect)
        var direction = resolvedDirection(rawDirection)
        let maximumBounces = max(0, maximumBounces)
        var segments: [RicochetLanceSegment] = []

        for segmentIndex in 0...maximumBounces {
            direction = reflectedIfLeavingBounds(direction, from: start, in: playableRect)

            let hit = nextBoundaryHit(from: start, direction: direction, in: playableRect)
            guard hit.distance.isFinite, hit.distance > epsilon else {
                break
            }

            let end = CGPoint(
                x: start.x + direction.dx * hit.distance,
                y: start.y + direction.dy * hit.distance
            )

            if ArenaGeometry.squaredDistance(from: start, to: end) > epsilon * epsilon {
                segments.append(RicochetLanceSegment(start: start, end: end))
            }
            guard segmentIndex < maximumBounces else {
                break
            }

            start = end
            if hit.reflectX {
                direction.dx = -direction.dx
            }
            if hit.reflectY {
                direction.dy = -direction.dy
            }
            direction = resolvedDirection(direction)
        }

        return segments
    }

    private static func intersects(
        enemy: ArenaEnemy,
        segment: RicochetLanceSegment,
        beamRadius: CGFloat
    ) -> Bool {
        let radius = max(0, enemy.radius) + max(0, beamRadius)
        return distanceSquared(from: enemy.position, to: segment) <= radius * radius
    }

    private static func resolvedDirection(_ direction: CGVector) -> CGVector {
        direction.normalized(or: CGVector(dx: 0, dy: 1))
    }

    private static func clamped(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(rect.maxX, max(rect.minX, point.x)),
            y: min(rect.maxY, max(rect.minY, point.y))
        )
    }

    private static func reflectedIfLeavingBounds(
        _ direction: CGVector,
        from point: CGPoint,
        in rect: CGRect
    ) -> CGVector {
        var direction = direction
        if point.x <= rect.minX + epsilon, direction.dx < 0 {
            direction.dx = abs(direction.dx)
        } else if point.x >= rect.maxX - epsilon, direction.dx > 0 {
            direction.dx = -abs(direction.dx)
        }

        if point.y <= rect.minY + epsilon, direction.dy < 0 {
            direction.dy = abs(direction.dy)
        } else if point.y >= rect.maxY - epsilon, direction.dy > 0 {
            direction.dy = -abs(direction.dy)
        }

        return resolvedDirection(direction)
    }

    private static func nextBoundaryHit(
        from point: CGPoint,
        direction: CGVector,
        in rect: CGRect
    ) -> BoundaryHit {
        let distanceX = axisDistance(
            coordinate: point.x,
            velocity: direction.dx,
            minimum: rect.minX,
            maximum: rect.maxX
        )
        let distanceY = axisDistance(
            coordinate: point.y,
            velocity: direction.dy,
            minimum: rect.minY,
            maximum: rect.maxY
        )
        let distance = min(distanceX, distanceY)

        return BoundaryHit(
            distance: distance,
            reflectX: abs(distanceX - distance) <= epsilon,
            reflectY: abs(distanceY - distance) <= epsilon
        )
    }

    private static func axisDistance(
        coordinate: CGFloat,
        velocity: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        guard abs(velocity) > epsilon else {
            return .infinity
        }

        if velocity > 0 {
            return max(0, (maximum - coordinate) / velocity)
        }

        return max(0, (minimum - coordinate) / velocity)
    }

    private static func distanceSquared(from point: CGPoint, to segment: RicochetLanceSegment) -> CGFloat {
        guard point.isFinite, segment.start.isFinite, segment.end.isFinite else {
            return .infinity
        }
        let dx = segment.end.x - segment.start.x
        let dy = segment.end.y - segment.start.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return ArenaGeometry.squaredDistance(from: point, to: segment.start)
        }

        let rawProgress = (
            (point.x - segment.start.x) * dx
                + (point.y - segment.start.y) * dy
        ) / lengthSquared
        let progress = min(1, max(0, rawProgress))
        let closestPoint = CGPoint(
            x: segment.start.x + dx * progress,
            y: segment.start.y + dy * progress
        )

        return ArenaGeometry.squaredDistance(from: point, to: closestPoint)
    }

    private struct BoundaryHit {
        let distance: CGFloat
        let reflectX: Bool
        let reflectY: Bool
    }

}
