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

    func testEnemyCapacityKeepsPatternsDueWithoutAccumulatingCatchUpSpawns() {
        let configuration = allPatternConfiguration()
        var director = EnemySpawnDirector(configuration: configuration)
        let fullArena = (0..<configuration.warmup.maxActiveEnemies).map { index in
            ArenaEnemy(id: index, position: .zero, radius: 8, speed: 0)
        }

        let blockedFrame = updateDirector(&director, deltaTime: 20, survivalTime: 0, activeEnemies: fullArena)
        XCTAssertTrue(blockedFrame.newEnemies.isEmpty)
        XCTAssertTrue(blockedFrame.telegraphsToShow.isEmpty)
        for pattern in EnemySpawnDirector.SpawnPattern.allCases {
            XCTAssertLessThan(director[keyPath: pattern.timer], 0)
        }

        let releasedFrame = updateDirector(&director, deltaTime: 0.1, survivalTime: 0)
        XCTAssertEqual(releasedFrame.telegraphsToShow.count, 3) // Two patterns and one splitter warning.
        XCTAssertEqual(director.pendingTelegraphSlotCount, 2)
        XCTAssertEqual(director.pendingSplitterCount, 1)
        XCTAssertEqual(director.timeUntilNextFormation, 10, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextSplitter, 10, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextArrowRush, 10, accuracy: 0.0001)

        _ = updateDirector(&director, deltaTime: 0.1, survivalTime: 0)
        XCTAssertEqual(director.timeUntilNextFormation, 9.9, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextSplitter, 9.9, accuracy: 0.0001)
    }

    func testTelegraphCapacityDoesNotResetIntroductionsOrBlockSplitterWarnings() {
        var configuration = allPatternConfiguration()
        configuration.maxPendingEnemyTelegraphs = 0
        var director = EnemySpawnDirector(configuration: configuration)

        let blockedFrame = updateDirector(&director, deltaTime: 3, survivalTime: 0)
        XCTAssertEqual(blockedFrame.telegraphsToShow.count, 1)
        XCTAssertEqual(director.pendingSplitterCount, 1)
        XCTAssertEqual(director.timeUntilNextFormation, -1.5, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextArrowRush, 0, accuracy: 0.0001)

        director.configuration.maxPendingEnemyTelegraphs = 1
        let releasedFrame = updateDirector(&director, deltaTime: 0.1, survivalTime: 0)
        XCTAssertEqual(releasedFrame.telegraphsToShow.count, 1)
        XCTAssertEqual(director.timeUntilNextFormation, 10, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextArrowRush, -0.1, accuracy: 0.0001)
    }

    func testOldestDuePaddleUsesCapacityBeforeFormationAndChasers() {
        var configuration = allPatternConfiguration()
        configuration.maxPendingEnemyTelegraphs = 1
        configuration.warmup.maxActiveEnemies = configuration.warmup.paddleTrapBarEnemyCount * 2 + 1
        configuration.warmup.chaserSpawnInterval = 0.1
        var director = EnemySpawnDirector(configuration: configuration)
        director.enabledSpawnPatterns = Set(EnemySpawnDirector.SpawnPattern.allCases)
        director.timeUntilNextFormation = -1
        director.timeUntilNextPaddleTrap = -5

        _ = director.update(
            deltaTime: 0.1,
            survivalTime: 0,
            activeEnemies: [],
            playableRect: CGRect(x: 0, y: 0, width: 658, height: 317),
            playerPosition: CGPoint(x: 329, y: 158.5),
            pickupCircles: []
        )
        XCTAssertEqual(director.pendingPaddleTrapCount, 1)
        XCTAssertEqual(director.pendingEnemyCount, configuration.warmup.maxActiveEnemies)
        XCTAssertEqual(director.timeUntilNextFormation, -1.1, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextPaddleTrap, 10, accuracy: 0.0001)
    }

    func testReenabledPatternsRestartTheirIntroductionDelays() {
        let configuration = allPatternConfiguration()
        var director = EnemySpawnDirector(configuration: configuration)
        _ = updateDirector(&director, deltaTime: 0.5, survivalTime: 0)

        director.configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 80)
        _ = updateDirector(&director, deltaTime: 0.1, survivalTime: 0)

        assertTelegraphTimers(director, equal: 0)
        XCTAssertEqual(director.timeUntilNextSplitter, 0)

        director.configuration.warmup = configuration.warmup
        let reenabledFrame = updateDirector(&director, deltaTime: 0.1, survivalTime: 0)

        XCTAssertTrue(reenabledFrame.newEnemies.isEmpty)
        XCTAssertTrue(reenabledFrame.telegraphsToShow.isEmpty)
        XCTAssertEqual(director.timeUntilNextFormation, 1.4, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextSplitter, 2.9, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextArrowRush, 2.9, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextMineDot, 4.4, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextHunterDot, 5.9, accuracy: 0.0001)
        XCTAssertEqual(director.timeUntilNextPaddleTrap, 7.4, accuracy: 0.0001)
    }

    func testSuccessfulTelegraphPreservesCountdownOvershoot() {
        var configuration = EnemySpawnConfiguration()
        configuration.patternIntroductionSpacing = 0
        configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.warmup.formationSpawnInterval = 10
        configuration.warmup.formationSpeed = 100
        var director = EnemySpawnDirector(configuration: configuration)

        let frame = updateDirector(&director, deltaTime: 0.3, survivalTime: 0)

        XCTAssertEqual(frame.telegraphsToShow.count, 1)
        XCTAssertEqual(director.timeUntilNextFormation, 9.7, accuracy: 0.0001)
    }

    private func allPatternConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.warmup = configuration.chaos
        configuration.warmup.chaserSpawnInterval = 0
        configuration.warmup.maxActiveEnemies = 80
        configuration.warmup.formationSpawnInterval = 10
        configuration.warmup.splitterSpawnInterval = 10
        configuration.warmup.arrowRushSpawnInterval = 10
        configuration.warmup.mineDotSpawnInterval = 10
        configuration.warmup.hunterDotSpawnInterval = 10
        configuration.warmup.paddleTrapSpawnInterval = 10
        return configuration
    }

    private func assertTelegraphTimers(
        _ director: EnemySpawnDirector,
        equal expected: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let timers = [
            director.timeUntilNextFormation,
            director.timeUntilNextArrowRush,
            director.timeUntilNextMineDot,
            director.timeUntilNextHunterDot,
            director.timeUntilNextPaddleTrap
        ]
        for timer in timers {
            XCTAssertEqual(timer, expected, accuracy: 0.0001, file: file, line: line)
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

    private func updateDirector(
        _ director: inout EnemySpawnDirector,
        deltaTime: TimeInterval,
        survivalTime: TimeInterval,
        activeEnemies: [ArenaEnemy] = []
    ) -> EnemySpawnFrame {
        director.update(
            deltaTime: deltaTime,
            survivalTime: survivalTime,
            activeEnemies: activeEnemies,
            playableRect: CGRect(x: 0, y: 0, width: 300, height: 300),
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )
    }
}
