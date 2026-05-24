import CoreGraphics
import Foundation

struct FreezeBurstWaveFrame: Equatable {
    let frozenEnemyIDs: Set<Int>
    let radius: CGFloat
    let isComplete: Bool
}

struct FreezeBurstWaveState: Equatable {
    let center: CGPoint
    let maximumRadius: CGFloat
    let duration: TimeInterval
    private(set) var elapsedTime: TimeInterval = 0
    private var appliedEnemyIDs: Set<Int> = []

    init(center: CGPoint, maximumRadius: CGFloat, duration: TimeInterval) {
        self.center = center
        self.maximumRadius = maximumRadius
        self.duration = duration
    }

    var isComplete: Bool {
        let clampedDuration = max(0, duration)
        return clampedDuration == 0 ? elapsedTime > 0 : elapsedTime >= clampedDuration
    }

    mutating func update(deltaTime: TimeInterval, enemies: [ArenaEnemy]) -> FreezeBurstWaveFrame {
        guard !isComplete else {
            return FreezeBurstWaveFrame(
                frozenEnemyIDs: [],
                radius: currentRadius,
                isComplete: true
            )
        }

        let clampedDuration = max(0, duration)
        if clampedDuration == 0 {
            elapsedTime = 1
        } else {
            elapsedTime = min(clampedDuration, elapsedTime + max(0, deltaTime))
        }
        let radius = currentRadius
        let freezeCircle = CollisionCircle(center: center, radius: radius)
        let frozenEnemyIDs = Set(
            enemies
                .filter { !appliedEnemyIDs.contains($0.id) && freezeCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )
        appliedEnemyIDs.formUnion(frozenEnemyIDs)

        return FreezeBurstWaveFrame(
            frozenEnemyIDs: frozenEnemyIDs,
            radius: radius,
            isComplete: isComplete
        )
    }

    private var currentRadius: CGFloat {
        let clampedMaximumRadius = max(0, maximumRadius)
        let clampedDuration = max(0, duration)

        guard clampedDuration > 0 else {
            return clampedMaximumRadius
        }

        let progress = min(1, max(0, elapsedTime / clampedDuration))
        return clampedMaximumRadius * CGFloat(progress)
    }
}
