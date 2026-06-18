import CoreGraphics
import XCTest
@testable import TiltArena

final class EnemySpawnDirectorSplitterTests: XCTestCase {
    func testSplitterSpawnsFromPressureWithLargerBodyAndRespectsCap() throws {
        let configuration = splitterSpawnConfiguration()
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 320, height: 320)
        let playerPosition = CGPoint(x: 160, y: 160)

        let warmupFrame = director.update(
            deltaTime: 1,
            survivalTime: 29.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )
        XCTAssertTrue(warmupFrame.newEnemies.allSatisfy { !$0.isSplitter })

        let warningFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(warningFrame.telegraphsToShow.count, 1)
        XCTAssertTrue(warningFrame.newEnemies.isEmpty)

        let frame = director.update(
            deltaTime: configuration.spawnWarningDuration,
            survivalTime: 30 + configuration.spawnWarningDuration,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(frame.telegraphIDsToRemove, [warningFrame.telegraphsToShow[0].id])
        let splitter = try XCTUnwrap(frame.newEnemies.first)
        XCTAssertEqual(frame.newEnemies.count, 1)
        XCTAssertTrue(splitter.isSplitter)
        XCTAssertTrue(splitter.isPlayerCollisionGraceActive)
        XCTAssertFalse(splitter.canDamagePlayer)
        XCTAssertTrue(splitter.canBeTargetedByWeapons)
        XCTAssertEqual(splitter.radius, configuration.enemyRadius * configuration.splitterRadiusScale, accuracy: 0.0001)
        XCTAssertEqual(splitter.speed, 72, accuracy: 0.0001)
        XCTAssertTrue(director.isSafeSpawn(splitter.position, avoiding: playerPosition, enemyRadius: splitter.radius))

        let cappedFrame = director.update(
            deltaTime: 2,
            survivalTime: 32,
            activeEnemies: [splitter],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.allSatisfy { !$0.isSplitter })
    }

    func testPendingSplitterWarningCountsAgainstSplitterCap() {
        var configuration = splitterSpawnConfiguration()
        let fastSplitterPhase = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 10,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            splitterSpawnInterval: 0.1,
            splitterSpeed: 72,
            maxActiveSplitters: 1
        )
        configuration.pressure = fastSplitterPhase
        configuration.chaos = fastSplitterPhase
        configuration.survivalHell = fastSplitterPhase
        var director = EnemySpawnDirector(configuration: configuration)

        let warningFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 30,
            activeEnemies: [],
            playableRect: CGRect(x: 0, y: 0, width: 320, height: 320),
            playerPosition: CGPoint(x: 160, y: 160),
            pickupCircles: []
        )
        let blockedFrame = director.update(
            deltaTime: 0.05,
            survivalTime: 30.05,
            activeEnemies: [],
            playableRect: CGRect(x: 0, y: 0, width: 320, height: 320),
            playerPosition: CGPoint(x: 160, y: 160),
            pickupCircles: []
        )

        XCTAssertEqual(warningFrame.telegraphsToShow.count, 1)
        XCTAssertTrue(blockedFrame.telegraphsToShow.isEmpty)
        XCTAssertTrue(blockedFrame.newEnemies.isEmpty)
    }

    func testSplitterChildrenSpawnProtectedAndAwayFromPlayer() {
        var configuration = EnemySpawnConfiguration()
        configuration.splitterChildPlayerSafetyRadius = 42
        configuration.splitterChildGraceDuration = 0.75
        configuration.splitterChildSpeedScale = 0.8
        var director = EnemySpawnDirector(configuration: configuration)
        director.nextEnemyID = 10
        let playerPosition = CGPoint(x: 100, y: 100)
        let splitter = ArenaEnemy(
            id: 3,
            position: CGPoint(x: 106, y: 100),
            radius: 8,
            speed: 90,
            behavior: .splitter
        )

        let children = director.splitChildren(
            for: splitter,
            playableRect: CGRect(x: 0, y: 0, width: 260, height: 260),
            playerPosition: playerPosition
        )

        XCTAssertEqual(children.map(\.id), [10, 11])
        XCTAssertEqual(children.count, 2)
        for child in children {
            XCTAssertTrue(child.isSplitterChild)
            XCTAssertTrue(child.isSplitProtected)
            XCTAssertFalse(child.canDamagePlayer)
            XCTAssertTrue(child.canBeTargetedByWeapons)
            XCTAssertEqual(child.speed, 72, accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(
                hypot(child.position.x - playerPosition.x, child.position.y - playerPosition.y) + 0.001,
                configuration.splitterChildPlayerSafetyRadius + child.radius
            )
        }
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

    private func splitterSpawnConfiguration() -> EnemySpawnConfiguration {
        let splitterPhase = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 10,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            splitterSpawnInterval: 1,
            splitterSpeed: 72,
            maxActiveSplitters: 1
        )
        var configuration = EnemySpawnConfiguration()
        configuration.playerSafetyRadius = 20
        configuration.splitterRadiusScale = 1.75
        configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 10)
        configuration.pressure = splitterPhase
        configuration.chaos = splitterPhase
        configuration.survivalHell = splitterPhase
        return configuration
    }
}
