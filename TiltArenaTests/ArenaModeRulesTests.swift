import XCTest
@testable import TiltArena

final class ArenaModeRulesTests: XCTestCase {
    func testAvailabilityUsesProgressionState() {
        var profile = RunProfile()

        XCTAssertTrue(ArenaModeRules.isAvailable(.classic, profile: profile))
        XCTAssertFalse(ArenaModeRules.isAvailable(.redline, profile: profile))
        XCTAssertFalse(ArenaModeRules.isAvailable(.daily, profile: profile))

        profile.bestScore = ArenaModeRules.redlineBestScoreRequirement
        XCTAssertTrue(ArenaModeRules.isAvailable(.redline, profile: profile))
        XCTAssertFalse(ArenaModeRules.isAvailable(.daily, profile: profile))

        profile.bestScore = 3_000
        profile.highestCombo = 30
        profile.totalEnemiesDestroyed = 300
        XCTAssertTrue(ArenaModeRules.isAvailable(.daily, profile: profile))
    }

    func testRedlineStartsFasterDenserAndBiasesMovementControlWeapons() {
        let classic = ArenaModeRules.runSettings(for: .classic)
        let redline = ArenaModeRules.runSettings(for: .redline)
        let classicWarmup = classic.enemySpawnConfiguration.tuning(at: 0)
        let redlineWarmup = redline.enemySpawnConfiguration.tuning(at: 0)

        XCTAssertLessThan(redlineWarmup.chaserSpawnInterval, classicWarmup.chaserSpawnInterval)
        XCTAssertGreaterThan(redlineWarmup.chaserSpeed, classicWarmup.chaserSpeed)
        XCTAssertGreaterThan(redlineWarmup.maxActiveEnemies, classicWarmup.maxActiveEnemies)
        XCTAssertNotNil(redlineWarmup.formationSpawnInterval)
        XCTAssertNil(classicWarmup.arrowRushSpawnInterval)
        XCTAssertNotNil(redlineWarmup.arrowRushSpawnInterval)
        XCTAssertGreaterThan(redlineWarmup.arrowRushSpeed, classicWarmup.arrowRushSpeed)

        let panicWeapons: Set<WeaponKind> = [.shockwave, .seekerSwarm, .razorShield, .novaBomb]
        let movementControlWeapons: Set<WeaponKind> = [
            .freezeBurst,
            .gravityWell,
            .chainLightning,
            .flameTrail,
            .warpDash,
            .powerWave,
            .ricochetLance
        ]
        let cycle = redline.pickupSpawnConfiguration.weaponKindCycle
        let panicCount = cycle.filter { panicWeapons.contains($0) }.count
        let movementControlCount = cycle.filter { movementControlWeapons.contains($0) }.count

        XCTAssertGreaterThan(movementControlCount, panicCount)
        XCTAssertLessThan(
            cycle.filter { $0 == .shockwave }.count,
            classic.pickupSpawnConfiguration.weaponKindCycle.filter { $0 == .shockwave }.count
        )
        XCTAssertFalse(cycle.contains(.novaBomb))
    }

    func testRedlineTightensSafetyWindowsAndPickupForgiveness() {
        let classic = ArenaModeRules.runSettings(for: .classic)
        let redline = ArenaModeRules.runSettings(for: .redline)

        XCTAssertGreaterThan(
            redline.enemySpawnConfiguration.enemySurvivalSpeedMultiplier(at: 0),
            classic.enemySpawnConfiguration.enemySurvivalSpeedMultiplier(at: 0)
        )
        XCTAssertGreaterThan(
            redline.enemySpawnConfiguration.enemySurvivalSpeedMultiplier(at: 120),
            classic.enemySpawnConfiguration.enemySurvivalSpeedMultiplier(at: 120)
        )
        XCTAssertLessThan(
            redline.enemySpawnConfiguration.playerSafetyRadius,
            classic.enemySpawnConfiguration.playerSafetyRadius
        )
        XCTAssertLessThan(
            redline.enemySpawnConfiguration.spawnWarningDuration,
            classic.enemySpawnConfiguration.spawnWarningDuration
        )
        XCTAssertLessThan(
            redline.enemySpawnConfiguration.spawnPlayerCollisionGraceDuration,
            classic.enemySpawnConfiguration.spawnPlayerCollisionGraceDuration
        )
        XCTAssertGreaterThan(
            redline.enemySpawnConfiguration.maxPendingEnemyTelegraphs,
            classic.enemySpawnConfiguration.maxPendingEnemyTelegraphs
        )
        XCTAssertLessThan(
            redline.pickupSpawnConfiguration.maxActivePickups,
            classic.pickupSpawnConfiguration.maxActivePickups
        )
        XCTAssertGreaterThan(
            redline.pickupSpawnConfiguration.refillDelay,
            classic.pickupSpawnConfiguration.refillDelay
        )
        XCTAssertGreaterThan(
            redline.pickupSpawnConfiguration.playerClearance,
            classic.pickupSpawnConfiguration.playerClearance
        )
        XCTAssertLessThan(
            redline.pickupSpawnConfiguration.enemyClearance,
            classic.pickupSpawnConfiguration.enemyClearance
        )
    }

    func testRedlineEscalatesSpecialThreatsMoreAggressivelyThanClassic() throws {
        let classic = ArenaModeRules.runSettings(for: .classic).enemySpawnConfiguration
        let redline = ArenaModeRules.runSettings(for: .redline).enemySpawnConfiguration
        let classicChaos = classic.tuning(at: 90)
        let redlineChaos = redline.tuning(at: 90)
        let classicHell = classic.tuning(at: 180)
        let redlineHell = redline.tuning(at: 180)

        XCTAssertLessThan(
            try XCTUnwrap(redlineChaos.arrowRushSpawnInterval),
            try XCTUnwrap(classicChaos.arrowRushSpawnInterval)
        )
        XCTAssertLessThan(
            try XCTUnwrap(redlineChaos.mineDotSpawnInterval),
            try XCTUnwrap(classicChaos.mineDotSpawnInterval)
        )
        XCTAssertLessThan(
            try XCTUnwrap(redlineChaos.hunterDotSpawnInterval),
            try XCTUnwrap(classicChaos.hunterDotSpawnInterval)
        )
        XCTAssertGreaterThan(redlineChaos.arrowRushEnemyCount, classicChaos.arrowRushEnemyCount)
        XCTAssertGreaterThan(redlineChaos.arrowRushSpeed, classicChaos.arrowRushSpeed)
        XCTAssertGreaterThan(redlineChaos.hunterDotSpeed, classicChaos.hunterDotSpeed)
        XCTAssertGreaterThan(redlineChaos.maxActiveHunterDots, classicChaos.maxActiveHunterDots)

        XCTAssertLessThan(redlineHell.chaserSpawnInterval, classicHell.chaserSpawnInterval)
        XCTAssertGreaterThan(redlineHell.arrowRushSpeed, classicHell.arrowRushSpeed)
        XCTAssertGreaterThan(redlineHell.paddleTrapDotSpeed, classicHell.paddleTrapDotSpeed)
        XCTAssertGreaterThan(redlineHell.splitterSpeed, classicHell.splitterSpeed)
        XCTAssertGreaterThan(redlineHell.maxActiveEnemies, classicHell.maxActiveEnemies)
        XCTAssertGreaterThan(redlineHell.maxActivePaddleTraps, classicHell.maxActivePaddleTraps)
        XCTAssertGreaterThan(redlineHell.maxActiveSplitters, classicHell.maxActiveSplitters)
    }

    func testDailyUsesClassicBalanceWithStableLocalDaySeed() throws {
        let calendar = utcCalendar()
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 21)))
        let sameDayLater = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 21,
            hour: 23,
            minute: 30
        )))
        let nextDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 22)))

        let classic = ArenaModeRules.runSettings(for: .classic)
        let first = ArenaModeRules.runSettings(for: .daily, date: firstDate, calendar: calendar)
        let sameDay = ArenaModeRules.runSettings(for: .daily, date: sameDayLater, calendar: calendar)
        let nextDay = ArenaModeRules.runSettings(for: .daily, date: nextDate, calendar: calendar)

        XCTAssertEqual(first.enemySpawnConfiguration, classic.enemySpawnConfiguration)
        XCTAssertEqual(first.pickupSpawnConfiguration, classic.pickupSpawnConfiguration)
        XCTAssertEqual(first.sequenceSeed, sameDay.sequenceSeed)
        XCTAssertNotEqual(first.sequenceSeed, nextDay.sequenceSeed)
        XCTAssertEqual(first.sequenceSeed, 20_260_521)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
