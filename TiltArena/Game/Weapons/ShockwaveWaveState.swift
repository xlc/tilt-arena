import CoreGraphics
import Foundation

struct ShockwaveWaveFrame: Equatable {
    let destroyedEnemyIDs: Set<Int>
    let radius: CGFloat
    let isComplete: Bool
}

struct ShockwaveWaveState: Equatable {
    private static let timeEpsilon: TimeInterval = 0.000_001

    let activation: WeaponActivation
    let center: CGPoint
    let maximumRadius: CGFloat
    let expansionDuration: TimeInterval
    let holdDuration: TimeInterval
    let expansionExponent: Double
    private(set) var elapsedTime: TimeInterval = 0
    private var destroyedEnemyIDs: Set<Int> = []

    init(
        center: CGPoint,
        maximumRadius: CGFloat,
        expansionDuration: TimeInterval,
        holdDuration: TimeInterval,
        expansionExponent: Double = 1,
        activation: WeaponActivation = WeaponActivation(kind: .shockwave)
    ) {
        self.activation = activation
        self.center = center
        self.maximumRadius = WeaponRuntimeSafetyLimits.distance(maximumRadius)
        self.expansionDuration = WeaponRuntimeSafetyLimits.duration(expansionDuration)
        self.holdDuration = WeaponRuntimeSafetyLimits.duration(holdDuration)
        self.expansionExponent = expansionExponent
    }

    var isComplete: Bool {
        elapsedTime + Self.timeEpsilon >= totalDuration && elapsedTime > 0
    }

    mutating func update(deltaTime: TimeInterval, enemies: [ArenaEnemy]) -> ShockwaveWaveFrame {
        guard !isComplete else {
            return ShockwaveWaveFrame(
                destroyedEnemyIDs: [],
                radius: currentRadius,
                isComplete: true
            )
        }

        let deltaTime = deltaTime.isFinite ? max(0, deltaTime) : 0
        elapsedTime = min(totalDuration, elapsedTime + deltaTime)
        if totalDuration == 0 {
            elapsedTime = .leastNonzeroMagnitude
        }

        let waveCircle = CollisionCircle(center: center, radius: currentRadius)
        let newlyDestroyedEnemyIDs = Set(
            enemies
                .filter { !destroyedEnemyIDs.contains($0.id) && waveCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )
        destroyedEnemyIDs.formUnion(newlyDestroyedEnemyIDs)

        return ShockwaveWaveFrame(
            destroyedEnemyIDs: newlyDestroyedEnemyIDs,
            radius: currentRadius,
            isComplete: isComplete
        )
    }

    private var currentRadius: CGFloat {
        let clampedMaximumRadius = max(0, maximumRadius)
        let clampedExpansionDuration = max(0, expansionDuration)

        guard clampedExpansionDuration > 0 else {
            return clampedMaximumRadius
        }

        return clampedMaximumRadius * WeaponWaveExpansion.progress(
            elapsed: elapsedTime, duration: clampedExpansionDuration, exponent: expansionExponent
        )
    }

    private var totalDuration: TimeInterval {
        max(0, expansionDuration) + max(0, holdDuration)
    }
}
