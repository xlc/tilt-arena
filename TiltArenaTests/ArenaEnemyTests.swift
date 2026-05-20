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

    func testFrozenEnemyPausesMovementUntilThawed() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 100)

        enemy.freeze(duration: 1)
        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.5)

        XCTAssertTrue(enemy.isFrozen)
        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.5)
        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.1)

        XCTAssertFalse(enemy.isFrozen)
        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)
    }

    func testFrozenEnemyPreservesBehaviorAndFormationIdentity() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 10),
            radius: 8,
            speed: 90,
            behavior: .formationLine(velocity: CGVector(dx: 40, dy: -10), formationID: 4)
        )

        enemy.freeze(duration: 0.25)
        enemy.advance(toward: CGPoint(x: 1000, y: 1000), deltaTime: 0.25)

        XCTAssertFalse(enemy.isFrozen)
        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 10, accuracy: 0.0001)
        XCTAssertEqual(enemy.formationID, 4)
        XCTAssertTrue(enemy.isLinearPatternEnemy)

        enemy.advance(toward: CGPoint(x: 1000, y: 1000), deltaTime: 0.5)

        XCTAssertEqual(enemy.position.x, 20, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 5, accuracy: 0.0001)
        XCTAssertEqual(enemy.formationID, 4)
    }

    func testGravityPullMovesTowardTargetWithoutOvershootingOrMovingFrozenEnemies() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 0)

        enemy.pullToward(CGPoint(x: 30, y: 40), distance: 25)

        XCTAssertEqual(enemy.position.x, 15, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 20, accuracy: 0.0001)

        enemy.pullToward(CGPoint(x: 30, y: 40), distance: 100)

        XCTAssertEqual(enemy.position.x, 30, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 40, accuracy: 0.0001)

        enemy.freeze(duration: 1)
        enemy.pullToward(.zero, distance: 100)

        XCTAssertEqual(enemy.position.x, 30, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 40, accuracy: 0.0001)
    }

    func testHunterDotUsesPredictedPlayerPosition() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 0),
            radius: 8,
            speed: 100,
            behavior: .hunterDot(predictionLead: 1, previousTarget: CGPoint(x: 100, y: 0))
        )

        enemy.advance(toward: CGPoint(x: 100, y: 100), deltaTime: 1)

        XCTAssertEqual(enemy.position.x, 44.7214, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 89.4427, accuracy: 0.0001)
        XCTAssertNil(enemy.formationID)
        XCTAssertFalse(enemy.isLinearPatternEnemy)
        XCTAssertTrue(enemy.isHunterDot)
    }

    func testPaddleTrapBarDoesNotMoveAndExpires() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 80, y: 120),
            radius: 8,
            speed: 0,
            behavior: .paddleTrapBar(trapID: 7, remainingLifetime: 2)
        )

        enemy.advance(toward: CGPoint(x: 300, y: 300), deltaTime: 1.5)

        XCTAssertEqual(enemy.position.x, 80, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 120, accuracy: 0.0001)
        XCTAssertEqual(enemy.paddleTrapID, 7)
        XCTAssertNil(enemy.formationID)
        XCTAssertFalse(enemy.isLinearPatternEnemy)
        XCTAssertTrue(enemy.isPaddleTrap)
        XCTAssertFalse(enemy.isExpired)

        enemy.advance(toward: CGPoint(x: 300, y: 300), deltaTime: 0.5)

        XCTAssertTrue(enemy.isExpired)
    }

    func testPaddleTrapDotBouncesInsideBounds() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 9, y: 9),
            radius: 8,
            speed: 4,
            behavior: .paddleTrapDot(
                trapID: 3,
                velocity: CGVector(dx: 4, dy: 4),
                bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                remainingLifetime: 2
            )
        )

        enemy.advance(toward: CGPoint(x: 100, y: 100), deltaTime: 0.5)

        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 10, accuracy: 0.0001)
        XCTAssertEqual(enemy.paddleTrapID, 3)
        XCTAssertNil(enemy.formationID)
        XCTAssertFalse(enemy.isLinearPatternEnemy)
        XCTAssertTrue(enemy.isPaddleTrap)

        guard case let .paddleTrapDot(_, velocity, _, remainingLifetime) = enemy.behavior else {
            XCTFail("Expected Paddle Trap dot behavior.")
            return
        }

        XCTAssertEqual(velocity.dx, -4, accuracy: 0.0001)
        XCTAssertEqual(velocity.dy, -4, accuracy: 0.0001)
        XCTAssertEqual(remainingLifetime, 1.5, accuracy: 0.0001)
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
