import Foundation

struct NovaBombTargetSelector: Equatable {
    let minimumTargetCount: Int
    let targetFraction: Double

    init(configuration: StartingWeaponConfiguration = StartingWeaponConfiguration()) {
        minimumTargetCount = configuration.novaBombMinimumTargetCount
        targetFraction = configuration.novaBombTargetFraction
    }

    func targetCount(enemyCount: Int) -> Int {
        let clampedEnemyCount = max(0, enemyCount)
        let fractionalTargetCount = (Double(clampedEnemyCount) * max(0, targetFraction)).rounded()
        guard clampedEnemyCount > 0 else {
            return 0
        }

        return min(
            clampedEnemyCount,
            max(max(0, minimumTargetCount), max(0, Int(fractionalTargetCount)))
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
