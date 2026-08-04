import Foundation

extension EnemySpawnDirector {
    var pendingTelegraphCapacity: Int {
        min(
            EnemySpawnSafetyLimits.maximumPendingTelegraphCount,
            max(0, configuration.maxPendingEnemyTelegraphs)
        )
    }

    var pendingSpawnWarningCapacity: Int {
        min(
            EnemySpawnSafetyLimits.maximumPendingTelegraphCount,
            max(0, configuration.maxPendingSpawnWarnings)
        )
    }

    var requiredFormationEnemyCount: Int {
        min(
            EnemySpawnSafetyLimits.maximumFormationLaneCount - 1,
            max(1, configuration.minimumFormationEnemyCount)
        )
    }

    func telegraphDuration(_ duration: TimeInterval) -> TimeInterval {
        EnemySpawnSafetyLimits.telegraphDuration(duration)
    }

    mutating func sanitizeSpawnTimers() {
        let timers: [WritableKeyPath<EnemySpawnDirector, TimeInterval>] = [
            \.timeUntilNextChaser,
            \.timeUntilNextFormation,
            \.timeUntilNextSplitter,
            \.timeUntilNextArrowRush,
            \.timeUntilNextMineDot,
            \.timeUntilNextHunterDot,
            \.timeUntilNextPaddleTrap
        ]
        for timer in timers where !self[keyPath: timer].isFinite {
            self[keyPath: timer] = 0
        }
    }
}
