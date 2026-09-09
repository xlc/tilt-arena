import XCTest
@testable import TiltArena

final class RunProfileStoreTests: XCTestCase {
    func testRecordingRunSaturatesCorruptedCounters() {
        var profile = RunProfile()
        profile.totalRuns = Int.max
        profile.totalEnemiesDestroyed = Int.max
        let summary = RunSummary(
            score: 10,
            survivalTime: 1,
            maxCombo: 1,
            enemiesDestroyed: 1,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: 1)
        )

        profile.record(summary)

        XCTAssertEqual(profile.totalRuns, Int.max)
        XCTAssertEqual(profile.totalEnemiesDestroyed, Int.max)
    }

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "RunProfileStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRunProfilePersistsBestTotalsAndRecentRuns() {
        let store = RunProfileStore(defaults: defaults)

        for runNumber in 1...6 {
            store.record(
                RunSummary(
                    score: runNumber * 100,
                    survivalTime: TimeInterval(runNumber * 10),
                    maxCombo: runNumber,
                    enemiesDestroyed: runNumber * 3,
                    bestWeapon: .shockwave,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(runNumber))
                )
            )
        }

        let reloadedProfile = RunProfileStore(defaults: defaults).profile

        XCTAssertEqual(reloadedProfile.lifetimeBestScore, 600)
        XCTAssertEqual(reloadedProfile.lifetimeHighestCombo, 6)
        XCTAssertEqual(reloadedProfile.lifetimeLongestSurvivalTime, 60)
        XCTAssertEqual(reloadedProfile.totalRuns, 6)
        XCTAssertEqual(reloadedProfile.totalEnemiesDestroyed, 63)
        XCTAssertTrue(reloadedProfile.unlockedWeapons.contains(.freezeBurst))
        XCTAssertEqual(reloadedProfile.recentRuns.count, 5)
        XCTAssertEqual(reloadedProfile.recentRuns.first?.score, 600)
        XCTAssertEqual(reloadedProfile.recentRuns.last?.score, 200)
    }

    func testPersistedNumericNormalizationPreservesValidFieldsAndRepairsOnce() throws {
        let originalData = Data("""
        {
          "rulesVersion": \(ArenaRunContext.currentRulesVersion),
          "lifetimeBestScore": 4321,
          "lifetimeHighestCombo": -4,
          "lifetimeLongestSurvivalTime": 1e300,
          "totalRuns": -2,
          "totalEnemiesDestroyed": 55,
          "unlockedWeapons": ["shockwave"],
          "earnedAwardIDs": [],
          "dailyParticipationSeeds": [],
          "recentRuns": [],
          "modeRecords": [],
          "dailyRecords": {}
        }
        """.utf8)
        defaults.set(originalData, forKey: "tiltArena.runProfile")
        let store = RunProfileStore(defaults: defaults)

        let profile = store.profile

        XCTAssertEqual(profile.lifetimeBestScore, 4_321)
        XCTAssertEqual(profile.lifetimeHighestCombo, 0)
        XCTAssertEqual(
            profile.lifetimeLongestSurvivalTime,
            RunProfile.maximumPersistedSurvivalTime
        )
        XCTAssertEqual(
            TimeInterval(Int(profile.lifetimeLongestSurvivalTime)),
            profile.lifetimeLongestSurvivalTime
        )
        XCTAssertEqual(profile.totalRuns, 0)
        XCTAssertEqual(profile.totalEnemiesDestroyed, 55)
        XCTAssertTrue(profile.earnedAwardIDs.contains(.survivor))

        let repairedData = try XCTUnwrap(defaults.data(forKey: "tiltArena.runProfile"))
        XCTAssertNotEqual(repairedData, originalData)
        XCTAssertEqual(store.profile, profile)
        XCTAssertEqual(defaults.data(forKey: "tiltArena.runProfile"), repairedData)
    }

    func testSurvivorProgressHandlesOutOfRangeInMemoryDuration() {
        var profile = RunProfile()
        profile.lifetimeLongestSurvivalTime = 1e300

        let progress = ArenaProgressionRules.awardProgress(for: .survivor, profile: profile)

        XCTAssertEqual(progress.progress, 120)
        XCTAssertTrue(progress.isComplete)
    }

    func testDailyParticipationAndAwardsPersist() throws {
        let store = RunProfileStore(defaults: defaults)
        let timestamp = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 21)))

        let result = store.record(
            RunSummary(
                score: 5_000,
                survivalTime: 120,
                maxCombo: 30,
                enemiesDestroyed: 300,
                bestWeapon: .ricochetLance,
                timestamp: timestamp,
                mode: .daily,
                sequenceSeed: ArenaModeRules.dailySeed(for: timestamp)
            )
        )

        let reloadedProfile = RunProfileStore(defaults: defaults).profile

        XCTAssertEqual(result.profile.dailyParticipationSeeds, [ArenaModeRules.dailySeed(for: timestamp)])
        XCTAssertEqual(reloadedProfile.dailyParticipationSeeds, [ArenaModeRules.dailySeed(for: timestamp)])
        XCTAssertEqual(reloadedProfile.unlockedWeapons, Set(ArenaProgressionRules.allGameplayWeapons))
        XCTAssertTrue(reloadedProfile.earnedAwardIDs.contains(.comboSpark))
        XCTAssertTrue(reloadedProfile.earnedAwardIDs.contains(.weaponMaster))
    }

    func testCompetitiveRecordsStaySeparateWhileProgressionRemainsShared() {
        let store = RunProfileStore(defaults: defaults)
        store.record(RunSummary(
            score: 10_000, survivalTime: 50, maxCombo: 30, enemiesDestroyed: 40,
            bestWeapon: .shockwave, timestamp: Date(timeIntervalSince1970: 1), mode: .redline
        ))
        let previousClassicBest = store.profile.competitiveRecord(for: .classic).bestScore
        let classic = summary(score: 500, mode: .classic)
        store.record(classic)
        let profile = store.profile

        XCTAssertEqual(previousClassicBest, 0)
        XCTAssertEqual(profile.competitiveRecord(for: .classic).bestScore, 500)
        XCTAssertEqual(profile.competitiveRecord(for: .redline).bestScore, 10_000)
        XCTAssertEqual(profile.competitiveRecord(for: .classic).highestCombo, 3)
        XCTAssertEqual(profile.competitiveRecord(for: .classic).longestSurvivalTime, 10)
        XCTAssertEqual(profile.competitiveRecord(for: .redline).highestCombo, 30)
        XCTAssertEqual(profile.competitiveRecord(for: .redline).longestSurvivalTime, 50)
        XCTAssertEqual(profile.lifetimeBestScore, 10_000)
        XCTAssertEqual(profile.totalRuns, 2)
        XCTAssertFalse(ArenaModeRules.isAvailable(.redline, profile: profile))
        XCTAssertEqual(ArenaMenuContent.postRunHighlights(
            summary: classic, profile: profile, previousBestScore: previousClassicBest
        ).first, "NEW BEST")
        XCTAssertEqual(ArenaModeRules.progressText(for: .classic, profile: profile), "BEST 500")
        XCTAssertTrue(profile.unlockedWeapons.contains(.powerWave))
    }

    func testDailyContextSurvivesMidnightAndPauseAndPersistsActualSeed() throws {
        let startedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-09T23:59:50Z"))
        let context = ArenaRunContext(mode: .daily, sequenceSeed: 20_260_909, startedAt: startedAt)
        var controller = ClassicRunController()
        controller.start(context: context)
        controller.recordEnemyKills(count: 2, weaponKind: .shockwave)
        controller.pause()
        controller.update(deltaTime: 20)
        controller.resume()
        controller.update(deltaTime: 2)
        controller.endRun(at: startedAt.addingTimeInterval(30))
        let completed = try XCTUnwrap(controller.finalizedSummary)
        let store = RunProfileStore(defaults: defaults)
        store.record(completed)
        let profile = store.profile

        XCTAssertEqual(completed.mode, .daily)
        XCTAssertEqual(completed.sequenceSeed, 20_260_909)
        XCTAssertEqual(completed.startedAt, startedAt)
        XCTAssertEqual(completed.rulesVersion, ArenaRunContext.currentRulesVersion)
        XCTAssertEqual(profile.dailyParticipationSeeds, [20_260_909])
        XCTAssertEqual(profile.competitiveRecord(for: .daily, seed: 20_260_909).bestScore, 20)
        XCTAssertEqual(profile.competitiveRecord(for: .daily, seed: 20_260_910).bestScore, 0)
        XCTAssertEqual(profile.recentRuns.first, completed)

        controller.restart(context: ArenaRunContext(mode: .daily, sequenceSeed: 20_260_910))
        XCTAssertEqual(controller.context.sequenceSeed, 20_260_910)
    }

    func testDailyBestHistoryIsBoundedSeparatelyFromRecentRuns() {
        let store = RunProfileStore(defaults: defaults)
        for seed in 1...95 {
            store.record(summary(score: seed * 10, mode: .daily, seed: seed))
        }
        let previousBest = store.profile.competitiveRecord(for: .daily, seed: 95).bestScore
        let attempt = summary(score: 1_000, mode: .daily, seed: 95)
        store.record(attempt)
        let profile = store.profile
        XCTAssertEqual(profile.dailyRecords.count, 90)
        XCTAssertNil(profile.dailyRecords[1])
        XCTAssertEqual(profile.recentRuns.count, 5)
        XCTAssertEqual(profile.competitiveRecord(for: .daily, seed: 95).attempts, 2)
        XCTAssertTrue(ArenaMenuContent.postRunHighlights(
            summary: attempt, profile: profile, previousBestScore: previousBest
        ).contains("+50 VS PREVIOUS BEST"))
    }

    func testIncompatibleDevelopmentProfileResetsInsteadOfMigrating() {
        defaults.set(Data("{\"bestScore\":9000}".utf8), forKey: "tiltArena.runProfile")
        XCTAssertEqual(RunProfileStore(defaults: defaults).profile, RunProfile())
        XCTAssertNil(defaults.data(forKey: "tiltArena.runProfile"))
    }

    func testPreviousRulesProfileResetsWithoutPreservingCompetitiveRecords() throws {
        var profile = RunProfile()
        profile.record(summary(score: 9_000, mode: .classic))
        let data = try JSONEncoder().encode(profile)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["rulesVersion"] = ArenaRunContext.currentRulesVersion - 1
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "tiltArena.runProfile")
        XCTAssertEqual(RunProfileStore(defaults: defaults).profile, RunProfile())
        XCTAssertNil(defaults.data(forKey: "tiltArena.runProfile"))
    }

    private func summary(score: Int, mode: ArenaModeKind, seed: Int = 0) -> RunSummary {
        RunSummary(
            score: score, survivalTime: 10, maxCombo: 3, enemiesDestroyed: 5,
            bestWeapon: .shockwave, timestamp: Date(timeIntervalSince1970: 1), mode: mode, sequenceSeed: seed
        )
    }

    func testMissingOrCorruptProfileFallsBackToEmptyProfile() {
        let store = RunProfileStore(defaults: defaults)

        XCTAssertEqual(store.profile, RunProfile())

        defaults.set(Data([0, 1, 2]), forKey: "tiltArena.runProfile")

        XCTAssertEqual(store.profile, RunProfile())
        XCTAssertNil(defaults.data(forKey: "tiltArena.runProfile"))
    }

    func testResetClearsPersistedProfile() {
        let store = RunProfileStore(defaults: defaults)
        store.record(
            RunSummary(
                score: 100,
                survivalTime: 5,
                maxCombo: 2,
                enemiesDestroyed: 3,
                bestWeapon: .shockwave,
                timestamp: Date(timeIntervalSince1970: 1)
            )
        )

        store.reset()

        XCTAssertEqual(store.profile, RunProfile())
    }
}
