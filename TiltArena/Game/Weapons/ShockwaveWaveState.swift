import CoreGraphics
import Foundation

struct ShockwaveWaveFrame: Equatable {
    let destroyedEnemyIDs: Set<Int>
    let radius: CGFloat
    let isComplete: Bool
}

struct ShockwaveWaveState: Equatable {
    private static let timeEpsilon: TimeInterval = 0.000_001

    let center: CGPoint
    let maximumRadius: CGFloat
    let expansionDuration: TimeInterval
    let holdDuration: TimeInterval
    private(set) var elapsedTime: TimeInterval = 0
    private var destroyedEnemyIDs: Set<Int> = []

    init(
        center: CGPoint,
        maximumRadius: CGFloat,
        expansionDuration: TimeInterval,
        holdDuration: TimeInterval
    ) {
        self.center = center
        self.maximumRadius = maximumRadius
        self.expansionDuration = expansionDuration
        self.holdDuration = holdDuration
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

        elapsedTime = min(totalDuration, elapsedTime + max(0, deltaTime))
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

        let progress = min(1, max(0, elapsedTime / clampedExpansionDuration))
        return clampedMaximumRadius * CGFloat(progress)
    }

    private var totalDuration: TimeInterval {
        max(0, expansionDuration) + max(0, holdDuration)
    }
}
