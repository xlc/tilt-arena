import CoreGraphics
import XCTest
@testable import TiltArena

final class ChaserEnemyTests: XCTestCase {
    func testChaserMovesTowardPlayerWithoutOvershooting() {
        var enemy = ChaserEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 100)

        enemy.advance(toward: CGPoint(x: 30, y: 0), deltaTime: 1)

        XCTAssertEqual(enemy.position.x, 30, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 0, accuracy: 0.0001)
    }

    func testSpawnPlannerSkipsPositionsInsidePlayerSafetyRadius() {
        var planner = ChaserSpawnPlanner()
        let config = ClassicRunConfiguration(playerSafetyRadius: 120)
        let playableRect = CGRect(x: 0, y: 0, width: 320, height: 600)
        let playerPosition = CGPoint(x: 0, y: 75)

        let enemy = planner.spawnChaser(
            in: playableRect,
            avoiding: playerPosition,
            configuration: config
        )

        guard let enemy else {
            return XCTFail("Expected a safe spawn candidate.")
        }

        XCTAssertTrue(planner.isSafeSpawn(enemy.position, avoiding: playerPosition, safetyRadius: 120))
    }

    func testCircleCollisionUsesCombinedRadii() {
        let player = CollisionCircle(center: CGPoint(x: 0, y: 0), radius: 9)
        let touchingEnemy = CollisionCircle(center: CGPoint(x: 17, y: 0), radius: 8)
        let distantEnemy = CollisionCircle(center: CGPoint(x: 18, y: 0), radius: 8)

        XCTAssertTrue(player.intersects(touchingEnemy))
        XCTAssertFalse(player.intersects(distantEnemy))
    }

    func testPlayerHitRadiusIsSmallerThanVisibleCraft() {
        let config = ClassicRunConfiguration(playerVisualRadius: 14, playerHitRadiusScale: 0.65)

        XCTAssertLessThan(config.playerHitRadius, config.playerVisualRadius)
        XCTAssertEqual(config.playerHitRadius, 9.1, accuracy: 0.0001)
    }
}
