import CoreGraphics
import Foundation

struct FlameTrailConfiguration: Equatable {
    var duration: TimeInterval = 4.0
    var segmentLifetime: TimeInterval = 1.2
    var segmentRadius: CGFloat = 18
    var segmentSpacing: CGFloat = 14
    var maxSegments: Int = 24
    var frozenMeltDelay: TimeInterval = 0.3
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
        guard spacing == 0 || squaredDistance(from: lastSegment.position, to: position) >= spacing * spacing else {
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

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}
