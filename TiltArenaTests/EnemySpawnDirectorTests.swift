import XCTest
@testable import TiltArena

final class EnemySpawnDirectorTests: XCTestCase {
    func testDifficultyPhaseBoundaries() {
        XCTAssertEqual(EnemyDifficultyPhase.phase(at: 0), .warmup)
        XCTAssertEqual(EnemyDifficultyPhase.phase(at: 29.999), .warmup)
        XCTAssertEqual(EnemyDifficultyPhase.phase(at: 30), .pressure)
        XCTAssertEqual(EnemyDifficultyPhase.phase(at: 90), .chaos)
        XCTAssertEqual(EnemyDifficultyPhase.phase(at: 180), .survivalHell)
    }

    func testTuningSmoothlyIncreasesChaserPressure() {
        let configuration = EnemySpawnConfiguration()

        let start = configuration.tuning(at: 0)
        let middle = configuration.tuning(at: 15)
        let pressureStart = configuration.tuning(at: 30)

        XCTAssertLessThan(middle.chaserSpawnInterval, start.chaserSpawnInterval)
        XCTAssertGreaterThan(middle.chaserSpeed, start.chaserSpeed)
        XCTAssertGreaterThan(middle.maxActiveEnemies, start.maxActiveEnemies)
        XCTAssertEqual(pressureStart.formationSpawnInterval, configuration.pressure.formationSpawnInterval)
    }

    func testChaserSpawningRespectsCapPlayerSafetyAndPickupAvoidance() {
        var configuration = EnemySpawnConfiguration()
        configuration.warmup = EnemyPhaseTuning(
            chaserSpawnInterval: 1,
            chaserSpeed: 50,
            maxActiveEnemies: 1,
            formationSpawnInterval: nil,
            formationSpeed: 80,
            formationLaneCount: 5
        )
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 320, height: 600)
        let playerPosition = CGPoint(x: 0, y: 75)
        let pickupCircle = CollisionCircle(center: CGPoint(x: 320, y: 75), radius: 16)

        let frame = director.update(
            deltaTime: 0.1,
            survivalTime: 0,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        XCTAssertEqual(frame.newEnemies.count, 1)
        XCTAssertTrue(director.isSafeSpawn(
            frame.newEnemies[0].position,
            avoiding: playerPosition,
            pickupCircles: [pickupCircle]
        ))

        let cappedFrame = director.update(
            deltaTime: 10,
            survivalTime: 0,
            activeEnemyCount: 1,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
    }

    func testFormationTelegraphsBeforeSpawningAndLeavesPlayerLaneGap() {
        var configuration = formationTestConfiguration()
        configuration.playerSafetyRadius = 20
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)
        XCTAssertEqual(telegraphFrame.telegraphsToShow[0].segments.count, 2)
        XCTAssertTrue(telegraphFrame.newEnemies.isEmpty)

        let waitingFrame = director.update(
            deltaTime: 0.5,
            survivalTime: 30.5,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(waitingFrame.newEnemies.isEmpty)
        XCTAssertTrue(waitingFrame.telegraphIDsToRemove.isEmpty)

        let spawnFrame = director.update(
            deltaTime: 0.5,
            survivalTime: 31,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 4)
        XCTAssertEqual(Set(spawnFrame.newEnemies.compactMap(\.formationID)), [1])
        XCTAssertFalse(spawnFrame.newEnemies.contains { abs($0.position.y - playerPosition.y) < 0.0001 })
    }

    func testFormationSkipsPickupBlockedLane() {
        var configuration = formationTestConfiguration()
        configuration.playerSafetyRadius = 20
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let pickupCircle = CollisionCircle(center: CGPoint(x: 0, y: 75), radius: 40)

        _ = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: [pickupCircle]
        )

        let spawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 31,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: [pickupCircle]
        )

        XCTAssertEqual(spawnFrame.newEnemies.count, 3)
        XCTAssertFalse(spawnFrame.newEnemies.contains { abs($0.position.y - 75) < 0.0001 })
    }

    func testPendingFormationSpawningRespectsActiveCap() {
        var configuration = formationTestConfiguration()
        configuration.playerSafetyRadius = 20
        configuration.pressure.maxActiveEnemies = 4
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let spawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 31,
            activeEnemyCount: 2,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 2)
    }

    func testResetRestartsEnemyAndFormationIDs() {
        var configuration = EnemySpawnConfiguration()
        configuration.warmup = EnemyPhaseTuning(
            chaserSpawnInterval: 1,
            chaserSpeed: 50,
            maxActiveEnemies: 5,
            formationSpawnInterval: nil,
            formationSpeed: 80,
            formationLaneCount: 5
        )
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 320, height: 600)

        let firstFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 0,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: CGPoint(x: 160, y: 300),
            pickupCircles: []
        )

        director.reset()

        let resetFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 0,
            activeEnemyCount: 0,
            playableRect: playableRect,
            playerPosition: CGPoint(x: 160, y: 300),
            pickupCircles: []
        )

        XCTAssertEqual(firstFrame.newEnemies.first?.id, 1)
        XCTAssertEqual(resetFrame.newEnemies.first?.id, 1)
        XCTAssertEqual(director.nextFormationID, 1)
    }

    private func formationTestConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.formationTelegraphDuration = 1
        configuration.minimumFormationEnemyCount = 2
        configuration.pressure = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: 10,
            formationSpeed: 100,
            formationLaneCount: 5
        )
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: 10,
            formationSpeed: 100,
            formationLaneCount: 5
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: 10,
            formationSpeed: 100,
            formationLaneCount: 5
        )
        return configuration
    }
}
