import XCTest
@testable import TiltArena

final class ClassicRunControllerTests: XCTestCase {
    func testStartAndRestartEnterActiveRunAtZeroTime() {
        var controller = ClassicRunController()

        controller.start()
        _ = controller.update(deltaTime: 2, activeEnemyCount: 0)
        controller.recordEnemyKills(count: 3, weaponKind: .shockwave)
        controller.restart()

        XCTAssertEqual(controller.phase, .active)
        XCTAssertEqual(controller.survivalTime, 0)
        XCTAssertEqual(controller.enemiesDestroyed, 0)
        XCTAssertEqual(controller.score, 0)
        XCTAssertEqual(controller.currentCombo, 0)
        XCTAssertEqual(controller.maxCombo, 0)
        XCTAssertNil(controller.finalizedSummary)
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

    func testPausePreservesRunTimeAndSpawnScheduleUntilResume() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0.5, maxActiveChasers: 10)
        )

        controller.start()
        XCTAssertEqual(controller.update(deltaTime: 0.25, activeEnemyCount: 0), 1)

        controller.pause()
        XCTAssertEqual(controller.update(deltaTime: 5, activeEnemyCount: 1), 0)
        XCTAssertEqual(controller.survivalTime, 0.25, accuracy: 0.0001)

        controller.resume()
        XCTAssertEqual(controller.update(deltaTime: 0.24, activeEnemyCount: 1), 0)
        XCTAssertEqual(controller.survivalTime, 0.49, accuracy: 0.0001)
        XCTAssertEqual(controller.update(deltaTime: 0.01, activeEnemyCount: 1), 1)
        XCTAssertEqual(controller.survivalTime, 0.5, accuracy: 0.0001)
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

    func testEnemyKillCountIgnoresNegativeCounts() {
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 3, weaponKind: .shockwave)
        controller.recordEnemyKills(count: -1, weaponKind: .shockwave)

        XCTAssertEqual(controller.enemiesDestroyed, 3)
        XCTAssertEqual(controller.score, 30)
    }

    func testKillsUpdateScoreComboAndBestWeapon() {
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 3, weaponKind: .shockwave)

        XCTAssertEqual(controller.score, 30)
        XCTAssertEqual(controller.enemiesDestroyed, 3)
        XCTAssertEqual(controller.currentCombo, 3)
        XCTAssertEqual(controller.maxCombo, 3)
        XCTAssertEqual(controller.comboTimeRemaining, 1.2, accuracy: 0.0001)
        XCTAssertEqual(controller.comboMultiplier, 1)
        XCTAssertEqual(controller.bestWeapon, .shockwave)
    }

    func testComboExpiresAfterWindowAndPreservesMaxCombo() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0)
        )

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .seekerSwarm)
        _ = controller.update(deltaTime: 1.2, activeEnemyCount: 0)

        XCTAssertEqual(controller.currentCombo, 0)
        XCTAssertEqual(controller.comboTimeRemaining, 0)
        XCTAssertEqual(controller.maxCombo, 2)
        XCTAssertEqual(controller.score, 20)
    }

    func testMultiplierStartsAtTenthChainedKill() {
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 10, weaponKind: .shockwave)

        XCTAssertEqual(controller.currentCombo, 10)
        XCTAssertEqual(controller.comboMultiplier, 2)
        XCTAssertEqual(controller.score, 110)
    }

    func testBatchKillsCrossMultiplierThresholdSequentially() {
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 12, weaponKind: .seekerSwarm)

        XCTAssertEqual(controller.score, 150)
        XCTAssertEqual(controller.currentCombo, 12)
        XCTAssertEqual(controller.comboMultiplier, 2)
    }

    func testComboBreakResetsCurrentComboOnly() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0)
        )

        controller.start()
        controller.recordEnemyKills(count: 10, weaponKind: .shockwave)
        _ = controller.update(deltaTime: 1.2, activeEnemyCount: 0)
        controller.recordEnemyKills(count: 1, weaponKind: .razorShield)

        XCTAssertEqual(controller.currentCombo, 1)
        XCTAssertEqual(controller.maxCombo, 10)
        XCTAssertEqual(controller.comboMultiplier, 1)
        XCTAssertEqual(controller.score, 120)
    }

    func testNearMissAndDangerGrabScoreOncePerID() {
        var controller = ClassicRunController()

        controller.start()

        XCTAssertTrue(controller.recordNearMiss(enemyID: 7))
        XCTAssertFalse(controller.recordNearMiss(enemyID: 7))
        XCTAssertTrue(controller.recordDangerGrab(pickupID: 3))
        XCTAssertFalse(controller.recordDangerGrab(pickupID: 3))

        XCTAssertEqual(controller.score, 30)
    }

    func testEliteFormationAndSurvivalBonusHooks() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0)
        )

        controller.start()
        controller.recordEliteKill(weaponKind: .razorShield)
        controller.recordFormationBonus()
        _ = controller.update(deltaTime: 70, activeEnemyCount: 0)

        XCTAssertEqual(controller.score, 135)
        XCTAssertEqual(controller.enemiesDestroyed, 1)
        XCTAssertEqual(controller.bestWeapon, .razorShield)
    }

    func testRunSummaryFinalizesOnceAndResetsOnRestart() {
        let timestamp = Date(timeIntervalSince1970: 123)
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0)
        )

        controller.start()
        _ = controller.update(deltaTime: 2, activeEnemyCount: 0)
        controller.recordEnemyKills(count: 2, weaponKind: .seekerSwarm)
        controller.endRun(at: timestamp)
        controller.endRun(at: Date(timeIntervalSince1970: 999))

        XCTAssertEqual(
            controller.finalizedSummary,
            RunSummary(
                score: 20,
                survivalTime: 2,
                maxCombo: 2,
                enemiesDestroyed: 2,
                bestWeapon: .seekerSwarm,
                timestamp: timestamp
            )
        )

        controller.restart()

        XCTAssertEqual(controller.phase, .active)
        XCTAssertNil(controller.finalizedSummary)
        XCTAssertEqual(controller.score, 0)
        XCTAssertEqual(controller.currentCombo, 0)
    }

    func testSpawnCountRespectsMaximumEnemies() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0.5, maxActiveChasers: 3)
        )

        controller.start()
        let spawnCount = controller.update(deltaTime: 2, activeEnemyCount: 2)

        XCTAssertEqual(spawnCount, 1)
    }

    func testSpawnScheduleDoesNotAccumulateDebtWhileAtEnemyCap() {
        var controller = ClassicRunController(
            configuration: ClassicRunConfiguration(spawnInterval: 0.5, maxActiveChasers: 5)
        )

        controller.start()
        XCTAssertEqual(controller.update(deltaTime: 2, activeEnemyCount: 5), 0)
        XCTAssertEqual(controller.update(deltaTime: 0.1, activeEnemyCount: 0), 0)
        XCTAssertEqual(controller.update(deltaTime: 0.4, activeEnemyCount: 0), 1)
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
