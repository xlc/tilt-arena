import CoreGraphics
import Foundation

struct StartingWeaponConfiguration: Equatable {
    // Gameplay-impacting weapon knobs. Distances are SpriteKit points, durations are seconds,
    // and target limits are enemy counts. Shared visual travel timing lives in WeaponEffectTiming;
    // per-weapon visual timing stays here when it only applies to one weapon.
    //
    // Naming convention:
    // - Radius/range/beam width values define what enemies a weapon can reach or clear.
    // - Duration/hold/delay values define how long the gameplay effect lasts or waits.
    // - Target limit/count/fraction values cap how many enemies a weapon may affect.
    var shockwaveRadius: CGFloat = 90
    // Time for the expanding damaging wave to reach shockwaveRadius.
    var shockwaveExpansionDuration: TimeInterval = 0.6
    // Extra time the wave remains active after reaching full radius.
    var shockwaveHoldDuration: TimeInterval = 0.2
    // Number of nearest enemies the swarm launches at.
    var seekerTargetLimit: Int = 4
    // Area clear around each seeker impact.
    var seekerExplosionRadius: CGFloat = 30
    // Time seeker impact markers linger after exploding.
    var seekerExplosionHoldDuration: TimeInterval = 0.2
    // Projectile travel speed for seeker visuals.
    var seekerTravelSpeed: CGFloat = 320
    // Contact kill radius while the shield is orbiting the player.
    var razorShieldRadius: CGFloat = 28
    // How long the shield stays active.
    var razorShieldDuration: TimeInterval = 4
    // Final burst radius when the shield expires.
    var razorShieldExplosionRadius: CGFloat = 48
    // Enemies inside this radius are frozen, not destroyed.
    var freezeBurstRadius: CGFloat = 140
    // Time for the freeze wave to reach freezeBurstRadius.
    var freezeExpansionDuration: TimeInterval = 0.8
    // How long enemies remain frozen.
    var freezeDuration: TimeInterval = 12
    // Short post-thaw grace before an enemy can collide again.
    var freezeThawGraceDuration: TimeInterval = 0.5
    // Enemies inside this radius get pulled toward the well.
    var gravityWellRadius: CGFloat = 160
    // Arming delay before the pull starts.
    var gravityWellActivationDelay: TimeInterval = 0.5
    // How long the pull lasts.
    var gravityWellPullDuration: TimeInterval = 3
    // Kill radius at the center after enemies have been pulled inward.
    var gravityWellClearRadius: CGFloat = 32
    // First chain search range from the player.
    var chainLightningInitialRange: CGFloat = 140
    // Search range for each jump after the first hit.
    var chainLightningJumpRange: CGFloat = 96
    // Maximum chain hits.
    var chainLightningTargetLimit: Int = 6
    // Aura radius for slowed enemies.
    var timeDilationRadius: CGFloat = 120
    // How long the slowing aura stays active.
    var timeDilationDuration: TimeInterval = 6
    // Divides affected enemy speed; larger means slower enemies.
    var timeDilationMaximumSlowFactor: CGFloat = 8
    // Inner shove radius around the player.
    var timeDilationPushRadius: CGFloat = 48
    // Maximum outward shove distance for close enemies.
    var timeDilationMaximumPushDistance: CGFloat = 180
    // Pre-fire aiming/charge time before the wave releases.
    var powerWaveChargeDuration: TimeInterval = 0.6
    // Length of the cone-shaped wave.
    var powerWaveRange: CGFloat = 160
    // Cone width in degrees; 360 becomes a full circle.
    var powerWaveFanAngleDegrees: CGFloat = 60
    // Time for the cone to expand to full range.
    var powerWaveExpansionDuration: TimeInterval = 0.24
    // Maximum traced path length across bounces.
    var ricochetLanceRange: CGFloat = 560
    // Forgiving beam thickness used for collision along the traced path.
    var ricochetLanceBeamWidth: CGFloat = 18
    // Maximum wall bounces after the first segment.
    var ricochetLanceMaximumBounces: Int = 3
    // Time the traced beam remains active/visible.
    var ricochetLanceHoldDuration: TimeInterval = 0.5
    // Nova Bomb requires this many available enemies before it fires.
    var novaBombMinimumTargetCount: Int = 15
    // Fraction of available enemies selected once the minimum count is met.
    var novaBombTargetFraction: Double = 0.8
}

extension StartingWeaponConfiguration {
    func applying(chargeTier: WeaponPickupChargeTier) -> StartingWeaponConfiguration {
        guard chargeTier > .base else {
            return self
        }

        let level = CGFloat(chargeTier.rawValue)
        let rangeScale = 1 + level * 0.12
        let compactRangeScale = 1 + level * 0.08
        let durationScale = 1 + level * 0.15
        let targetBonus = chargeTier.rawValue
        var configuration = self

        configuration.shockwaveRadius *= rangeScale
        configuration.seekerTargetLimit += targetBonus
        configuration.seekerExplosionRadius *= compactRangeScale
        configuration.razorShieldRadius *= 1 + level * 0.06
        configuration.razorShieldDuration *= durationScale
        configuration.razorShieldExplosionRadius *= compactRangeScale
        configuration.freezeBurstRadius *= rangeScale
        configuration.freezeDuration *= durationScale
        configuration.gravityWellRadius *= rangeScale
        configuration.gravityWellClearRadius *= compactRangeScale
        configuration.chainLightningJumpRange *= rangeScale
        configuration.chainLightningTargetLimit += targetBonus
        configuration.timeDilationRadius *= compactRangeScale
        configuration.timeDilationDuration *= durationScale
        configuration.timeDilationMaximumPushDistance *= compactRangeScale
        configuration.powerWaveRange *= rangeScale
        configuration.powerWaveFanAngleDegrees = min(360, configuration.powerWaveFanAngleDegrees + level * 6)
        configuration.ricochetLanceBeamWidth *= compactRangeScale
        configuration.ricochetLanceMaximumBounces += targetBonus
        configuration.novaBombMinimumTargetCount += targetBonus * 3
        configuration.novaBombTargetFraction = min(1, configuration.novaBombTargetFraction + Double(targetBonus) * 0.08)

        return configuration
    }
}

struct WeaponResolution: Equatable {
    var destroyedEnemyIDs: Set<Int> = []
    var frozenEnemyIDs: Set<Int> = []
    var gravityWellEnemyIDs: Set<Int> = []
    var chainLightningEnemyIDs: [Int] = []
}

struct WeaponEffectTiming: Equatable {
    // Visual timing shared by projectile and wave effects. These values should make
    // effects readable; they do not decide which enemies are hit.
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
        case .flameTrail, .warpDash, .powerWave, .ricochetLance:
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

    func seekerExplosionTargets(center: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let explosionCircle = CollisionCircle(center: center, radius: configuration.seekerExplosionRadius)
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
