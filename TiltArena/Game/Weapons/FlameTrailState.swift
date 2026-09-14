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
        var configuration = self
        guard chargeTier > .base else {
            return configuration
        }

        let level = CGFloat(chargeTier.rawValue)
        configuration.segmentLifetime *= 1 + level * 0.12
        configuration.segmentRadius *= 1 + level * 0.10
        configuration.maxSegments += min(chargeTier.rawValue * 6, Int.max - configuration.maxSegments)
        return configuration
    }
}

struct FlameTrailSegment: Equatable, Identifiable {
    var activation: WeaponActivation?
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
    var killsByActivation: [WeaponActivation: Set<Int>] = [:]
    var burnedEnemyIDs: Set<Int> = []
    var segments: [FlameTrailSegment] = []
}

struct FlameTrailState {
    var configuration = FlameTrailConfiguration()
    private(set) var timeRemaining: TimeInterval = 0
    private(set) var segments: [FlameTrailSegment] = []
    private var activation: WeaponActivation?
    private var nextSegmentID = 1
    private var lastPlayerPosition: CGPoint?
    private var distanceSinceLastSegment: CGFloat = 0

    init(configuration: FlameTrailConfiguration = FlameTrailConfiguration()) {
        self.configuration = configuration
    }

    mutating func activate(
        at position: CGPoint, activation: WeaponActivation = WeaponActivation(kind: .flameTrail)
    ) {
        guard position.isFinite else {
            timeRemaining = 0
            return
        }
        let wasActive = timeRemaining > 0
        timeRemaining = configuration.duration

        if timeRemaining > 0 {
            if wasActive {
                appendSegmentsAlongMovement(
                    from: lastPlayerPosition ?? position,
                    to: position
                )
            } else {
                self.activation = activation
                appendSegment(at: position)
                distanceSinceLastSegment = 0
            }
        }
        self.activation = activation
        lastPlayerPosition = position
    }

    mutating func reset() {
        activation = nil
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
        trimSegmentsToLimit()
        let clampedDelta = deltaTime.isFinite ? max(0, deltaTime) : 0
        let playerPosition = playerPosition.isFinite
            ? playerPosition
            : lastPlayerPosition ?? .zero
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
        if timeRemaining == 0 { activation = nil }

        var frame = FlameTrailFrame(segments: segments)
        for enemy in enemies {
            guard let segment = segments.first(where: { $0.collisionCircle.intersects(enemy.collisionCircle) }) else { continue }
            frame.burnedEnemyIDs.insert(enemy.id)
            if let activation = segment.activation {
                frame.killsByActivation[activation, default: []].insert(enemy.id)
            }
        }
        return frame
    }

    private mutating func expireSegments(deltaTime: TimeInterval) {
        guard deltaTime > 0 else {
            return
        }

        for index in segments.indices {
            let remaining = WeaponRuntimeSafetyLimits.duration(segments[index].timeRemaining)
            segments[index].timeRemaining = max(0, remaining - deltaTime)
        }
        segments.removeAll { $0.timeRemaining == 0 }
    }

    private mutating func appendSegmentsAlongMovement(from start: CGPoint, to end: CGPoint) {
        guard start.isFinite, end.isFinite, configuration.maxSegments > 0 else {
            distanceSinceLastSegment = 0
            return
        }
        let spacing = configuration.segmentSpacing
        guard spacing > 0 else {
            appendSegment(at: end)
            distanceSinceLastSegment = 0
            return
        }

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance.isFinite, distance > 0 else {
            return
        }

        if !distanceSinceLastSegment.isFinite {
            distanceSinceLastSegment = 0
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
        let additionalSegmentCount = min(
            CGFloat(configuration.maxSegments - 1),
            floor(distanceAfterFirstSegment / spacing)
        )
        let retainedSegmentCount = 1 + Int(additionalSegmentCount)
        let residualDistance = distanceAfterFirstSegment.truncatingRemainder(dividingBy: spacing)
        let lastStepDistance = distanceToFirstSegment + distanceAfterFirstSegment - residualDistance
        let firstStepDistance = max(
            0,
            lastStepDistance - CGFloat(retainedSegmentCount - 1) * spacing
        )

        for segmentIndex in 0..<retainedSegmentCount {
            let stepDistance = firstStepDistance + CGFloat(segmentIndex) * spacing
            appendSegment(at: CGPoint(
                x: start.x + direction.dx * stepDistance,
                y: start.y + direction.dy * stepDistance
            ))
        }

        distanceSinceLastSegment = residualDistance
    }

    private mutating func appendSegment(at position: CGPoint) {
        guard position.isFinite else {
            return
        }
        let lifetime = configuration.segmentLifetime
        guard lifetime > 0, configuration.maxSegments > 0 else {
            return
        }

        segments.append(FlameTrailSegment(
            activation: activation,
            id: nextSegmentID,
            position: position,
            radius: configuration.segmentRadius,
            timeRemaining: lifetime,
            lifetime: lifetime
        ))
        nextSegmentID = nextSegmentID == Int.max ? 1 : nextSegmentID + 1

        if segments.count > configuration.maxSegments {
            segments.removeFirst(segments.count - configuration.maxSegments)
        }
    }

    private mutating func trimSegmentsToLimit() {
        let excessCount = segments.count - configuration.maxSegments
        if excessCount > 0 {
            segments.removeFirst(excessCount)
        }
    }

}
