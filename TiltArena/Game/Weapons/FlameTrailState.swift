import CoreGraphics
import Foundation

struct FlameTrailConfiguration: Equatable {
    // Gameplay-impacting Flame Trail knobs. Distances are SpriteKit points and durations are seconds.
    // This weapon is separate from StartingWeaponConfiguration because it creates persistent segments
    // over time instead of resolving a one-shot target set.
    // How long the player keeps emitting new trail segments after pickup.
    var duration: TimeInterval = 1.0
    // How long each placed segment remains dangerous.
    var segmentLifetime: TimeInterval = 3.0
    // Kill radius around each segment.
    var segmentRadius: CGFloat = 16
    // Minimum player movement before another segment is placed.
    var segmentSpacing: CGFloat = 14
    // Segment cap; old segments are dropped first when the cap is exceeded.
    var maxSegments: Int = 24
    // Frozen enemies must touch flame this long before melting.
    var frozenMeltDelay: TimeInterval = 0.3
    // Player movement multiplier while the trail is being generated.
    var speedMultiplier: CGFloat = 5
}

extension FlameTrailConfiguration {
    func applying(chargeTier: WeaponPickupChargeTier) -> FlameTrailConfiguration {
        guard chargeTier > .base else {
            return self
        }

        let level = CGFloat(chargeTier.rawValue)
        var configuration = self
        configuration.duration *= 1 + level * 0.20
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
    private var frozenMeltDurations: [Int: TimeInterval] = [:]

    init(configuration: FlameTrailConfiguration = FlameTrailConfiguration()) {
        self.configuration = configuration
    }

    mutating func activate(at position: CGPoint) {
        reset()
        timeRemaining = max(0, configuration.duration)

        if timeRemaining > 0 {
            appendSegment(at: position)
        }
    }

    mutating func reset() {
        timeRemaining = 0
        segments.removeAll()
        nextSegmentID = 1
        frozenMeltDurations.removeAll()
    }

    mutating func update(
        deltaTime: TimeInterval,
        playerPosition: CGPoint,
        enemies: [ArenaEnemy]
    ) -> FlameTrailFrame {
        let clampedDelta = max(0, deltaTime)
        timeRemaining = max(0, timeRemaining - clampedDelta)
        expireSegments(deltaTime: clampedDelta)

        if timeRemaining > 0 {
            appendSegmentIfNeeded(at: playerPosition)
        }

        let burnedEnemyIDs = burnTargets(enemies: enemies, deltaTime: clampedDelta)
        return FlameTrailFrame(burnedEnemyIDs: burnedEnemyIDs, segments: segments)
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

    private mutating func appendSegmentIfNeeded(at position: CGPoint) {
        guard let lastSegment = segments.last else {
            appendSegment(at: position)
            return
        }

        let spacing = max(0, configuration.segmentSpacing)
        guard spacing == 0 || ArenaGeometry.squaredDistance(from: lastSegment.position, to: position) >= spacing * spacing else {
            return
        }

        appendSegment(at: position)
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

    private mutating func burnTargets(enemies: [ArenaEnemy], deltaTime: TimeInterval) -> Set<Int> {
        guard !segments.isEmpty else {
            frozenMeltDurations.removeAll()
            return []
        }

        var burnedEnemyIDs = Set<Int>()
        var contactingFrozenEnemyIDs = Set<Int>()

        for enemy in enemies where segments.contains(where: { $0.collisionCircle.intersects(enemy.collisionCircle) }) {
            if enemy.isFrozen {
                contactingFrozenEnemyIDs.insert(enemy.id)
                let meltDuration = frozenMeltDurations[enemy.id, default: 0] + deltaTime

                if meltDuration >= max(0, configuration.frozenMeltDelay) {
                    burnedEnemyIDs.insert(enemy.id)
                } else {
                    frozenMeltDurations[enemy.id] = meltDuration
                }
            } else {
                burnedEnemyIDs.insert(enemy.id)
            }
        }

        frozenMeltDurations = frozenMeltDurations.filter { enemyID, _ in
            contactingFrozenEnemyIDs.contains(enemyID) && !burnedEnemyIDs.contains(enemyID)
        }
        return burnedEnemyIDs
    }

}
