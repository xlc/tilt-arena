import XCTest
@testable import TiltArena

final class ClassicRunControllerTests: XCTestCase {
    func testExtremeFiniteDeltaKeepsFinalizedDurationEncodable() throws {
        var controller = ClassicRunController()
        controller.start()

        controller.update(deltaTime: .greatestFiniteMagnitude)
        controller.update(deltaTime: .greatestFiniteMagnitude)
        controller.endRun()

        let summary = try XCTUnwrap(controller.finalizedSummary)
        XCTAssertEqual(summary.survivalTime, RunProfile.maximumPersistedSurvivalTime)
        XCTAssertNoThrow(try JSONEncoder().encode(summary))
    }

    func testScoreSaturatesInsteadOfOverflowing() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = Int.max
        configuration.killsPerMultiplierStep = 1
        var controller = ClassicRunController(configuration: configuration)
        controller.start()

        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)

        XCTAssertEqual(controller.score, Int.max)
        XCTAssertEqual(controller.enemiesDestroyed, 2)
    }

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

    func testNonFiniteDeltaDoesNotPoisonRunTimers() {
        var controller = ClassicRunController()

        controller.start()
        controller.recordEnemyKills(count: 1, weaponKind: .shockwave)
        controller.update(deltaTime: .nan)
        controller.update(deltaTime: .infinity)

        XCTAssertEqual(controller.survivalTime, 0)
        XCTAssertEqual(controller.comboTimeRemaining, controller.configuration.comboWindow)

        controller.update(deltaTime: 0.25)

        XCTAssertEqual(controller.survivalTime, 0.25, accuracy: 0.0001)
        XCTAssertEqual(
            controller.comboTimeRemaining,
            controller.configuration.comboWindow - 0.25,
            accuracy: 0.0001
        )
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

    func testWeaponComboPrimesFamilyWithoutFirstClearBonus() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = 7
        configuration.killsPerMultiplierStep = 100
        configuration.weaponComboWindow = 3.25
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        let event = controller.recordEnemyKills(count: 3, weaponKind: .shockwave)

        XCTAssertNil(event)
        XCTAssertEqual(controller.score, 3 * configuration.baseEnemyScore)
        XCTAssertEqual(controller.weaponComboPrimer?.family, .force)
        XCTAssertEqual(controller.weaponComboPrimer?.timeRemaining ?? 0, configuration.weaponComboWindow, accuracy: 0.0001)
    }

    func testWeaponComboReportsDifferentFamilyClearWithoutChangingScoreOrComboTimer() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = 7
        configuration.killsPerMultiplierStep = 100
        configuration.comboWindow = 1.1
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)
        let event = controller.recordEnemyKills(count: 2, weaponKind: .seekerSwarm)

        XCTAssertEqual(event?.kind, .synergy)
        XCTAssertEqual(event?.previousFamily, .force)
        XCTAssertEqual(event?.currentFamily, .seek)
        XCTAssertEqual(controller.score, 4 * configuration.baseEnemyScore)
        XCTAssertEqual(
            controller.comboTimeRemaining,
            configuration.comboWindow,
            accuracy: 0.0001
        )
    }

    func testStaggeredKillsCanRecordOneAggregatedWeaponClear() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = 7
        configuration.killsPerMultiplierStep = 100
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)

        XCTAssertNil(controller.recordEnemyKills(
            count: 1,
            weaponKind: .chainLightning,
            recordsWeaponClear: false
        ))
        XCTAssertNil(controller.recordEnemyKills(
            count: 1,
            weaponKind: .chainLightning,
            recordsWeaponClear: false
        ))
        XCTAssertEqual(controller.weaponComboPrimer?.family, .force)
        XCTAssertEqual(controller.enemiesDestroyed, 4)
        XCTAssertEqual(controller.score, 4 * configuration.baseEnemyScore)

        let event = controller.recordWeaponClear(killCount: 2, weaponKind: .chainLightning)

        XCTAssertEqual(event?.kind, .synergy)
        XCTAssertEqual(event?.previousFamily, .force)
        XCTAssertEqual(event?.currentFamily, .seek)
        XCTAssertEqual(controller.weaponComboPrimer?.family, .seek)
        XCTAssertEqual(controller.enemiesDestroyed, 4)
        XCTAssertEqual(controller.score, 4 * configuration.baseEnemyScore)
    }

    func testWeaponComboDoesNotBonusSameFamilyOrSmallFollowupClear() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = 7
        configuration.killsPerMultiplierStep = 100
        configuration.weaponComboMinimumKillCount = 1
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)
        XCTAssertNil(controller.recordEnemyKills(count: 2, weaponKind: .powerWave))
        XCTAssertNil(controller.recordEnemyKills(count: 1, weaponKind: .seekerSwarm))

        XCTAssertEqual(controller.score, 5 * configuration.baseEnemyScore)
        XCTAssertEqual(controller.weaponComboPrimer?.family, .seek)
    }

    func testWeaponComboCascadeAfterThreeDistinctFamiliesWithoutChangingScoreOrComboTimer() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = 7
        configuration.killsPerMultiplierStep = 100
        configuration.comboWindow = 1.1
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)
        controller.recordEnemyKills(count: 2, weaponKind: .seekerSwarm)
        let event = controller.recordEnemyKills(count: 2, weaponKind: .freezeBurst)

        XCTAssertEqual(event?.kind, .cascade)
        XCTAssertEqual(event?.previousFamily, .seek)
        XCTAssertEqual(event?.currentFamily, .control)
        XCTAssertEqual(controller.score, 6 * configuration.baseEnemyScore)
        XCTAssertEqual(
            controller.comboTimeRemaining,
            configuration.comboWindow,
            accuracy: 0.0001
        )
    }

    func testWeaponComboPrimerExpiresDuringActiveUpdate() {
        var configuration = ClassicRunConfiguration()
        configuration.weaponComboWindow = 2.5
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)
        controller.recordEnemyKills(count: 2, weaponKind: .seekerSwarm)
        controller.update(deltaTime: 1)

        XCTAssertEqual(controller.weaponComboPrimer?.family, .seek)
        XCTAssertEqual(
            controller.weaponComboPrimer?.timeRemaining ?? 0,
            1.5,
            accuracy: 0.0001
        )

        controller.update(deltaTime: 1.5)
        XCTAssertNil(controller.weaponComboPrimer)
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

    func testTinySurvivalBonusIntervalCannotTrapRunUpdate() {
        var configuration = ClassicRunConfiguration()
        configuration.survivalBonusStartTime = 0
        configuration.survivalBonusInterval = .leastNonzeroMagnitude
        var controller = ClassicRunController(configuration: configuration)

        controller.start()
        controller.update(deltaTime: 1)

        XCTAssertEqual(controller.phase, .active)
        XCTAssertEqual(controller.survivalTime, 1)
        XCTAssertEqual(controller.score, 0)
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
                timestamp: timestamp,
                startedAt: controller.context.startedAt
            )
        )

        controller.restart()

        XCTAssertEqual(controller.phase, .active)
        XCTAssertNil(controller.finalizedSummary)
        XCTAssertEqual(controller.score, 0)
        XCTAssertEqual(controller.currentCombo, 0)
    }
}
