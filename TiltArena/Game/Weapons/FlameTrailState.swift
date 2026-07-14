import CoreGraphics
import Foundation

struct FlameTrailConfiguration: Equatable {
    // Gameplay-impacting Flame Trail knobs. Distances are SpriteKit points and durations are seconds.
    // This weapon is separate from StartingWeaponConfiguration because it creates persistent segments
    // over time instead of resolving a one-shot target set.
    // How long the fixed-speed burst emits new trail segments after pickup.
    var duration: TimeInterval = 0.3
    // How long each placed segment remains dangerous.
    var segmentLifetime: TimeInterval = 3.0
    // Kill radius around each segment.
    var segmentRadius: CGFloat = 16
    // Minimum player movement before another segment is placed.
    var segmentSpacing: CGFloat = 14
    // Segment cap; old segments are dropped first when the cap is exceeded.
    var maxSegments: Int = 24
    // Invulnerability granted after the fixed-speed burst.
    var invulnerabilityDuration: TimeInterval = 0.5
    // Player fixed-speed multiplier while the trail is being generated.
    var speedMultiplier: CGFloat = 5
}

extension FlameTrailConfiguration {
    func applying(chargeTier: WeaponPickupChargeTier) -> FlameTrailConfiguration {
        guard chargeTier > .base else {
            return self
        }

        let level = CGFloat(chargeTier.rawValue)
        var configuration = self
        configuration.segmentLifetime *= 1 + level * 0.12
        configuration.segmentRadius *= 1 + level * 0.10
        configuration.maxSegments += chargeTier.rawValue * 6
        return configuration
    }
}

struct FlameTrailSegment: Equatable, Identifiable {
    let id: Int
    let position: CGPoint
    let radius: CGFloat
    var timeRemaining: TimeInterval
    let lifetime: TimeInterval

    var remainingFraction: CGFloat {
        guard lifetime > 0 else {
            return 0
        }
        return CGFloat(max(0, min(1, timeRemaining / lifetime)))
    }

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }
}

struct FlameTrailFrame: Equatable {
    var burnedEnemyIDs: Set<Int> = []
    var segments: [FlameTrailSegment] = []
}

struct FlameTrailState {
    var configuration = FlameTrailConfiguration()
    private(set) var timeRemaining: TimeInterval = 0
    private(set) var segments: [FlameTrailSegment] = []
    private var nextSegmentID = 1
    private var lastPlayerPosition: CGPoint?
    private var distanceSinceLastSegment: CGFloat = 0

    init(configuration: FlameTrailConfiguration = FlameTrailConfiguration()) {
        self.configuration = configuration
    }

    mutating func activate(at position: CGPoint) {
        let wasActive = timeRemaining > 0
        timeRemaining = max(0, configuration.duration)

        if timeRemaining > 0 {
            if wasActive {
                appendSegmentsAlongMovement(
                    from: lastPlayerPosition ?? position,
                    to: position
                )
            } else {
                appendSegment(at: position)
                distanceSinceLastSegment = 0
            }
        }
        lastPlayerPosition = position
    }

    mutating func reset() {
        timeRemaining = 0
        segments.removeAll()
        nextSegmentID = 1
        lastPlayerPosition = nil
        distanceSinceLastSegment = 0
    }

    mutating func update(
        deltaTime: TimeInterval,
        playerPosition: CGPoint,
        enemies: [ArenaEnemy]
    ) -> FlameTrailFrame {
        let clampedDelta = max(0, deltaTime)
        let previousPlayerPosition = lastPlayerPosition ?? playerPosition
        let activeDelta = min(timeRemaining, clampedDelta)
        let wasActive = timeRemaining > 0
        timeRemaining = max(0, timeRemaining - clampedDelta)
        expireSegments(deltaTime: clampedDelta)

        if wasActive {
            let emissionPosition: CGPoint
            if clampedDelta > 0 {
                let activeFraction = CGFloat(activeDelta / clampedDelta)
                emissionPosition = CGPoint(
                    x: previousPlayerPosition.x + (playerPosition.x - previousPlayerPosition.x) * activeFraction,
                    y: previousPlayerPosition.y + (playerPosition.y - previousPlayerPosition.y) * activeFraction
                )
            } else {
                emissionPosition = playerPosition
            }
            appendSegmentsAlongMovement(
                from: previousPlayerPosition,
                to: emissionPosition
            )
        }
        lastPlayerPosition = playerPosition

        return FlameTrailFrame(
            burnedEnemyIDs: burnTargets(enemies: enemies),
            segments: segments
        )
    }

    private mutating func expireSegments(deltaTime: TimeInterval) {
        guard deltaTime > 0 else {
            return
        }

        for index in segments.indices {
            segments[index].timeRemaining = max(0, segments[index].timeRemaining - deltaTime)
        }
        segments.removeAll { $0.timeRemaining == 0 }
    }

    private mutating func appendSegmentsAlongMovement(from start: CGPoint, to end: CGPoint) {
        let spacing = max(0, configuration.segmentSpacing)
        guard spacing > 0 else {
            appendSegment(at: end)
            distanceSinceLastSegment = 0
            return
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0 else {
            return
        }

        let carriedDistance = max(
            0,
            distanceSinceLastSegment.truncatingRemainder(dividingBy: spacing)
        )
        let distanceToFirstSegment = spacing - carriedDistance
        guard distance >= distanceToFirstSegment else {
            distanceSinceLastSegment = carriedDistance + distance
            return
        }

        let direction = CGVector(dx: dx / distance, dy: dy / distance)
        let distanceAfterFirstSegment = max(0, distance - distanceToFirstSegment)
        let emittedSegmentCount = 1 + Int((distanceAfterFirstSegment / spacing).rounded(.down))
        let retainedSegmentCount = min(max(0, configuration.maxSegments), emittedSegmentCount)
        let firstRetainedSegment = emittedSegmentCount - retainedSegmentCount

        for segmentIndex in firstRetainedSegment..<emittedSegmentCount {
            let stepDistance = distanceToFirstSegment + CGFloat(segmentIndex) * spacing
            appendSegment(at: CGPoint(
                x: start.x + direction.dx * stepDistance,
                y: start.y + direction.dy * stepDistance
            ))
        }

        distanceSinceLastSegment = distanceAfterFirstSegment
            - CGFloat(emittedSegmentCount - 1) * spacing
    }

    private mutating func appendSegment(at position: CGPoint) {
        let lifetime = max(0, configuration.segmentLifetime)
        guard lifetime > 0, configuration.maxSegments > 0 else {
            return
        }

        segments.append(FlameTrailSegment(
            id: nextSegmentID,
            position: position,
            radius: max(0, configuration.segmentRadius),
            timeRemaining: lifetime,
            lifetime: lifetime
        ))
        nextSegmentID += 1

        if segments.count > configuration.maxSegments {
            segments.removeFirst(segments.count - configuration.maxSegments)
        }
    }

    private func burnTargets(enemies: [ArenaEnemy]) -> Set<Int> {
        guard !segments.isEmpty else {
            return []
        }

        return Set(
            enemies
                .filter { enemy in
                    segments.contains { $0.collisionCircle.intersects(enemy.collisionCircle) }
                }
                .map(\.id)
        )
    }

}
