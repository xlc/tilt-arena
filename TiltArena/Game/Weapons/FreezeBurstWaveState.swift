import CoreGraphics
import Foundation

struct FreezeBurstWaveFrame: Equatable {
    let frozenEnemyIDs: Set<Int>
    let radius: CGFloat
    let isComplete: Bool
}

struct FreezeBurstWaveState: Equatable {
    let activation: WeaponActivation
    let center: CGPoint
    let maximumRadius: CGFloat
    let duration: TimeInterval
    let freezeDuration: TimeInterval
    let thawGraceDuration: TimeInterval
    private(set) var elapsedTime: TimeInterval = 0
    private var appliedEnemyIDs: Set<Int> = []

    init(
        center: CGPoint,
        maximumRadius: CGFloat,
        duration: TimeInterval,
        freezeDuration: TimeInterval = StartingWeaponConfiguration().freezeDuration,
        thawGraceDuration: TimeInterval = StartingWeaponConfiguration().freezeThawGraceDuration,
        activation: WeaponActivation = WeaponActivation(kind: .freezeBurst)
    ) {
        self.activation = activation
        self.center = center
        self.maximumRadius = WeaponRuntimeSafetyLimits.distance(maximumRadius)
        self.duration = WeaponRuntimeSafetyLimits.duration(duration)
        self.freezeDuration = WeaponRuntimeSafetyLimits.duration(freezeDuration)
        self.thawGraceDuration = WeaponRuntimeSafetyLimits.duration(thawGraceDuration)
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
            let deltaTime = deltaTime.isFinite ? max(0, deltaTime) : 0
            elapsedTime = min(clampedDuration, elapsedTime + deltaTime)
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
