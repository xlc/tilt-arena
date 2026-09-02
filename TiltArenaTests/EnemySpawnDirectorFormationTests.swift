import XCTest
@testable import TiltArena

final class EnemySpawnDirectorFormationTests: XCTestCase {
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

    func testFormationRejectsNonfinitePlayerPositionWithoutTrapping() {
        let configuration = formationTestConfiguration()
        var director = EnemySpawnDirector(configuration: configuration)

        let frame = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemies: [],
            playableRect: CGRect(x: 0, y: 0, width: 300, height: 300),
            playerPosition: CGPoint(x: CGFloat.nan, y: CGFloat.infinity),
            pickupCircles: []
        )

        XCTAssertTrue(frame.telegraphsToShow.isEmpty)
        XCTAssertTrue(frame.newEnemies.isEmpty)
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
    private func formationTestConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.patternIntroductionSpacing = 0
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

}
