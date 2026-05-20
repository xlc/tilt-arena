import CoreGraphics
import XCTest
@testable import TiltArena

final class ArenaEnemyTests: XCTestCase {
    func testEnemyMovesTowardPlayerWithoutOvershooting() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 100)

        enemy.advance(toward: CGPoint(x: 30, y: 0), deltaTime: 1)

        XCTAssertEqual(enemy.position.x, 30, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 0, accuracy: 0.0001)
    }

    func testEnemyDoesNotMoveWithNegativeSpeedOrDeltaTime() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 10, y: 0), radius: 8, speed: -100)

        enemy.advance(toward: CGPoint(x: 30, y: 0), deltaTime: 1)
        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)

        enemy.speed = 100
        enemy.advance(toward: CGPoint(x: 30, y: 0), deltaTime: -1)
        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)
    }

    func testFormationLineMovesAlongVelocity() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 10),
            radius: 8,
            speed: 90,
            behavior: .formationLine(velocity: CGVector(dx: 40, dy: -10), formationID: 4)
        )

        enemy.advance(toward: CGPoint(x: 1000, y: 1000), deltaTime: 0.5)

        XCTAssertEqual(enemy.position.x, 20, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 5, accuracy: 0.0001)
        XCTAssertEqual(enemy.formationID, 4)
    }

    func testArrowRushMovesAlongVelocity() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: -20, y: 50),
            radius: 8,
            speed: 150,
            behavior: .arrowRush(velocity: CGVector(dx: 120, dy: 30))
        )

        enemy.advance(toward: CGPoint(x: 0, y: 0), deltaTime: 0.25)

        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 57.5, accuracy: 0.0001)
        XCTAssertNil(enemy.formationID)
        XCTAssertTrue(enemy.isLinearPatternEnemy)
    }

    func testMineDotDoesNotMove() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 80, y: 120),
            radius: 8,
            speed: 0,
            behavior: .mineDot
        )

        enemy.advance(toward: CGPoint(x: 300, y: 300), deltaTime: 10)

        XCTAssertEqual(enemy.position.x, 80, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 120, accuracy: 0.0001)
        XCTAssertNil(enemy.formationID)
        XCTAssertFalse(enemy.isLinearPatternEnemy)
        XCTAssertTrue(enemy.isMineDot)
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
