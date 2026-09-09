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

    @discardableResult
    mutating func sanitizeSpawnTimers() -> Int {
        var sanitizedCount = 0
        let timers: [WritableKeyPath<EnemySpawnDirector, TimeInterval>] = [
            \.timeUntilNextChaser
        ] + SpawnPattern.allCases.map(\.timer)
        for timer in timers where !self[keyPath: timer].isFinite {
            self[keyPath: timer] = 0
            sanitizedCount += 1
        }
        return sanitizedCount
    }
}
