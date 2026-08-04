import Foundation

extension EnemySpawnDirector {
    enum SpawnPattern: Hashable {
        case formation
        case splitter
        case arrowRush
        case mineDot
        case hunterDot
        case paddleTrap

        var introductionStep: Double {
            switch self {
            case .formation:
                return 1
            case .splitter, .arrowRush:
                return 2
            case .mineDot:
                return 3
            case .hunterDot:
                return 4
            case .paddleTrap:
                return 5
            }
        }
    }

    mutating func primeTimer(
        for pattern: SpawnPattern,
        interval: TimeInterval,
        timer: WritableKeyPath<EnemySpawnDirector, TimeInterval>
    ) {
        guard enabledSpawnPatterns.insert(pattern).inserted else {
            return
        }

        let interval = interval.isFinite ? max(0, interval) : 0
        let spacing = configuration.patternIntroductionSpacing.isFinite
            ? max(0, configuration.patternIntroductionSpacing)
            : 0
        self[keyPath: timer] = min(interval, spacing * pattern.introductionStep)
    }

    mutating func disablePattern(
        _ pattern: SpawnPattern,
        timer: WritableKeyPath<EnemySpawnDirector, TimeInterval>
    ) {
        enabledSpawnPatterns.remove(pattern)
        self[keyPath: timer] = 0
    }

    mutating func resetSpawnSchedule() {
        enabledSpawnPatterns.removeAll()
        pendingSpawns.removeAll()
    }
}
