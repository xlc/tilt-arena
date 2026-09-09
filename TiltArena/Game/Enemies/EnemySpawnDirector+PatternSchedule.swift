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

    mutating func spawnPatterns(context: SpawnContext, frame: inout EnemySpawnFrame) {
        // Older due patterns get first use of shared capacity. Stable ties keep
        // the seeded schedule deterministic. An unplaceable pattern cannot block others.
        let patterns = SpawnPattern.allCases.enumerated().sorted { first, second in
            let firstTimer = self[keyPath: first.element.timer]
            let secondTimer = self[keyPath: second.element.timer]
            return firstTimer == secondTimer ? first.offset < second.offset : firstTimer < secondTimer
        }
        for (_, pattern) in patterns {
            let projectedCount = context.activeEnemies.count + frame.newEnemies.count + pendingEnemyCount
            switch pattern {
            case .formation:
                spawnFormationTelegraphIfNeeded(projectedEnemyCount: projectedCount, context: context, frame: &frame)
            case .splitter:
                spawnSplitterIfNeeded(projectedEnemyCount: projectedCount, context: context, frame: &frame)
            case .arrowRush:
                spawnArrowRushTelegraphIfNeeded(projectedEnemyCount: projectedCount, context: context, frame: &frame)
            case .mineDot:
                spawnMineDotTelegraphIfNeeded(context: context, frame: &frame)
            case .hunterDot:
                spawnHunterDotTelegraphIfNeeded(context: context, frame: &frame)
            case .paddleTrap:
                spawnPaddleTrapTelegraphIfNeeded(context: context, frame: &frame)
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
        hasEnemyCapacity: Bool,
        hasRoleCapacity: Bool = true
    ) -> Bool {
        primeTimer(for: pattern, interval: interval)

        // Readiness ages even while capacity is occupied; blocking never restarts a cooldown.
        self[keyPath: pattern.timer] -= deltaTime
        capacityGates.enemy = capacityGates.enemy || !hasEnemyCapacity
        capacityGates.role = capacityGates.role || !hasRoleCapacity
        capacityGates.warning = capacityGates.warning || pendingTelegraphSlotCount >= pendingTelegraphCapacity
        return self[keyPath: pattern.timer] <= 0
            && pendingTelegraphSlotCount < pendingTelegraphCapacity
            && hasEnemyCapacity
            && hasRoleCapacity
    }

    mutating func completePattern(_ pattern: SpawnPattern, interval: TimeInterval, deltaTime: TimeInterval) {
        let remaining = self[keyPath: pattern.timer]
        // Preserve normal sub-frame overshoot, but discard blocked or long-frame
        // debt so clearing capacity cannot release a burst of missed spawns.
        let overshoot = remaining >= -deltaTime && remaining > -interval ? remaining : 0
        self[keyPath: pattern.timer] = interval + overshoot
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
