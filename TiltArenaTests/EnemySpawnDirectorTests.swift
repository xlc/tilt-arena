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
            activeEnemies: [],
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
            activeEnemies: placeholderEnemies(count: 1),
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
    }

    func testSequenceSeedOffsetsChaserSpawnsRepeatably() {
        var configuration = EnemySpawnConfiguration()
        configuration.playerSafetyRadius = 0
        configuration.warmup = EnemyPhaseTuning(
            chaserSpawnInterval: 1,
            chaserSpeed: 50,
            maxActiveEnemies: 3,
            formationSpawnInterval: nil,
            formationSpeed: 80,
            formationLaneCount: 5
        )

        let firstSeedFrame = firstChaserFrame(configuration: configuration, sequenceSeed: 20_260_521)
        let repeatSeedFrame = firstChaserFrame(configuration: configuration, sequenceSeed: 20_260_521)
        let nextSeedFrame = firstChaserFrame(configuration: configuration, sequenceSeed: 20_260_522)

        XCTAssertEqual(firstSeedFrame.newEnemies.first?.position, repeatSeedFrame.newEnemies.first?.position)
        XCTAssertNotEqual(firstSeedFrame.newEnemies.first?.position, nextSeedFrame.newEnemies.first?.position)
    }

    func testEnemyTelegraphsBeforeSpawningAndLeavesPlayerLaneGap() {
        var configuration = formationTestConfiguration()
        configuration.playerSafetyRadius = 20
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemies: [],
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
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(waitingFrame.newEnemies.isEmpty)
        XCTAssertTrue(waitingFrame.telegraphIDsToRemove.isEmpty)

        let spawnFrame = director.update(
            deltaTime: 0.5,
            survivalTime: 31,
            activeEnemies: [],
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
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: [pickupCircle]
        )

        let spawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 31,
            activeEnemies: [],
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
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let spawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 31,
            activeEnemies: placeholderEnemies(count: 2),
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 2)
    }

    func testArrowRushDoesNotTelegraphBeforeChaos() {
        var director = EnemySpawnDirector(configuration: arrowRushTestConfiguration())
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

    func testArrowRushUsesChaosAndSurvivalHellDefaults() {
        let configuration = EnemySpawnConfiguration()
        let chaos = configuration.tuning(at: 90)
        let survivalHell = configuration.tuning(at: 180)

        XCTAssertEqual(chaos.arrowRushSpawnInterval, 10)
        XCTAssertEqual(chaos.arrowRushSpeed, 150, accuracy: 0.0001)
        XCTAssertEqual(chaos.arrowRushEnemyCount, 3)
        XCTAssertEqual(survivalHell.arrowRushSpawnInterval, 7)
        XCTAssertEqual(survivalHell.arrowRushSpeed, 175, accuracy: 0.0001)
        XCTAssertEqual(survivalHell.arrowRushEnemyCount, 5)
    }

    func testArrowRushTelegraphsBeforeSpawningAndTargetsCapturedPlayerPosition() {
        var configuration = arrowRushTestConfiguration()
        configuration.arrowRushTelegraphDuration = 0.85
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let capturedTarget = CGPoint(x: 240, y: 180)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: capturedTarget,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)
        XCTAssertEqual(telegraphFrame.telegraphsToShow[0].segments.count, 3)
        XCTAssertTrue(telegraphFrame.newEnemies.isEmpty)

        let waitingFrame = director.update(
            deltaTime: 0.4,
            survivalTime: 90.4,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 20, y: 40),
            pickupCircles: []
        )

        XCTAssertTrue(waitingFrame.newEnemies.isEmpty)
        XCTAssertTrue(waitingFrame.telegraphIDsToRemove.isEmpty)

        let spawnFrame = director.update(
            deltaTime: 0.45,
            survivalTime: 90.85,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 20, y: 40),
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 3)

        for enemy in spawnFrame.newEnemies {
            let velocity = arrowRushVelocity(for: enemy)
            let targetVector = CGVector(
                dx: capturedTarget.x - enemy.position.x,
                dy: capturedTarget.y - enemy.position.y
            )

            XCTAssertNil(enemy.formationID)
            XCTAssertTrue(enemy.isLinearPatternEnemy)
            XCTAssertEqual(hypot(velocity.dx, velocity.dy), 150, accuracy: 0.0001)
            XCTAssertEqual(cross(velocity, targetVector), 0, accuracy: 0.0001)
            XCTAssertGreaterThan(dot(velocity, targetVector), 0)
        }
    }

    func testPendingArrowRushSpawningRespectsActiveCap() {
        var configuration = arrowRushTestConfiguration()
        configuration.chaos.maxActiveEnemies = 4
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

        let spawnFrame = director.update(
            deltaTime: 0.85,
            survivalTime: 90.85,
            activeEnemies: placeholderEnemies(count: 2),
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 2)
    }

    func testPendingArrowRushCountsAgainstActiveCapBeforeSpawning() {
        var configuration = arrowRushTestConfiguration()
        configuration.chaos.maxActiveEnemies = 3
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
        director.configuration.chaos.chaserSpawnInterval = 0.1
        director.configuration.chaos.chaserSpeed = 50

        let blockedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(blockedFrame.newEnemies.isEmpty)
        XCTAssertTrue(blockedFrame.telegraphsToShow.isEmpty)
        XCTAssertTrue(blockedFrame.telegraphIDsToRemove.isEmpty)
    }

    func testResetRestartsArrowRushTelegraphs() {
        var director = EnemySpawnDirector(configuration: arrowRushTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let firstFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        director.reset()

        let resetFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 240, y: 180),
            pickupCircles: []
        )

        XCTAssertEqual(firstFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(resetFrame.telegraphsToShow.first?.id, 1)
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
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 160, y: 300),
            pickupCircles: []
        )

        director.reset()

        let resetFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 0,
            activeEnemies: [],
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

    private func arrowRushTestConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.playerSafetyRadius = 20
        configuration.formationTelegraphDuration = 1
        configuration.arrowRushTelegraphDuration = 0.85
        configuration.minimumArrowRushEnemyCount = 2
        configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.pressure = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            arrowRushSpawnInterval: 10,
            arrowRushSpeed: 150,
            arrowRushEnemyCount: 3
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            arrowRushSpawnInterval: 7,
            arrowRushSpeed: 175,
            arrowRushEnemyCount: 5
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

    private func placeholderEnemies(count: Int) -> [ArenaEnemy] {
        (0..<count).map { index in
            ArenaEnemy(
                id: 10_000 + index,
                position: CGPoint(x: 40 + CGFloat(index) * 24, y: 40),
                radius: 8,
                speed: 0
            )
        }
    }

    private func arrowRushVelocity(
        for enemy: ArenaEnemy,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> CGVector {
        guard case let .arrowRush(velocity) = enemy.behavior else {
            XCTFail("Expected Arrow Rush enemy.", file: file, line: line)
            return .zero
        }

        return velocity
    }

    private func cross(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        lhs.dx * rhs.dy - lhs.dy * rhs.dx
    }

    private func dot(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        lhs.dx * rhs.dx + lhs.dy * rhs.dy
    }

}

private func firstChaserFrame(configuration: EnemySpawnConfiguration, sequenceSeed: Int) -> EnemySpawnFrame {
    var director = EnemySpawnDirector(configuration: configuration, sequenceSeed: sequenceSeed)
    return director.update(
        deltaTime: 0.1,
        survivalTime: 0,
        activeEnemies: [],
        playableRect: CGRect(x: 0, y: 0, width: 320, height: 600),
        playerPosition: CGPoint(x: 160, y: 300),
        pickupCircles: []
    )
}
