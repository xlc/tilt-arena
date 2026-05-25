import CoreGraphics

struct WeaponApplicationLog: Equatable {
    var destroyedCount: Int = 0
    var frozenCount: Int = 0
    var gravityTargetCount: Int = 0
}

struct WeaponApplication: Equatable {
    enum Effect: Equatable {
        case shockwaveWave
        case seekerSwarm(enemyIDs: Set<Int>)
        case razorShield
        case freezeBurstWave
        case gravityWell(enemyIDs: Set<Int>)
        case chainLightning(enemyIDs: [Int])
        case flameTrail
        case directional(WeaponKind)
        case powerWave
        case novaBomb(enemyIDs: Set<Int>)
    }

    var effect: Effect
    var log: WeaponApplicationLog
}

struct WeaponApplicationCoordinator {
    var resolver = StartingWeaponResolver()

    func application<R: RandomNumberGenerator>(
        kind: WeaponKind,
        playerPosition: CGPoint,
        enemies: [ArenaEnemy],
        using rng: inout R
    ) -> WeaponApplication {
        let resolution = resolver.resolve(
            kind: kind,
            playerPosition: playerPosition,
            enemies: enemies
        )
        var log = WeaponApplicationLog(
            destroyedCount: resolution.destroyedEnemyIDs.count,
            frozenCount: resolution.frozenEnemyIDs.count,
            gravityTargetCount: resolution.gravityWellEnemyIDs.count
        )

        switch kind {
        case .shockwave:
            log.destroyedCount = 0
            return WeaponApplication(effect: .shockwaveWave, log: log)
        case .seekerSwarm:
            return WeaponApplication(effect: .seekerSwarm(enemyIDs: resolution.destroyedEnemyIDs), log: log)
        case .razorShield:
            return WeaponApplication(effect: .razorShield, log: log)
        case .freezeBurst:
            return WeaponApplication(effect: .freezeBurstWave, log: log)
        case .gravityWell:
            return WeaponApplication(effect: .gravityWell(enemyIDs: resolution.gravityWellEnemyIDs), log: log)
        case .chainLightning:
            return WeaponApplication(effect: .chainLightning(enemyIDs: resolution.chainLightningEnemyIDs), log: log)
        case .flameTrail:
            return WeaponApplication(effect: .flameTrail, log: log)
        case .warpDash, .ricochetLance:
            return WeaponApplication(effect: .directional(kind), log: log)
        case .powerWave:
            return WeaponApplication(effect: .powerWave, log: log)
        case .novaBomb:
            let targetIDs = NovaBombTargetSelector(configuration: resolver.configuration).selectedEnemyIDs(
                from: enemies,
                using: &rng
            )
            log.destroyedCount = targetIDs.count
            return WeaponApplication(effect: .novaBomb(enemyIDs: targetIDs), log: log)
        }
    }
}
