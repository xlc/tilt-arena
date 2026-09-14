import Foundation

extension EnemySpawnDirector {
    var pendingTelegraphCapacity: Int {
        configuration.maxPendingEnemyTelegraphs
    }

    var pendingSpawnWarningCapacity: Int {
        configuration.maxPendingSpawnWarnings
    }

    var requiredFormationEnemyCount: Int {
        configuration.minimumFormationEnemyCount
    }

    func telegraphDuration(_ duration: TimeInterval) -> TimeInterval {
        EnemySpawnSafetyLimits.statusDuration(duration)
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
