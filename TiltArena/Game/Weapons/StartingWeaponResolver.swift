import CoreGraphics
import Foundation

struct StartingWeaponConfiguration: Equatable {
    var shockwaveRadius: CGFloat = 104
    var shockwaveExpansionDuration: TimeInterval = 0.3
    var shockwaveHoldDuration: TimeInterval = 0.1
    var seekerTargetLimit: Int = 4
    var razorShieldRadius: CGFloat = 32
    var razorShieldDuration: TimeInterval = 4
    var razorShieldExplosionRadius: CGFloat = 40
    var freezeBurstRadius: CGFloat = 140
    var freezeExpansionDuration: TimeInterval = 0.25
    var freezeDuration: TimeInterval = 4
    var freezeThawGraceDuration: TimeInterval = 0.35
    var frozenCrasherDuration: TimeInterval = 2.4
    var gravityWellRadius: CGFloat = 132
    var gravityWellActivationDelay: TimeInterval = 0.5
    var gravityWellPullDuration: TimeInterval = 0.85
    var gravityWellClearRadius: CGFloat = 32
    var chainLightningInitialRange: CGFloat = 128
    var chainLightningJumpRange: CGFloat = 96
    var chainLightningTargetLimit: Int = 6
    var warpDashDistanceFractionOfShortSide: CGFloat = 0.33
    var warpDashInvulnerabilityDuration: TimeInterval = 0.50
    var powerWaveChargeDuration: TimeInterval = 0.35
    var powerWaveRange: CGFloat = 180
    var powerWaveFanAngleDegrees: CGFloat = 70
    var powerWaveExpansionDuration: TimeInterval = 0.24
    var novaBombMaximumTargetCount: Int = 15
    var novaBombTargetFraction: Double = 0.8
}

struct WeaponResolution: Equatable {
    var destroyedEnemyIDs: Set<Int> = []
    var frozenEnemyIDs: Set<Int> = []
    var gravityWellEnemyIDs: Set<Int> = []
    var chainLightningEnemyIDs: [Int] = []
}

struct WeaponEffectTiming: Equatable {
    var projectileSpeed: CGFloat = 520
    var waveSpeed: CGFloat = 620
    var minimumTravelDuration: TimeInterval = 0.08
    var maximumProjectileTravelDuration: TimeInterval = 0.42
    var maximumWaveTravelDuration: TimeInterval = 0.72

    func projectileDuration(from origin: CGPoint, to target: CGPoint) -> TimeInterval {
        duration(
            distance: distance(from: origin, to: target),
            speed: projectileSpeed,
            maximumDuration: maximumProjectileTravelDuration
        )
    }

    func waveDuration(from origin: CGPoint, to target: CGPoint) -> TimeInterval {
        duration(
            distance: distance(from: origin, to: target),
            speed: waveSpeed,
            maximumDuration: maximumWaveTravelDuration
        )
    }

    func waveDuration(radius: CGFloat) -> TimeInterval {
        duration(
            distance: max(0, radius),
            speed: waveSpeed,
            maximumDuration: maximumWaveTravelDuration
        )
    }

    func chainImpactDelays(origin: CGPoint, targets: [CGPoint]) -> [TimeInterval] {
        var currentOrigin = origin
        var elapsed: TimeInterval = 0
        return targets.map { target in
            elapsed += projectileDuration(from: currentOrigin, to: target)
            currentOrigin = target
            return elapsed
        }
    }

    private func duration(distance: CGFloat, speed: CGFloat, maximumDuration: TimeInterval) -> TimeInterval {
        guard distance > 0, speed > 0 else {
            return minimumTravelDuration
        }

        let rawDuration = TimeInterval(distance / speed)
        return min(maximumDuration, max(minimumTravelDuration, rawDuration))
    }

    private func distance(from origin: CGPoint, to target: CGPoint) -> CGFloat {
        hypot(target.x - origin.x, target.y - origin.y)
    }
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
        case .flameTrail, .warpDash, .powerWave:
            return WeaponResolution()
        case .novaBomb:
            return WeaponResolution()
        }
    }

    func shieldTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let shieldCircle = CollisionCircle(center: playerPosition, radius: configuration.razorShieldRadius)
        return Set(enemies.filter { shieldCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    func shieldExplosionTargets(playerPosition: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let explosionCircle = CollisionCircle(center: playerPosition, radius: configuration.razorShieldExplosionRadius)
        return Set(enemies.filter { explosionCircle.intersects($0.collisionCircle) }.map(\.id))
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
        return Set(enemies.filter { wellCircle.intersects($0.collisionCircle) }.map(\.id))
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
