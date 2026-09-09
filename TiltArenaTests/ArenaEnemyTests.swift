import CoreGraphics
import XCTest
@testable import TiltArena

final class ArenaEnemyTests: XCTestCase {
    func testNonfiniteFreezeAndDeltaDoNotLeaveEnemyPermanentlyStopped() {
        var enemy = ArenaEnemy(id: 1, position: .zero, radius: 8, speed: 100)

        enemy.freeze(duration: .infinity)
        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: .infinity)
        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.1)

        XCTAssertFalse(enemy.isFrozen)
        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)
        XCTAssertTrue(enemy.position.y.isFinite)
    }

    func testPaddleDotIgnoresNonfiniteVelocityWithoutPoisoningPosition() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 5, y: 5),
            radius: 4,
            speed: 1,
            behavior: .paddleTrapDot(
                trapID: 1,
                velocity: CGVector(dx: CGFloat.infinity, dy: 1),
                bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                remainingLifetime: 2
            )
        )

        enemy.advance(toward: CGPoint.zero, deltaTime: 0.1)

        XCTAssertEqual(enemy.position, CGPoint(x: 5, y: 5))
        XCTAssertTrue(enemy.position.x.isFinite && enemy.position.y.isFinite)
    }

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

    func testEnemyMovementSpeedIncreasesWithMovementTime() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 0),
            radius: 8,
            speed: 100,
            speedRampPerSecond: 0.5,
            maximumSpeedMultiplier: 1.4
        )

        enemy.advance(toward: CGPoint(x: 1_000, y: 0), deltaTime: 1)
        XCTAssertEqual(enemy.position.x, 100, accuracy: 0.0001)

        enemy.advance(toward: CGPoint(x: 1_000, y: 0), deltaTime: 1)
        XCTAssertEqual(enemy.position.x, 240, accuracy: 0.0001)
    }

    func testExternalSpeedMultiplierSlowsMovementWithoutStoppingRamp() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 0),
            radius: 8,
            speed: 100,
            speedRampPerSecond: 1,
            maximumSpeedMultiplier: 2
        )

        enemy.advance(toward: CGPoint(x: 1_000, y: 0), deltaTime: 1, externalSpeedMultiplier: 0.25)
        enemy.advance(toward: CGPoint(x: 1_000, y: 0), deltaTime: 1, externalSpeedMultiplier: 0.25)

        XCTAssertEqual(enemy.position.x, 75, accuracy: 0.0001)
    }

    func testChaserMovementRespectsMaximumSpeedCap() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 100)

        enemy.advance(
            toward: CGPoint(x: 1_000, y: 0),
            deltaTime: 1,
            externalSpeedMultiplier: 2,
            maximumSpeed: 30
        )

        XCTAssertEqual(enemy.position.x, 30, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 0, accuracy: 0.0001)
    }

    func testLinearMovementRespectsMaximumSpeedCap() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 0),
            radius: 8,
            speed: 100,
            behavior: .arrowRush(velocity: CGVector(dx: 80, dy: 60))
        )

        enemy.advance(
            toward: .zero,
            deltaTime: 1,
            externalSpeedMultiplier: 2,
            maximumSpeed: 25
        )

        XCTAssertEqual(enemy.position.x, 20, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 15, accuracy: 0.0001)
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

    func testFrozenEnemyEntersHarmlessShatterableThawGraceBeforeMoving() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 100)

        enemy.freeze(duration: 1, thawGraceDuration: 0.35)
        XCTAssertFalse(enemy.canDamagePlayer)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 1)

        XCTAssertFalse(enemy.isFrozen)
        XCTAssertTrue(enemy.isThawing)
        XCTAssertTrue(enemy.isShatterableFrozen)
        XCTAssertFalse(enemy.canDamagePlayer)
        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.2)

        XCTAssertTrue(enemy.isThawing)
        XCTAssertFalse(enemy.canDamagePlayer)
        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.15)

        XCTAssertFalse(enemy.isThawing)
        XCTAssertFalse(enemy.isShatterableFrozen)
        XCTAssertTrue(enemy.canDamagePlayer)
        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.1)

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

    func testPlayerCollisionGracePreventsDamageWithoutStoppingMovement() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 0),
            radius: 4,
            speed: 100,
            playerCollisionGraceTimeRemaining: 0.5
        )

        XCTAssertTrue(enemy.isPlayerCollisionGraceActive)
        XCTAssertFalse(enemy.canDamagePlayer)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.25)

        XCTAssertEqual(enemy.position.x, 25, accuracy: 0.0001)
        XCTAssertTrue(enemy.isPlayerCollisionGraceActive)
        XCTAssertFalse(enemy.canDamagePlayer)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.25)

        XCTAssertEqual(enemy.position.x, 50, accuracy: 0.0001)
        XCTAssertFalse(enemy.isPlayerCollisionGraceActive)
        XCTAssertTrue(enemy.canDamagePlayer)
    }

    func testSplitSpawnGracePreventsMovementAndDamage() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 0, y: 0),
            radius: 4,
            speed: 100,
            behavior: .splitterChild,
            splitSpawnGraceTimeRemaining: 0.5
        )

        XCTAssertTrue(enemy.isSplitterChild)
        XCTAssertTrue(enemy.isSplitProtected)
        XCTAssertFalse(enemy.canDamagePlayer)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.25)

        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)
        XCTAssertTrue(enemy.isSplitProtected)
        XCTAssertFalse(enemy.canDamagePlayer)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.25)

        XCTAssertEqual(enemy.position.x, 0, accuracy: 0.0001)
        XCTAssertFalse(enemy.isSplitProtected)
        XCTAssertTrue(enemy.canDamagePlayer)

        enemy.advance(toward: CGPoint(x: 100, y: 0), deltaTime: 0.1)

        XCTAssertEqual(enemy.position.x, 10, accuracy: 0.0001)
    }

    func testGravityPullMovesTowardTargetWithoutOvershootingAndCanMoveFrozenEnemies() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 0, y: 0), radius: 8, speed: 0)

        enemy.pullToward(CGPoint(x: 30, y: 40), distance: 25)

        XCTAssertEqual(enemy.position.x, 15, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 20, accuracy: 0.0001)

        enemy.pullToward(CGPoint(x: 30, y: 40), distance: 100)

        XCTAssertEqual(enemy.position.x, 30, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 40, accuracy: 0.0001)

        enemy.freeze(duration: 1, thawGraceDuration: 0.35)
        enemy.pullToward(.zero, distance: 25)

        XCTAssertEqual(enemy.position.x, 15, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 20, accuracy: 0.0001)
        XCTAssertTrue(enemy.isFrozen)

        enemy.advance(toward: CGPoint(x: 100, y: 100), deltaTime: 0.5)

        XCTAssertEqual(enemy.position.x, 15, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 20, accuracy: 0.0001)
    }

    func testPushAwayMovesOutwardFromSource() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 3, y: 4), radius: 8, speed: 0)

        enemy.pushAway(from: .zero, distance: 10)

        XCTAssertEqual(enemy.position.x, 9, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 12, accuracy: 0.0001)
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

    func testHunterDotPredictionLeadIsFrameRateIndependent() {
        var longerFrameEnemy = ArenaEnemy(
            id: 1,
            position: .zero,
            radius: 8,
            speed: 100,
            behavior: .hunterDot(
                predictionLead: 0.5,
                previousTarget: CGPoint(x: 100, y: 90)
            )
        )
        var shorterFrameEnemy = ArenaEnemy(
            id: 2,
            position: .zero,
            radius: 8,
            speed: 100,
            behavior: .hunterDot(
                predictionLead: 0.5,
                previousTarget: CGPoint(x: 100, y: 95)
            )
        )

        longerFrameEnemy.advance(toward: CGPoint(x: 100, y: 100), deltaTime: 0.1)
        shorterFrameEnemy.advance(toward: CGPoint(x: 100, y: 100), deltaTime: 0.05)

        XCTAssertEqual(
            longerFrameEnemy.position.x / longerFrameEnemy.position.y,
            shorterFrameEnemy.position.x / shorterFrameEnemy.position.y,
            accuracy: 0.0001
        )
        XCTAssertEqual(longerFrameEnemy.position.x / longerFrameEnemy.position.y, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testFrozenHunterTracksPlayerWithoutMovingToAvoidStalePredictionOnThaw() {
        let target = CGPoint(x: 100, y: 80)
        var enemy = ArenaEnemy(
            id: 1,
            position: .zero,
            radius: 8,
            speed: 100,
            behavior: .hunterDot(
                predictionLead: 0.5,
                previousTarget: .zero
            )
        )
        enemy.freeze(duration: 1)

        enemy.advance(toward: target, deltaTime: 0.25)

        XCTAssertEqual(enemy.position, .zero)
        guard case let .hunterDot(_, previousTarget) = enemy.behavior else {
            XCTFail("Expected Hunter Dot behavior.")
            return
        }
        XCTAssertEqual(previousTarget, target)
    }

    func testPaddleTrapBarDoesNotMoveAndExpires() {
        var enemy = ArenaEnemy(
            id: 1,
            position: CGPoint(x: 80, y: 120),
            radius: 8,
            speed: 0,
            behavior: .paddleTrapBar(trapID: 7, orientation: .horizontal, remainingLifetime: 2)
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

        XCTAssertEqual(enemy.position.x, 9, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 9, accuracy: 0.0001)
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

    func testPaddlePuckRetainsBounceTravelAcrossFrameRates() {
        var positions: [CGPoint] = []
        for framesPerSecond in [30, 60, 120] {
            var enemy = ArenaEnemy(
                id: 1, position: CGPoint(x: 43, y: 17), radius: 4, speed: 145,
                behavior: .paddleTrapDot(trapID: 1, velocity: CGVector(dx: 103, dy: -97),
                                         bounds: CGRect(x: 0, y: 0, width: 126, height: 38), remainingLifetime: 8)
            )
            for _ in 0..<(framesPerSecond * 4) {
                enemy.advance(toward: .zero, deltaTime: 1 / Double(framesPerSecond))
            }
            positions.append(enemy.position)
        }
        for point in positions.dropFirst() {
            XCTAssertEqual(point.x, positions[0].x, accuracy: 0.0001)
            XCTAssertEqual(point.y, positions[0].y, accuracy: 0.0001)
        }
        XCTAssertEqual(positions[0].x, 49, accuracy: 0.0001)
        XCTAssertEqual(positions[0].y, 9, accuracy: 0.0001)
    }

    func testPaddlePuckCanCrossSeveralWallsWithinOneStep() {
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 3, y: 8), radius: 4, speed: 40,
                               behavior: .paddleTrapDot(trapID: 1, velocity: CGVector(dx: -37, dy: 22),
                                                        bounds: CGRect(x: 0, y: 0, width: 10, height: 10), remainingLifetime: 8))
        enemy.advance(toward: .zero, deltaTime: 1)
        XCTAssertEqual(enemy.position.x, 6, accuracy: 0.0001)
        XCTAssertEqual(enemy.position.y, 10, accuracy: 0.0001)
        guard case let .paddleTrapDot(_, velocity, _, _) = enemy.behavior else { return XCTFail("Expected puck") }
        XCTAssertEqual(velocity, CGVector(dx: -37, dy: -22))
    }

    func testFrozenPaddleTrapStillExpiresOnWallClockTime() {
        var bar = ArenaEnemy(
            id: 1,
            position: .zero,
            radius: 4,
            speed: 0,
            behavior: .paddleTrapBar(trapID: 7, orientation: .horizontal, remainingLifetime: 1),
            frozenTimeRemaining: 3
        )
        var dot = ArenaEnemy(
            id: 2,
            position: .zero,
            radius: 4,
            speed: 100,
            behavior: .paddleTrapDot(
                trapID: 7,
                velocity: CGVector(dx: 100, dy: 0),
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                remainingLifetime: 1
            ),
            frozenTimeRemaining: 3
        )

        bar.advance(toward: .zero, deltaTime: 1)
        dot.advance(toward: .zero, deltaTime: 1)

        XCTAssertTrue(bar.isExpired)
        XCTAssertTrue(dot.isExpired)
        XCTAssertEqual(dot.position, .zero)
        XCTAssertTrue(bar.isFrozen)
        XCTAssertTrue(dot.isFrozen)
    }

    func testCircleCollisionUsesCombinedRadii() {
        let player = CollisionCircle(center: CGPoint(x: 0, y: 0), radius: 9)
        let touchingEnemy = CollisionCircle(center: CGPoint(x: 17, y: 0), radius: 8)
        let distantEnemy = CollisionCircle(center: CGPoint(x: 18, y: 0), radius: 8)

        XCTAssertTrue(player.intersects(touchingEnemy))
        XCTAssertFalse(player.intersects(distantEnemy))
    }

    func testPlayerHitRadiusStaysWellInsideVisibleCraft() {
        let config = ClassicRunConfiguration()

        XCTAssertLessThan(config.playerHitRadius, config.playerVisualRadius)
        XCTAssertEqual(config.playerVisualRadius, 12, accuracy: 0.0001)
        XCTAssertEqual(config.playerHitRadius, 4.8, accuracy: 0.0001)
    }
}
