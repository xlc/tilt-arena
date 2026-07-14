import CoreGraphics
import XCTest
@testable import TiltArena

@MainActor
final class ArenaSceneEnemyLifecycleTests: XCTestCase {
    func testGravityWellDestroysPickupLocationEnemyOnActivation() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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

    func testPostWeaponSafetyHonorsMinimumEffectTravelDuration() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
        let configuration = StartingWeaponConfiguration(timeDilationDuration: 0)

        scene.activateTimeDilationAuraForTesting(configuration: configuration)

        XCTAssertFalse(scene.isTimeDilationAuraActiveForTesting)
        XCTAssertTrue(scene.isPostWeaponSafeForTesting)
    }

    func testFlameTrailResolvesBurnBeforeEnemyCanDamagePlayerOrQueueDuplicateBursts() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
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
}
