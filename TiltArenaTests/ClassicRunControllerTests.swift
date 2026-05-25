import XCTest
@testable import TiltArena

final class ClassicRunControllerTests: XCTestCase {
    func testStartAndRestartEnterActiveRunAtZeroTime() {
        var controller = ClassicRunController()

        controller.start()
        controller.update(deltaTime: 2)
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

        controller.update(deltaTime: 1)
        XCTAssertEqual(controller.survivalTime, 0)

        controller.start()
        controller.update(deltaTime: 1)
        controller.pause()
        controller.update(deltaTime: 1)

        XCTAssertEqual(controller.survivalTime, 1)
    }

    func testPausePreservesRunTimeUntilResume() {
        var controller = ClassicRunController()

        controller.start()
        controller.update(deltaTime: 0.25)

        controller.pause()
        controller.update(deltaTime: 5)
        XCTAssertEqual(controller.survivalTime, 0.25, accuracy: 0.0001)

        controller.resume()
        controller.update(deltaTime: 0.25)
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
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .seekerSwarm)
        controller.update(deltaTime: 1.2)

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
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 10, weaponKind: .shockwave)
        controller.update(deltaTime: 1.2)
        controller.recordEnemyKills(count: 1, weaponKind: .razorShield)

        XCTAssertEqual(controller.currentCombo, 1)
        XCTAssertEqual(controller.maxCombo, 10)
        XCTAssertEqual(controller.comboMultiplier, 1)
        XCTAssertEqual(controller.score, 120)
    }

    func testItemPickupScoresOncePerID() {
        var controller = ClassicRunController()

        controller.start()

        XCTAssertTrue(controller.recordItemPickup(pickupID: 3))
        XCTAssertFalse(controller.recordItemPickup(pickupID: 3))

        XCTAssertEqual(controller.score, 50)
        XCTAssertEqual(controller.enemiesDestroyed, 0)
        XCTAssertEqual(controller.currentCombo, 0)
    }

    func testSurvivalBonusAccumulatesSqrtEnemyScaleEverySecond() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = 0
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.recordEnemyKills(count: 25, weaponKind: .razorShield)
        controller.update(deltaTime: 60.5)

        XCTAssertEqual(controller.score, 0)
        XCTAssertEqual(controller.enemiesDestroyed, 25)
        XCTAssertEqual(controller.bestWeapon, .razorShield)

        controller.update(deltaTime: 0.6)
        XCTAssertEqual(controller.score, 1)

        controller.update(deltaTime: 1)
        XCTAssertEqual(controller.score, 3)

        controller.recordEnemyKills(count: 75, weaponKind: .freezeBurst)
        controller.update(deltaTime: 1)

        XCTAssertEqual(controller.score, 5)
        XCTAssertEqual(controller.enemiesDestroyed, 100)
    }

    func testRunSummaryFinalizesOnceAndResetsOnRestart() {
        let timestamp = Date(timeIntervalSince1970: 123)
        var controller = ClassicRunController()

        controller.start()
        controller.update(deltaTime: 2)
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
}
