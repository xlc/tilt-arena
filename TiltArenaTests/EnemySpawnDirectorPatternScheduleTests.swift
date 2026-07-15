import XCTest
@testable import TiltArena

final class EnemySpawnDirectorPatternScheduleTests: XCTestCase {
    func testNewPatternsReceiveStaggeredPhaseIntroductionTimers() {
        var pressureConfiguration = EnemySpawnConfiguration()
        pressureConfiguration.warmup = disabledPhaseTuning(maxActiveEnemies: 20)
        pressureConfiguration.pressure = EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: 10,
            formationSpeed: 100,
            formationLaneCount: 5,
            splitterSpawnInterval: 10,
            splitterSpeed: 72,
            maxActiveSplitters: 1
        )
        var pressureDirector = EnemySpawnDirector(configuration: pressureConfiguration)

        _ = updateDirector(&pressureDirector, deltaTime: 0.1, survivalTime: 29.9)
        let pressureBoundary = updateDirector(&pressureDirector, deltaTime: 0.1, survivalTime: 30)

        XCTAssertTrue(pressureBoundary.telegraphsToShow.isEmpty)
        XCTAssertTrue(pressureBoundary.newEnemies.isEmpty)
        XCTAssertEqual(pressureDirector.timeUntilNextFormation, 1.4, accuracy: 0.0001)
        XCTAssertEqual(pressureDirector.timeUntilNextSplitter, 2.9, accuracy: 0.0001)

        _ = updateDirector(&pressureDirector, deltaTime: 0, survivalTime: 30)
        XCTAssertEqual(pressureDirector.timeUntilNextFormation, 1.4, accuracy: 0.0001)
        XCTAssertEqual(pressureDirector.timeUntilNextSplitter, 2.9, accuracy: 0.0001)

        var chaosConfiguration = EnemySpawnConfiguration()
        chaosConfiguration.pressure = disabledPhaseTuning(maxActiveEnemies: 40)
        chaosConfiguration.chaos.chaserSpawnInterval = 0
        chaosConfiguration.chaos.formationSpawnInterval = nil
        chaosConfiguration.chaos.splitterSpawnInterval = nil
        var chaosDirector = EnemySpawnDirector(configuration: chaosConfiguration)

        _ = updateDirector(&chaosDirector, deltaTime: 0.1, survivalTime: 89.9)
        let chaosBoundary = updateDirector(&chaosDirector, deltaTime: 0.1, survivalTime: 90)

        XCTAssertTrue(chaosBoundary.telegraphsToShow.isEmpty)
        XCTAssertEqual(chaosDirector.timeUntilNextArrowRush, 2.9, accuracy: 0.0001)
        XCTAssertEqual(chaosDirector.timeUntilNextMineDot, 4.4, accuracy: 0.0001)
        XCTAssertEqual(chaosDirector.timeUntilNextHunterDot, 5.9, accuracy: 0.0001)
        XCTAssertEqual(chaosDirector.timeUntilNextPaddleTrap, 7.4, accuracy: 0.0001)
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

    private func updateDirector(
        _ director: inout EnemySpawnDirector,
        deltaTime: TimeInterval,
        survivalTime: TimeInterval
    ) -> EnemySpawnFrame {
        director.update(
            deltaTime: deltaTime,
            survivalTime: survivalTime,
            activeEnemies: [],
            playableRect: CGRect(x: 0, y: 0, width: 300, height: 300),
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )
    }
}
