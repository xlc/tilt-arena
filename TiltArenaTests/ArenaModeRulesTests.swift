import XCTest
@testable import TiltArena

final class ArenaModeRulesTests: XCTestCase {
    func testAvailabilityUsesCurrentProgressionProxies() {
        var profile = RunProfile()

        XCTAssertTrue(ArenaModeRules.isAvailable(.classic, profile: profile))
        XCTAssertFalse(ArenaModeRules.isAvailable(.redline, profile: profile))
        XCTAssertFalse(ArenaModeRules.isAvailable(.daily, profile: profile))

        profile.bestScore = ArenaModeRules.redlineBestScoreRequirement
        XCTAssertTrue(ArenaModeRules.isAvailable(.redline, profile: profile))
        XCTAssertFalse(ArenaModeRules.isAvailable(.daily, profile: profile))

        profile.totalEnemiesDestroyed = ArenaModeRules.dailyEnemyUnlockRequirement
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

        let panicWeapons: Set<WeaponKind> = [.shockwave, .seekerSwarm, .razorShield, .novaBomb]
        let movementControlWeapons: Set<WeaponKind> = [
            .freezeBurst,
            .gravityWell,
            .chainLightning,
            .flameTrail,
            .warpDash,
            .decoyBeacon
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
