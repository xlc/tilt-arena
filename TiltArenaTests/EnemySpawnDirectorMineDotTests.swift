import XCTest
@testable import TiltArena

final class EnemySpawnDirectorMineDotTests: XCTestCase {
    func testMineDotDoesNotTelegraphBeforeChaos() {
        var director = EnemySpawnDirector(configuration: mineDotTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let pressureFrame = director.update(
            deltaTime: 100,
            survivalTime: 89.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 220, y: 160),
            pickupCircles: []
        )

        XCTAssertTrue(pressureFrame.telegraphsToShow.isEmpty)

        let chaosFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 220, y: 160),
            pickupCircles: []
        )

        XCTAssertEqual(chaosFrame.telegraphsToShow.count, 1)
        XCTAssertTrue(chaosFrame.newEnemies.isEmpty)
    }

    func testMineDotUsesChaosAndSurvivalHellDefaults() {
        let configuration = EnemySpawnConfiguration()
        let chaos = configuration.tuning(at: 90)
        let survivalHell = configuration.tuning(at: 180)

        XCTAssertEqual(chaos.mineDotSpawnInterval, 14)
        XCTAssertEqual(chaos.maxActiveMineDots, 4)
        XCTAssertEqual(survivalHell.mineDotSpawnInterval, 10)
        XCTAssertEqual(survivalHell.maxActiveMineDots, 7)
    }

    func testMineDotTelegraphsBeforeSpawningAndStaysStationary() {
        var configuration = mineDotTestConfiguration()
        configuration.mineDotTelegraphDuration = 0.9
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 240, y: 180)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)
        XCTAssertGreaterThan(telegraphFrame.telegraphsToShow[0].segments.count, 8)
        XCTAssertTrue(telegraphFrame.newEnemies.isEmpty)

        let waitingFrame = director.update(
            deltaTime: 0.4,
            survivalTime: 90.4,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(waitingFrame.newEnemies.isEmpty)
        XCTAssertTrue(waitingFrame.telegraphIDsToRemove.isEmpty)

        let spawnFrame = director.update(
            deltaTime: 0.5,
            survivalTime: 90.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 1)
        var mineDot = spawnFrame.newEnemies[0]
        let spawnPosition = mineDot.position

        mineDot.advance(toward: CGPoint(x: 0, y: 0), deltaTime: 2)

        XCTAssertTrue(mineDot.isMineDot)
        XCTAssertNil(mineDot.formationID)
        XCTAssertFalse(mineDot.isLinearPatternEnemy)
        XCTAssertEqual(mineDot.position.x, spawnPosition.x, accuracy: 0.0001)
        XCTAssertEqual(mineDot.position.y, spawnPosition.y, accuracy: 0.0001)
    }

    func testMineDotPlacementAvoidsPlayerPickupActiveEnemyAndMineSpacing() throws {
        var configuration = mineDotTestConfiguration()
        configuration.mineDotPickupGuardDistance = 16
        configuration.mineDotMinimumSpacing = 80
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let pickupCircle = CollisionCircle(center: CGPoint(x: 150, y: 150), radius: 16)
        let blockedCandidate = ArenaEnemy(
            id: 900,
            position: CGPoint(x: 198, y: 150),
            radius: 8,
            speed: 0,
            behavior: .mineDot
        )
        let playerPosition = CGPoint(x: 40, y: 40)

        _ = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [blockedCandidate],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        let spawnFrame = director.update(
            deltaTime: 0.9,
            survivalTime: 90.9,
            activeEnemies: [blockedCandidate],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        XCTAssertEqual(spawnFrame.newEnemies.count, 1)
        let mineDot = try XCTUnwrap(spawnFrame.newEnemies.first)
        XCTAssertTrue(director.isSafeSpawn(
            mineDot.position,
            avoiding: playerPosition,
            pickupCircles: [pickupCircle]
        ))
        XCTAssertGreaterThanOrEqual(distance(from: mineDot.position, to: blockedCandidate.position), 80)
        XCTAssertLessThan(distance(from: mineDot.position, to: pickupCircle.center), 70)
        XCTAssertNotEqual(mineDot.position, blockedCandidate.position)
    }

    func testPendingMineDotCountsAgainstActiveCap() {
        var configuration = mineDotTestConfiguration()
        configuration.chaos.maxActiveEnemies = 1
        configuration.chaos.maxActiveMineDots = 2
        configuration.chaos.mineDotSpawnInterval = 0.1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let blockedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertTrue(blockedFrame.telegraphsToShow.isEmpty)
        XCTAssertTrue(blockedFrame.newEnemies.isEmpty)
    }

    func testPendingMineDotCountsAgainstMineSpecificCap() {
        var configuration = mineDotTestConfiguration()
        configuration.chaos.maxActiveEnemies = 20
        configuration.chaos.maxActiveMineDots = 1
        configuration.chaos.mineDotSpawnInterval = 0.1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let blockedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertTrue(blockedFrame.telegraphsToShow.isEmpty)
        XCTAssertTrue(blockedFrame.newEnemies.isEmpty)
    }

    func testActiveMineDotCountsAgainstMineSpecificCap() {
        var configuration = mineDotTestConfiguration()
        configuration.chaos.maxActiveMineDots = 1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let activeMineDot = ArenaEnemy(
            id: 900,
            position: CGPoint(x: 80, y: 80),
            radius: 8,
            speed: 0,
            behavior: .mineDot
        )

        let frame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [activeMineDot],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertTrue(frame.telegraphsToShow.isEmpty)
        XCTAssertTrue(frame.newEnemies.isEmpty)
    }

    func testResetRestartsMineDotTelegraphsAndEnemyIDs() {
        var director = EnemySpawnDirector(configuration: mineDotTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let firstTelegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )
        let firstSpawnFrame = director.update(
            deltaTime: 0.9,
            survivalTime: 90.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        director.reset()

        let resetTelegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )
        let resetSpawnFrame = director.update(
            deltaTime: 0.9,
            survivalTime: 90.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertEqual(firstTelegraphFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(resetTelegraphFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(firstSpawnFrame.newEnemies.first?.id, 1)
        XCTAssertEqual(resetSpawnFrame.newEnemies.first?.id, 1)
    }

    private func mineDotTestConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.playerSafetyRadius = 20
        configuration.mineDotTelegraphDuration = 0.9
        configuration.mineDotMinimumSpacing = 52
        configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.pressure = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            mineDotSpawnInterval: 14,
            maxActiveMineDots: 4
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            mineDotSpawnInterval: 10,
            maxActiveMineDots: 7
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

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
