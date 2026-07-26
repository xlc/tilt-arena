import CoreGraphics
import XCTest
@testable import TiltArena

@MainActor
final class ArenaSceneEnemyLifecycleTests: XCTestCase {
    func testGravityWellDestroysPickupLocationEnemyOnActivation() {
        let scene = makeActiveScene()
        let pickupPosition = CGPoint(x: 80, y: 90)
        let centerEnemy = ArenaEnemy(id: 100, position: pickupPosition, radius: 10, speed: 0)
        let outerEnemy = ArenaEnemy(
            id: 101,
            position: CGPoint(x: pickupPosition.x + 70, y: pickupPosition.y),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(centerEnemy)
        scene.addEnemyForTesting(outerEnemy)
        scene.activateGravityWellForTesting(
            center: pickupPosition,
            enemyIDs: [centerEnemy.id, outerEnemy.id],
            configuration: StartingWeaponConfiguration(gravityWellClearRadius: 24)
        )

        XCTAssertEqual(scene.enemyIDsForTesting, [outerEnemy.id])
    }

    func testSeekerSwarmLeavesTargetLiveBeforeImpact() {
        let scene = makeActiveScene()
        let target = ArenaEnemy(
            id: 100,
            position: CGPoint(x: 160, y: 120),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(target)
        scene.playSeekerSwarmForTesting(enemyIDs: [target.id], from: CGPoint(x: 40, y: 40))

        XCTAssertEqual(scene.enemyIDsForTesting, [target.id])
        XCTAssertEqual(scene.enemyNodeCountForTesting, 1)
    }

    func testSeekerExplosionUsesStoredImpactLocationAfterOriginalTargetDies() {
        let scene = makeActiveScene()
        let target = ArenaEnemy(
            id: 100,
            position: CGPoint(x: 160, y: 120),
            radius: 10,
            speed: 0
        )
        let nearbyEnemy = ArenaEnemy(
            id: 101,
            position: CGPoint(x: 178, y: 120),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(target)
        scene.addEnemyForTesting(nearbyEnemy)
        scene.removeEnemyForTesting(id: target.id)

        XCTAssertEqual(scene.enemyIDsForTesting, [nearbyEnemy.id])

        scene.resolveSeekerExplosionForTesting(
            at: WeaponImpactTarget(id: target.id, position: target.position)
        )

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertEqual(scene.enemyNodeCountForTesting, 0)
    }

    func testPostWeaponSafetyTemporarilySuppressesEnemyCollision() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 200, position: playerPosition, radius: 10, speed: 0)

        scene.addEnemyForTesting(enemy)
        scene.grantPostWeaponSafetyForTesting()
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertFalse(scene.isRunGameOverForTesting)

        scene.advancePostWeaponSafetyForTesting(deltaTime: 1)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertTrue(scene.isRunGameOverForTesting)
    }

    func testSweptCollisionCatchesEnemyCrossingPlayerBetweenFrameEndpoints() throws {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(
            id: 205,
            position: CGPoint(x: playerPosition.x + 20, y: playerPosition.y),
            radius: 4,
            speed: 0
        )
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [
                enemy.id: CGPoint(x: playerPosition.x - 20, y: playerPosition.y)
            ]
        )

        XCTAssertTrue(scene.isRunGameOverForTesting)
        let collision = try XCTUnwrap(scene.lastDeathCollisionSnapshotForTesting)
        XCTAssertEqual(collision.playerPosition.x, playerPosition.x, accuracy: 0.0001)
        XCTAssertEqual(
            abs(collision.enemyPosition.x - playerPosition.x),
            ClassicRunConfiguration().playerHitRadius + enemy.radius,
            accuracy: 0.0001
        )
    }

    func testSweptCollisionDoesNotRetroactivelyKillAcrossProtectedMovement() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(
            id: 207,
            position: CGPoint(x: playerPosition.x + 20, y: playerPosition.y),
            radius: 4,
            speed: 0
        )
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [
                enemy.id: CGPoint(x: playerPosition.x - 20, y: playerPosition.y)
            ],
            allowsSweptCollision: false
        )

        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testSweptCollisionDoesNotRetroactivelyKillAcrossEnemySpawnGrace() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(
            id: 208,
            position: CGPoint(x: playerPosition.x + 20, y: playerPosition.y),
            radius: 4,
            speed: 0
        )
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [:]
        )

        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testEnemyLeavingSpawnGraceCanStillHitAtFrameEndpoint() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 209, position: playerPosition, radius: 4, speed: 0)
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [:]
        )

        XCTAssertTrue(scene.isRunGameOverForTesting)
    }

    func testFrozenEnemyCanBeShatteredBeforeThawWindow() {
        let scene = makeActiveScene()
        let frozenEnemy = ArenaEnemy(
            id: 206,
            position: scene.playerPositionForTesting,
            radius: 4,
            speed: 0,
            frozenTimeRemaining: 4
        )
        scene.addEnemyForTesting(frozenEnemy)

        scene.shatterFrozenContactEnemiesForTesting()

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testControlAndArenaClearsSuppressSplitterChildren() {
        for weaponKind in [WeaponKind.freezeBurst, .gravityWell, .novaBomb] {
            let scene = makeActiveScene()
            let splitter = ArenaEnemy(
                id: 207,
                position: CGPoint(x: 80, y: 80),
                radius: 8,
                speed: 70,
                behavior: .splitter
            )
            scene.addEnemyForTesting(splitter)

            scene.destroyEnemiesForTesting(ids: [splitter.id], weaponKind: weaponKind)

            XCTAssertTrue(scene.enemyIDsForTesting.isEmpty, "\(weaponKind) should fully clear splitters")
        }
    }

    func testDirectDamageStillTriggersSplitterChildren() {
        let scene = makeActiveScene()
        let splitter = ArenaEnemy(
            id: 208,
            position: CGPoint(x: 80, y: 80),
            radius: 8,
            speed: 70,
            behavior: .splitter
        )
        scene.addEnemyForTesting(splitter)

        scene.destroyEnemiesForTesting(ids: [splitter.id], weaponKind: .shockwave)

        XCTAssertEqual(scene.enemyIDsForTesting.count, 2)
        XCTAssertFalse(scene.enemyIDsForTesting.contains(splitter.id))
    }

    func testPostWeaponSafetyHonorsMinimumEffectTravelDuration() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 201, position: playerPosition, radius: 10, speed: 0)

        scene.addEnemyForTesting(enemy)
        scene.grantPostWeaponSafetyForTesting(.novaBomb, minimumDuration: 1.5)
        scene.advancePostWeaponSafetyForTesting(deltaTime: 1)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertFalse(scene.isRunGameOverForTesting)

        scene.advancePostWeaponSafetyForTesting(deltaTime: 0.51)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertTrue(scene.isRunGameOverForTesting)
    }

    func testNovaClearResolvesBeforeCollisionWhenDroppedFrameCrossesDeadline() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 204, position: playerPosition, radius: 10, speed: 0)

        scene.addEnemyForTesting(enemy)
        scene.activateNovaBombForTesting(enemyIDs: [enemy.id])
        scene.updateActiveRunForTesting(
            deltaTime: scene.weaponEffectTiming.maximumWaveTravelDuration + 0.01
        )

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testRazorShieldResolvesContactBeforeEnemyCanDamagePlayerOrQueueDuplicateBolts() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 201, position: playerPosition, radius: 10, speed: 0)
        let configuration = StartingWeaponConfiguration(
            razorShieldRadius: 24,
            razorShieldDuration: 1
        )

        scene.addEnemyForTesting(enemy)
        scene.activateRazorShieldForTesting(configuration: configuration)
        scene.updateRazorShieldForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)
        XCTAssertFalse(scene.isRunGameOverForTesting)

        let effectNodeCountAfterContact = scene.weaponEffectNodeCountForTesting
        scene.updateRazorShieldForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, effectNodeCountAfterContact)
    }

    func testZeroDurationRazorShieldCompletesImmediatelyWithExplosionSafety() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 202, position: playerPosition, radius: 10, speed: 0)
        let configuration = StartingWeaponConfiguration(
            razorShieldRadius: 24,
            razorShieldDuration: 0,
            razorShieldExplosionRadius: 48
        )

        scene.addEnemyForTesting(enemy)
        scene.activateRazorShieldForTesting(configuration: configuration)

        XCTAssertFalse(scene.isRazorShieldActiveForTesting)
        XCTAssertTrue(scene.isPostWeaponSafeForTesting)
        XCTAssertGreaterThan(scene.weaponEffectNodeCountForTesting, 0)

        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)
        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testZeroDurationTimeDilationCompletesWithoutLeavingAuraState() {
        let scene = makeActiveScene()
        let configuration = StartingWeaponConfiguration(timeDilationDuration: 0)

        scene.activateTimeDilationAuraForTesting(configuration: configuration)

        XCTAssertFalse(scene.isTimeDilationAuraActiveForTesting)
        XCTAssertTrue(scene.isPostWeaponSafeForTesting)
    }

    func testFlameTrailResolvesBurnBeforeEnemyCanDamagePlayerOrQueueDuplicateBursts() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 203, position: playerPosition, radius: 10, speed: 0)
        let configuration = FlameTrailConfiguration(
            duration: 0.3,
            segmentLifetime: 1,
            segmentRadius: 16,
            segmentSpacing: 14,
            maxSegments: 4,
            invulnerabilityDuration: 0,
            speedMultiplier: 1
        )

        scene.addEnemyForTesting(enemy)
        scene.activateFlameTrailForTesting(configuration: configuration)
        scene.updateFlameTrailForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)
        XCTAssertFalse(scene.isRunGameOverForTesting)

        let effectNodeCountAfterBurn = scene.weaponEffectNodeCountForTesting
        scene.updateFlameTrailForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, effectNodeCountAfterBurn)
    }

    private func makeActiveScene() -> ArenaScene {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
        return scene
    }
}
