import CoreGraphics
import XCTest
@testable import TiltArena

@MainActor
final class ArenaSceneEnemyLifecycleTests: XCTestCase {
    func testGravityWellEffectOriginUsesPlayableArenaCenter() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        let playerPosition = CGPoint(x: 40, y: 70)

        XCTAssertEqual(
            scene.weaponEffectOriginForTesting(kind: .gravityWell, playerPosition: playerPosition),
            CGPoint(x: scene.currentPlayableRect.midX, y: scene.currentPlayableRect.midY)
        )
        XCTAssertEqual(
            scene.weaponEffectOriginForTesting(kind: .shockwave, playerPosition: playerPosition),
            playerPosition
        )
    }

    func testGravityWellDestroysCenterEnemyOnActivation() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
        let center = CGPoint(x: scene.currentPlayableRect.midX, y: scene.currentPlayableRect.midY)
        let centerEnemy = ArenaEnemy(id: 100, position: center, radius: 10, speed: 0)
        let outerEnemy = ArenaEnemy(
            id: 101,
            position: CGPoint(x: center.x + 70, y: center.y),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(centerEnemy)
        scene.addEnemyForTesting(outerEnemy)
        scene.activateGravityWellForTesting(
            center: center,
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
}
