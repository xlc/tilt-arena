import Foundation

struct NovaBombTargetSelector: Equatable {
    let targetFraction: Double

    init(configuration: StartingWeaponConfiguration = StartingWeaponConfiguration()) {
        targetFraction = configuration.sanitizedForRuntime().novaBombTargetFraction
    }

    func targetCount(enemyCount: Int) -> Int {
        let clampedEnemyCount = max(0, enemyCount)
        guard clampedEnemyCount > 0 else {
            return 0
        }
        guard targetFraction > 0 else {
            return 0
        }
        guard targetFraction < 1 else {
            return clampedEnemyCount
        }

        let fractionalTargetCount = (Double(clampedEnemyCount) * targetFraction).rounded()
        guard fractionalTargetCount.isFinite, fractionalTargetCount > 0 else {
            return 0
        }
        guard fractionalTargetCount < Double(Int.max) else {
            return clampedEnemyCount
        }

        return min(
            clampedEnemyCount,
            max(0, Int(fractionalTargetCount))
        )
    }

    func selectedEnemyIDs<R: RandomNumberGenerator>(from enemies: [ArenaEnemy], using rng: inout R) -> Set<Int> {
        let count = targetCount(enemyCount: enemies.count)
        guard count > 0 else {
            return []
        }

        var enemyIDs = enemies.map(\.id)
        enemyIDs.shuffle(using: &rng)
        return Set(enemyIDs.prefix(count))
    }
}
