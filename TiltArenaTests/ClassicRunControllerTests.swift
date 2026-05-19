import XCTest
@testable import TiltArena

final class ClassicRunControllerTests: XCTestCase {
    func testStartAndRestartEnterActiveRunAtZeroTime() {
        var controller = ClassicRunController()

        controller.start()
        _ = controller.update(deltaTime: 2, activeEnemyCount: 0)
        controller.restart()

        XCTAssertEqual(controller.phase, .active)
        XCTAssertEqual(controller.survivalTime, 0)
    }

    func testUpdateOnlyAdvancesWhileActive() {
        var controller = ClassicRunController()

        XCTAssertEqual(controller.update(deltaTime: 1, activeEnemyCount: 0), 0)
        XCTAssertEqual(controller.survivalTime, 0)

        controller.start()
        _ = controller.update(deltaTime: 1, activeEnemyCount: 0)
        controller.pause()
        _ = controller.update(deltaTime: 1, activeEnemyCount: 0)

        XCTAssertEqual(controller.survivalTime, 1)
    }

    func testPauseResumeAndGameOverTransitions() {
        var controller = ClassicRunController()

        controller.start()
        controller.pause()
        XCTAssertEqual(controller.phase, .paused)

        controller.resume()
        XCTAssertEqual(controller.phase, .active)

        controller.endRun()
        XCTAssertEqual(controller.phase, .gameOver)
    }

    func testSpawnCountRespectsMaximumEnemies() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0.5, maxActiveChasers: 3)
        )

        controller.start()
        let spawnCount = controller.update(deltaTime: 2, activeEnemyCount: 2)

        XCTAssertEqual(spawnCount, 1)
    }

    func testNonPositiveSpawnIntervalDoesNotScheduleEnemies() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0)
        )

        controller.start()
        let spawnCount = controller.update(deltaTime: 1, activeEnemyCount: 0)

        XCTAssertEqual(spawnCount, 0)
        XCTAssertEqual(controller.survivalTime, 1)
    }
}
