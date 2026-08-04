import XCTest
@testable import TiltArena

final class StartingWeaponResolverTests: XCTestCase {
    func testRuntimeConfigurationSanitizesExtremeAndNonfiniteValuesOnAssignment() {
        var resolver = StartingWeaponResolver()

        resolver.configuration = StartingWeaponConfiguration(
            shockwaveRadius: .infinity,
            shockwaveExpansionDuration: .infinity,
            seekerTargetLimit: .max,
            ricochetLanceMaximumBounces: .max,
            ricochetLanceHoldDuration: .infinity
        )

        XCTAssertEqual(resolver.configuration.shockwaveRadius, 0)
        XCTAssertEqual(resolver.configuration.shockwaveExpansionDuration, 0)
        XCTAssertEqual(resolver.configuration.seekerTargetLimit, WeaponRuntimeSafetyLimits.maximumTargetCount)
        XCTAssertEqual(
            resolver.configuration.ricochetLanceMaximumBounces,
            WeaponRuntimeSafetyLimits.maximumRicochetBounceCount
        )
        XCTAssertEqual(resolver.configuration.ricochetLanceHoldDuration, 0)
    }

    func testDefaultShockwaveTuningKeepsWaveReadableAndLargerThanShieldBurst() {
        let configuration = StartingWeaponConfiguration()

        XCTAssertGreaterThan(configuration.shockwaveRadius, configuration.razorShieldExplosionRadius)
        XCTAssertGreaterThan(configuration.shockwaveExpansionDuration, 0)
        XCTAssertGreaterThanOrEqual(configuration.shockwaveHoldDuration, 0)
        XCTAssertLessThanOrEqual(configuration.shockwaveHoldDuration, configuration.shockwaveExpansionDuration)
    }

    func testWeaponSpriteSheetMapsWeaponsToIconAndEffectRows() {
        XCTAssertEqual(WeaponSpriteSheet.assetName, "WeaponSprites")
        XCTAssertEqual(WeaponSpriteSheet.rowCount, 2)
        XCTAssertEqual(WeaponSpriteSheet.columnCount, WeaponKind.allCases.count)

        let cellWidth = 1 / CGFloat(WeaponKind.allCases.count)
        for (column, kind) in WeaponKind.allCases.enumerated() {
            let x = CGFloat(column) * cellWidth

            XCTAssertEqual(WeaponSpriteSheet.column(for: kind), column)
            XCTAssertEqual(
                WeaponSpriteSheet.textureRect(for: kind, role: .icon),
                CGRect(x: x, y: 0.5, width: cellWidth, height: 0.5)
            )
            XCTAssertEqual(
                WeaponSpriteSheet.textureRect(for: kind, role: .effect),
                CGRect(x: x, y: 0, width: cellWidth, height: 0.5)
            )
        }
    }

    func testDefaultWeaponTuningKeepsWeaponFamiliesInDistinctRoles() {
        let configuration = StartingWeaponConfiguration()
        let flameTrailConfiguration = FlameTrailConfiguration()

        XCTAssertGreaterThan(configuration.seekerExplosionRadius, 0)
        XCTAssertGreaterThan(configuration.seekerTravelSpeed, 0)
        XCTAssertGreaterThan(configuration.razorShieldExplosionRadius, configuration.razorShieldRadius)
        XCTAssertGreaterThan(configuration.freezeBurstRadius, configuration.shockwaveRadius)
        XCTAssertGreaterThan(configuration.freezeDuration, configuration.freezeExpansionDuration)
        XCTAssertGreaterThan(configuration.gravityWellRadius, configuration.gravityWellClearRadius)
        XCTAssertGreaterThan(configuration.gravityWellPullDuration, configuration.gravityWellActivationDelay)
        XCTAssertGreaterThan(configuration.chainLightningInitialRange, configuration.chainLightningJumpRange)
        XCTAssertGreaterThan(configuration.chainLightningTargetLimit, configuration.seekerTargetLimit)
        XCTAssertGreaterThan(flameTrailConfiguration.segmentLifetime, flameTrailConfiguration.duration)
        XCTAssertGreaterThan(flameTrailConfiguration.segmentRadius, 0)
        XCTAssertGreaterThan(flameTrailConfiguration.speedMultiplier, 1)
        XCTAssertGreaterThan(configuration.timeDilationRadius, configuration.timeDilationPushRadius)
        XCTAssertGreaterThan(configuration.timeDilationDuration, 0)
        XCTAssertGreaterThan(configuration.timeDilationMaximumSlowFactor, 1)
        XCTAssertGreaterThan(configuration.powerWaveRange, configuration.timeDilationPushRadius)
        XCTAssertGreaterThan(configuration.powerWaveFanAngleDegrees, 0)
        XCTAssertLessThanOrEqual(configuration.powerWaveFanAngleDegrees, 360)
        XCTAssertGreaterThan(configuration.ricochetLanceBeamWidth, 0)
        XCTAssertEqual(configuration.ricochetLanceMaximumBounces, 1)
        XCTAssertGreaterThan(configuration.ricochetLanceHoldDuration, 0)
        XCTAssertEqual(configuration.novaBombTargetFraction, 0.5)
    }

    func testBaseWeaponConfigurationPreservesEveryConfiguredValue() {
        let base = StartingWeaponConfiguration(
            shockwaveRadius: 103,
            seekerTargetLimit: 7,
            ricochetLanceMaximumBounces: 3,
            novaBombTargetFraction: 0.4
        )

        XCTAssertEqual(base.applying(chargeTier: .base), base)
    }

    func testChargedWeaponConfigurationAppliesMeaningfulUpgradeFromConfiguredBase() {
        let base = StartingWeaponConfiguration(
            shockwaveRadius: 100,
            seekerTargetLimit: 4,
            chainLightningTargetLimit: 6,
            ricochetLanceMaximumBounces: 3,
            novaBombTargetFraction: 0.4
        )

        let charged = base.applying(chargeTier: .charged)
        let overcharged = base.applying(chargeTier: .overcharged)

        XCTAssertGreaterThan(charged.shockwaveRadius, base.shockwaveRadius)
        XCTAssertGreaterThan(overcharged.shockwaveRadius, charged.shockwaveRadius)
        XCTAssertGreaterThan(charged.seekerTargetLimit, base.seekerTargetLimit)
        XCTAssertGreaterThan(overcharged.seekerTargetLimit, charged.seekerTargetLimit)
        XCTAssertGreaterThan(charged.chainLightningTargetLimit, base.chainLightningTargetLimit)
        XCTAssertGreaterThan(overcharged.chainLightningTargetLimit, charged.chainLightningTargetLimit)
        XCTAssertEqual(charged.ricochetLanceMaximumBounces, 4)
        XCTAssertEqual(overcharged.ricochetLanceMaximumBounces, 5)
        XCTAssertEqual(charged.novaBombTargetFraction, 0.65, accuracy: 0.0001)
        XCTAssertEqual(overcharged.novaBombTargetFraction, 0.9, accuracy: 0.0001)
    }

    func testChargedNovaBombTargetFractionIsCappedAtOne() {
        let base = StartingWeaponConfiguration(novaBombTargetFraction: 0.8)

        XCTAssertEqual(base.applying(chargeTier: .charged).novaBombTargetFraction, 1)
        XCTAssertEqual(base.applying(chargeTier: .overcharged).novaBombTargetFraction, 1)
    }

    func testRazorShieldMergePreservesStrongestCoverage() {
        let current = StartingWeaponConfiguration(
            razorShieldRadius: 64,
            razorShieldDuration: 1,
            razorShieldExplosionRadius: 20
        )
        let incoming = StartingWeaponConfiguration(
            razorShieldRadius: 12,
            razorShieldDuration: 8,
            razorShieldExplosionRadius: 80
        )

        let merged = current.mergingRazorShield(with: incoming)

        XCTAssertEqual(merged.razorShieldRadius, current.razorShieldRadius)
        XCTAssertEqual(merged.razorShieldDuration, incoming.razorShieldDuration)
        XCTAssertEqual(merged.razorShieldExplosionRadius, incoming.razorShieldExplosionRadius)
    }

    func testTimeDilationMergePreservesStrongestControl() {
        let current = StartingWeaponConfiguration(
            timeDilationRadius: 180,
            timeDilationDuration: 1,
            timeDilationMaximumSlowFactor: 9,
            timeDilationPushRadius: 20,
            timeDilationMaximumPushDistance: 40
        )
        let incoming = StartingWeaponConfiguration(
            timeDilationRadius: 40,
            timeDilationDuration: 8,
            timeDilationMaximumSlowFactor: 2,
            timeDilationPushRadius: 60,
            timeDilationMaximumPushDistance: 200
        )

        let merged = current.mergingTimeDilation(with: incoming)

        XCTAssertEqual(merged.timeDilationRadius, current.timeDilationRadius)
        XCTAssertEqual(merged.timeDilationDuration, incoming.timeDilationDuration)
        XCTAssertEqual(merged.timeDilationMaximumSlowFactor, current.timeDilationMaximumSlowFactor)
        XCTAssertEqual(merged.timeDilationPushRadius, incoming.timeDilationPushRadius)
        XCTAssertEqual(merged.timeDilationMaximumPushDistance, incoming.timeDilationMaximumPushDistance)
    }

    func testShockwaveClearsEnemiesInsideRadius() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(shockwaveRadius: 50)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 60, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .shockwave,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [1])
    }

    func testSeekerSwarmClearsNearestCappedEnemies() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(seekerTargetLimit: 2)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 200, y: 0)),
            enemy(id: 2, position: CGPoint(x: 20, y: 0)),
            enemy(id: 3, position: CGPoint(x: 60, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .seekerSwarm,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [2, 3])
    }

    func testSeekerExplosionTargetsEnemiesInsideExplosionRadius() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(seekerExplosionRadius: 30)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 22, y: 0)),
            enemy(id: 2, position: CGPoint(x: 38, y: 0)),
            enemy(id: 3, position: CGPoint(x: 64, y: 0))
        ]

        XCTAssertEqual(
            resolver.seekerExplosionTargets(center: .zero, enemies: enemies),
            [1, 2]
        )
    }

    func testRazorShieldClearsContactEnemies() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(razorShieldRadius: 24)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 28, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .razorShield,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolver.shieldTargets(playerPosition: .zero, enemies: enemies), [1])
    }

    func testRazorShieldExplosionUsesExpandedExpiryRadius() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(
                razorShieldRadius: 24,
                razorShieldExplosionRadius: 40
            )
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 28, y: 0)),
            enemy(id: 2, position: CGPoint(x: 46, y: 0)),
            enemy(id: 3, position: CGPoint(x: 80, y: 0))
        ]

        XCTAssertEqual(resolver.shieldTargets(playerPosition: .zero, enemies: enemies), [1])
        XCTAssertEqual(resolver.shieldExplosionTargets(playerPosition: .zero, enemies: enemies), [1, 2])
    }

    func testFreezeBurstFreezesEnemiesInsideRadiusWithoutDestroyingThem() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(freezeBurstRadius: 50)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .freezeBurst,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [1])
    }

    func testFreezeBurstHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .freezeBurst,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
    }

    func testGravityWellTargetsEnemiesInsideRadiusIncludingFrozenEnemiesWithoutDestroyingThem() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(gravityWellRadius: 50)
        )
        var frozenEnemy = enemy(id: 3, position: CGPoint(x: 20, y: 0))
        frozenEnemy.freeze(duration: 1, thawGraceDuration: 0.35)
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0)),
            frozenEnemy
        ]

        let resolution = resolver.resolve(
            kind: .gravityWell,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [1, 3])
    }

    func testGravityWellCollapseCanClearFrozenEnemiesInsideClearRadius() {
        var frozenEnemy = enemy(id: 3, position: CGPoint(x: 20, y: 0))
        frozenEnemy.freeze(duration: 1, thawGraceDuration: 0.35)
        let state = GravityWellState(
            center: .zero,
            enemyIDs: [1, 2, 3],
            timeRemaining: 0,
            clearRadius: 24
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 12, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0)),
            frozenEnemy
        ]

        XCTAssertEqual(
            state.collapseTargets(enemies: enemies),
            [1, 3]
        )
    }

    func testGravityWellHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .gravityWell,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
    }

    func testChainLightningDestroysOrderedChainedTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 100, y: 0)),
            enemy(id: 2, position: CGPoint(x: 150, y: 0)),
            enemy(id: 3, position: CGPoint(x: 210, y: 0)),
            enemy(id: 4, position: CGPoint(x: 60, y: 90))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [1, 2, 3])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [1, 2, 3])
    }

    func testChainLightningStopsWhenNextTargetIsOutOfJumpRange() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 100, y: 0)),
            enemy(id: 2, position: CGPoint(x: 210, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [1])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [1])
    }

    func testChainLightningRespectsTargetLimit() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(chainLightningTargetLimit: 2)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 80, y: 0)),
            enemy(id: 2, position: CGPoint(x: 130, y: 0)),
            enemy(id: 3, position: CGPoint(x: 180, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [1, 2])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [1, 2])
    }

    func testChainLightningRequiresFirstTargetInsideInitialRange() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 141, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testChainLightningHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testNovaBombSelectionIsHandledOutsideResolver() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 200, y: 0)),
            enemy(id: 2, position: CGPoint(x: -40, y: 70)),
            enemy(id: 3, position: CGPoint(x: 0, y: -120))
        ]

        let resolution = resolver.resolve(
            kind: .novaBomb,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testRicochetLanceSelectionIsHandledOutsideResolver() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .ricochetLance,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
    }

    func testFlameTrailDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .flameTrail,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
    }

    func testTimeDilationDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .warpDash,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
    }

    func testPowerWaveDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .powerWave,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
    }

    func testNovaBombHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .novaBomb,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testWeaponEffectTimingKeepsProjectileImpactsTrackable() {
        let timing = WeaponEffectTiming(
            projectileSpeed: 500,
            waveSpeed: 600,
            minimumTravelDuration: 0.08,
            maximumProjectileTravelDuration: 0.42,
            maximumWaveTravelDuration: 0.72
        )

        XCTAssertEqual(
            timing.projectileDuration(from: .zero, to: CGPoint(x: 100, y: 0)),
            0.2,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            timing.projectileDuration(from: .zero, to: CGPoint(x: 1_000, y: 0)),
            0.42,
            accuracy: 0.0001
        )
    }

    func testWeaponEffectTimingAccumulatesChainImpactDelays() {
        let timing = WeaponEffectTiming(
            projectileSpeed: 500,
            waveSpeed: 600,
            minimumTravelDuration: 0.08,
            maximumProjectileTravelDuration: 0.42,
            maximumWaveTravelDuration: 0.72
        )

        let delays = timing.chainImpactDelays(
            origin: .zero,
            targets: [
                CGPoint(x: 50, y: 0),
                CGPoint(x: 150, y: 0),
                CGPoint(x: 150, y: 40)
            ]
        )

        XCTAssertEqual(delays.count, 3)
        XCTAssertEqual(delays[0], 0.1, accuracy: 0.0001)
        XCTAssertEqual(delays[1], 0.3, accuracy: 0.0001)
        XCTAssertEqual(delays[2], 0.38, accuracy: 0.0001)
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 8, speed: 0)
    }
}
