import Foundation

extension EnemySpawnDirector {
    enum SpawnPattern: CaseIterable, Hashable {
        case formation
        case splitter
        case arrowRush
        case mineDot
        case hunterDot
        case paddleTrap

        var timer: WritableKeyPath<EnemySpawnDirector, TimeInterval> {
            switch self {
            case .formation:
                return \.timeUntilNextFormation
            case .splitter:
                return \.timeUntilNextSplitter
            case .arrowRush:
                return \.timeUntilNextArrowRush
            case .mineDot:
                return \.timeUntilNextMineDot
            case .hunterDot:
                return \.timeUntilNextHunterDot
            case .paddleTrap:
                return \.timeUntilNextPaddleTrap
            }
        }

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
        interval: TimeInterval
    ) {
        guard enabledSpawnPatterns.insert(pattern).inserted else {
            return
        }

        let interval = interval.isFinite ? max(0, interval) : 0
        let spacing = configuration.patternIntroductionSpacing.isFinite
            ? max(0, configuration.patternIntroductionSpacing)
            : 0
        self[keyPath: pattern.timer] = min(interval, spacing * pattern.introductionStep)
    }

    mutating func advanceTelegraphTimer(
        for pattern: SpawnPattern,
        interval: TimeInterval,
        deltaTime: TimeInterval,
        hasEnemyCapacity: Bool
    ) -> Bool {
        primeTimer(for: pattern, interval: interval)

        // Capacity blocks postpone the next attempt without consuming this frame's time.
        guard pendingTelegraphSlotCount < pendingTelegraphCapacity, hasEnemyCapacity else {
            self[keyPath: pattern.timer] = max(self[keyPath: pattern.timer], interval)
            return false
        }

        self[keyPath: pattern.timer] -= deltaTime
        return self[keyPath: pattern.timer] <= 0
    }

    mutating func disablePattern(_ pattern: SpawnPattern) {
        enabledSpawnPatterns.remove(pattern)
        self[keyPath: pattern.timer] = 0
    }

    mutating func resetSpawnSchedule() {
        enabledSpawnPatterns.removeAll()
        pendingSpawns.removeAll()
    }
}
