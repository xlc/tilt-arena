import CoreGraphics
import Foundation

struct StartingWeaponConfiguration: Equatable {
    var shockwaveRadius: CGFloat = 96
    var seekerTargetLimit: Int = 4
    var razorShieldRadius: CGFloat = 32
    var razorShieldDuration: TimeInterval = 4
    var freezeBurstRadius: CGFloat = 112
    var freezeDuration: TimeInterval = 4
    var frozenCrasherDuration: TimeInterval = 2.4
    var gravityWellRadius: CGFloat = 132
    var gravityWellPullDuration: TimeInterval = 0.85
    var gravityWellClearRadius: CGFloat = 32
    var chainLightningInitialRange: CGFloat = 128
    var chainLightningJumpRange: CGFloat = 96
    var chainLightningTargetLimit: Int = 6
    var warpDashDistanceFractionOfShortSide: CGFloat = 0.33
    var warpDashInvulnerabilityDuration: TimeInterval = 0.35
}

struct WeaponResolution: Equatable {
    var destroyedEnemyIDs: Set<Int> = []
    var frozenEnemyIDs: Set<Int> = []
    var gravityWellEnemyIDs: Set<Int> = []
    var chainLightningEnemyIDs: [Int] = []
}

struct StartingWeaponResolver {
    var configuration = StartingWeaponConfiguration()

    func resolve(kind: WeaponKind, playerPosition: CGPoint, enemies: [ArenaEnemy]) -> WeaponResolution {
        switch kind {
        case .shockwave:
            return WeaponResolution(destroyedEnemyIDs: shockwaveTargets(playerPosition: playerPosition, enemies: enemies))
        case .seekerSwarm:
            return WeaponResolution(destroyedEnemyIDs: seekerTargets(playerPosition: playerPosition, enemies: enemies))
        case .razorShield:
            return WeaponResolution()
        case .freezeBurst:
            return WeaponResolution(frozenEnemyIDs: freezeBurstTargets(playerPosition: playerPosition, enemies: enemies))
        case .gravityWell:
            return WeaponResolution(gravityWellEnemyIDs: gravityWellTargets(playerPosition: playerPosition, enemies: enemies))
        case .chainLightning:
            let targetIDs = chainLightningTargets(playerPosition: playerPosition, enemies: enemies)
            return WeaponResolution(
                destroyedEnemyIDs: Set(targetIDs),
                chainLightningEnemyIDs: targetIDs
            )
        case .flameTrail, .warpDash, .decoyBeacon:
            return WeaponResolution()
        case .novaBomb:
            return WeaponResolution(destroyedEnemyIDs: Set(enemies.map(\.id)))
        }
    }

    func shieldTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let shieldCircle = CollisionCircle(center: playerPosition, radius: configuration.razorShieldRadius)
        return Set(enemies.filter { shieldCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func shockwaveTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let shockwaveCircle = CollisionCircle(center: playerPosition, radius: configuration.shockwaveRadius)
        return Set(enemies.filter { shockwaveCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func seekerTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let targetLimit = max(0, configuration.seekerTargetLimit)

        guard targetLimit > 0 else {
            return []
        }

        return Set(
            enemies
                .sorted {
                    ArenaGeometry.squaredDistance(from: $0.position, to: playerPosition)
                        < ArenaGeometry.squaredDistance(from: $1.position, to: playerPosition)
                }
                .prefix(targetLimit)
                .map(\.id)
        )
    }

    private func freezeBurstTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let freezeCircle = CollisionCircle(center: playerPosition, radius: configuration.freezeBurstRadius)
        return Set(enemies.filter { freezeCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func gravityWellTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let wellCircle = CollisionCircle(center: playerPosition, radius: configuration.gravityWellRadius)
        return Set(enemies.filter { !$0.isFrozen && wellCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func chainLightningTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> [Int] {
        let targetLimit = max(0, configuration.chainLightningTargetLimit)

        guard targetLimit > 0 else {
            return []
        }

        var targetIDs: [Int] = []
        var selectedIDs = Set<Int>()
        var origin = playerPosition
        var range = configuration.chainLightningInitialRange

        while targetIDs.count < targetLimit {
            guard let target = nearestEnemy(
                from: origin,
                within: range,
                excluding: selectedIDs,
                enemies: enemies
            ) else {
                return targetIDs
            }

            targetIDs.append(target.id)
            selectedIDs.insert(target.id)
            origin = target.position
            range = configuration.chainLightningJumpRange
        }

        return targetIDs
    }

    private func nearestEnemy(
        from origin: CGPoint,
        within range: CGFloat,
        excluding selectedIDs: Set<Int>,
        enemies: [ArenaEnemy]
    ) -> ArenaEnemy? {
        let maximumDistance = max(0, range)
        let maximumSquaredDistance = maximumDistance * maximumDistance

        return enemies
            .filter { enemy in
                !selectedIDs.contains(enemy.id)
                    && ArenaGeometry.squaredDistance(from: enemy.position, to: origin) <= maximumSquaredDistance
            }
            .min {
                ArenaGeometry.squaredDistance(from: $0.position, to: origin)
                    < ArenaGeometry.squaredDistance(from: $1.position, to: origin)
            }
    }
}
