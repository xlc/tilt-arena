import CoreGraphics
import XCTest
@testable import TiltArena

final class EnemySpawnDirectorHunterDotTests: XCTestCase {
    func testHunterDotDoesNotTelegraphBeforeChaos() {
        var director = EnemySpawnDirector(configuration: hunterDotTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let pressureFrame = director.update(
            deltaTime: 100,
            survivalTime: 89.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )

        XCTAssertTrue(pressureFrame.telegraphsToShow.isEmpty)

        let chaosFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )

        XCTAssertEqual(chaosFrame.telegraphsToShow.count, 1)
        XCTAssertTrue(chaosFrame.newEnemies.isEmpty)
    }

    func testHunterDotUsesChaosAndSurvivalHellDefaults() {
        let configuration = EnemySpawnConfiguration()
        let chaos = configuration.tuning(at: 90)
        let survivalHell = configuration.tuning(at: 180)

        XCTAssertEqual(chaos.hunterDotSpawnInterval, 15)
        XCTAssertEqual(chaos.hunterDotSpeed, 120, accuracy: 0.0001)
        XCTAssertEqual(chaos.hunterDotPredictionLead, 0.6, accuracy: 0.0001)
        XCTAssertEqual(chaos.maxActiveHunterDots, 2)
        XCTAssertEqual(survivalHell.hunterDotSpawnInterval, 10)
        XCTAssertEqual(survivalHell.hunterDotSpeed, 150, accuracy: 0.0001)
        XCTAssertEqual(survivalHell.hunterDotPredictionLead, 0.9, accuracy: 0.0001)
        XCTAssertEqual(survivalHell.maxActiveHunterDots, 3)
    }

    func testHunterDotTelegraphsBeforeSpawningAndUsesPredictionBehavior() throws {
        var configuration = hunterDotTestConfiguration()
        configuration.hunterDotTelegraphDuration = 0.75
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)
        XCTAssertEqual(telegraphFrame.telegraphsToShow[0].segments.count, 4)
        XCTAssertTrue(telegraphFrame.newEnemies.isEmpty)

        let waitingFrame = director.update(
            deltaTime: 0.35,
            survivalTime: 90.35,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(waitingFrame.newEnemies.isEmpty)
        XCTAssertTrue(waitingFrame.telegraphIDsToRemove.isEmpty)

        let spawnFrame = director.update(
            deltaTime: 0.4,
            survivalTime: 90.75,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        let enemy = try XCTUnwrap(spawnFrame.newEnemies.first)
        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 1)
        XCTAssertNil(enemy.formationID)
        XCTAssertFalse(enemy.isLinearPatternEnemy)
        XCTAssertTrue(enemy.isHunterDot)

        guard case let .hunterDot(predictionLead, previousTarget) = enemy.behavior else {
            XCTFail("Expected Hunter Dot behavior.")
            return
        }

        XCTAssertEqual(predictionLead, 0.6, accuracy: 0.0001)
        XCTAssertNil(previousTarget)
    }

    func testPendingHunterDotCountsAgainstActiveCap() {
        var configuration = hunterDotTestConfiguration()
        configuration.chaos.maxActiveEnemies = 1
        configuration.chaos.hunterDotSpawnInterval = 0.1
        configuration.chaos.maxActiveHunterDots = 2
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let cappedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
        XCTAssertTrue(cappedFrame.telegraphsToShow.isEmpty)
    }

    func testPendingHunterDotCountsAgainstHunterSpecificCap() {
        var configuration = hunterDotTestConfiguration()
        configuration.chaos.hunterDotSpawnInterval = 0.1
        configuration.chaos.maxActiveHunterDots = 1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let cappedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
        XCTAssertTrue(cappedFrame.telegraphsToShow.isEmpty)
    }

    func testActiveHunterDotCountsAgainstHunterSpecificCap() {
        var configuration = hunterDotTestConfiguration()
        configuration.chaos.maxActiveHunterDots = 1
        var director = EnemySpawnDirector(configuration: configuration)

        let frame = director.update(
            deltaTime: 1,
            survivalTime: 90,
            activeEnemies: [hunterEnemy()],
            playableRect: CGRect(x: 0, y: 0, width: 300, height: 300),
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )

        XCTAssertTrue(frame.newEnemies.isEmpty)
        XCTAssertTrue(frame.telegraphsToShow.isEmpty)
    }

    func testHunterDotRespectsPendingTelegraphCap() {
        var configuration = hunterDotTestConfiguration()
        configuration.maxPendingEnemyTelegraphs = 1
        configuration.chaos.hunterDotSpawnInterval = 0.1
        configuration.chaos.maxActiveHunterDots = 3
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let firstFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(firstFrame.telegraphsToShow.count, 1)

        let cappedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
        XCTAssertTrue(cappedFrame.telegraphsToShow.isEmpty)
    }

    func testHunterDotPlacementRespectsPlayerSafetyAndPickupAvoidance() throws {
        var configuration = hunterDotTestConfiguration()
        configuration.playerSafetyRadius = 30
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 0, y: 37.5)
        let pickupCircle = CollisionCircle(center: CGPoint(x: 300, y: 37.5), radius: 16)

        _ = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        let spawnFrame = director.update(
            deltaTime: 0.75,
            survivalTime: 90.75,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        let enemy = try XCTUnwrap(spawnFrame.newEnemies.first)
        XCTAssertTrue(director.isSafeSpawn(
            enemy.position,
            avoiding: playerPosition,
            pickupCircles: [pickupCircle]
        ))
    }

    func testResetRestartsHunterDotTelegraphsAndEnemyIDs() throws {
        var director = EnemySpawnDirector(configuration: hunterDotTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let firstTelegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )
        let firstSpawnFrame = director.update(
            deltaTime: 0.75,
            survivalTime: 90.75,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        director.reset()

        let resetTelegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )
        let resetSpawnFrame = director.update(
            deltaTime: 0.75,
            survivalTime: 90.75,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        let firstEnemy = try XCTUnwrap(firstSpawnFrame.newEnemies.first)
        let resetEnemy = try XCTUnwrap(resetSpawnFrame.newEnemies.first)
        XCTAssertEqual(firstTelegraphFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(resetTelegraphFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(firstEnemy.id, 1)
        XCTAssertEqual(resetEnemy.id, 1)
        XCTAssertEqual(firstEnemy.position, resetEnemy.position)
    }

    private func hunterDotTestConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.playerSafetyRadius = 20
        configuration.hunterDotTelegraphDuration = 0.75
        configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.pressure = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            arrowRushSpawnInterval: nil,
            arrowRushSpeed: 0,
            arrowRushEnemyCount: 0,
            mineDotSpawnInterval: nil,
            maxActiveMineDots: 0,
            hunterDotSpawnInterval: 18,
            hunterDotSpeed: 108,
            hunterDotPredictionLead: 0.6,
            maxActiveHunterDots: 2
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            arrowRushSpawnInterval: nil,
            arrowRushSpeed: 0,
            arrowRushEnemyCount: 0,
            mineDotSpawnInterval: nil,
            maxActiveMineDots: 0,
            hunterDotSpawnInterval: 13,
            hunterDotSpeed: 132,
            hunterDotPredictionLead: 0.9,
            maxActiveHunterDots: 3
        )
        return configuration
    }

    private func disabledPhaseTuning(maxActiveEnemies: Int) -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: maxActiveEnemies,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5
        )
    }

    private func hunterEnemy() -> ArenaEnemy {
        ArenaEnemy(
            id: 10_000,
            position: CGPoint(x: 20, y: 20),
            radius: 8,
            speed: 108,
            behavior: .hunterDot(predictionLead: 0.6, previousTarget: nil)
        )
    }
}
