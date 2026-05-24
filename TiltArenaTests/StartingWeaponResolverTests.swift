import XCTest
@testable import TiltArena

final class StartingWeaponResolverTests: XCTestCase {
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
            timeRemaining: 0
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 12, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0)),
            frozenEnemy
        ]

        XCTAssertEqual(
            state.collapseTargets(enemies: enemies, clearRadius: 24),
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
            enemy(id: 1, position: CGPoint(x: 129, y: 0))
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

    func testNovaBombClearsAllEnemies() {
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

        XCTAssertEqual(resolution.destroyedEnemyIDs, [1, 2, 3])
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

    func testWarpDashDoesNotInstantlyResolveTargets() {
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

    func testDecoyBeaconDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .decoyBeacon,
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
