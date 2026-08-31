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

        XCTAssertEqual(reloadedProfile.bestScore, 600)
        XCTAssertEqual(reloadedProfile.highestCombo, 6)
        XCTAssertEqual(reloadedProfile.longestSurvivalTime, 60)
        XCTAssertEqual(reloadedProfile.totalRuns, 6)
        XCTAssertEqual(reloadedProfile.totalEnemiesDestroyed, 63)
        XCTAssertTrue(reloadedProfile.unlockedWeapons.contains(.freezeBurst))
        XCTAssertEqual(reloadedProfile.recentRuns.count, 5)
        XCTAssertEqual(reloadedProfile.recentRuns.first?.score, 600)
        XCTAssertEqual(reloadedProfile.recentRuns.last?.score, 200)
    }

    func testOldProfileDecodingDefaultsProgressionFieldsAndClassicRunMode() throws {
        let oldProfile = OldRunProfile(
            bestScore: 1_600,
            highestCombo: 4,
            longestSurvivalTime: 20,
            totalRuns: 1,
            totalEnemiesDestroyed: 55,
            recentRuns: [
                OldRunSummary(
                    score: 1_600,
                    survivalTime: 20,
                    maxCombo: 4,
                    enemiesDestroyed: 55,
                    bestWeapon: .shockwave,
                    timestamp: Date(timeIntervalSince1970: 1)
                )
            ]
        )

        let data = try JSONEncoder().encode(oldProfile)
        let profile = try JSONDecoder().decode(RunProfile.self, from: data)

        XCTAssertEqual(profile.recentRuns.first?.mode, .classic)
        XCTAssertTrue(profile.unlockedWeapons.contains(.freezeBurst))
        XCTAssertTrue(profile.unlockedWeapons.contains(.flameTrail))
        XCTAssertFalse(profile.unlockedWeapons.contains(.gravityWell))
        XCTAssertEqual(profile.dailyParticipationSeeds, [])
    }

    func testPersistedNumericNormalizationPreservesValidFieldsAndRepairsOnce() throws {
        let originalData = Data("""
        {
          "bestScore": 4321,
          "highestCombo": -4,
          "longestSurvivalTime": 1e300,
          "totalRuns": -2,
          "totalEnemiesDestroyed": 55,
          "unlockedWeapons": ["shockwave"],
          "earnedAwardIDs": [],
          "dailyParticipationSeeds": []
        }
        """.utf8)
        defaults.set(originalData, forKey: "tiltArena.runProfile")
        let store = RunProfileStore(defaults: defaults)

        let profile = store.profile

        XCTAssertEqual(profile.bestScore, 4_321)
        XCTAssertEqual(profile.highestCombo, 0)
        XCTAssertEqual(
            profile.longestSurvivalTime,
            RunProfile.maximumPersistedSurvivalTime
        )
        XCTAssertEqual(
            TimeInterval(Int(profile.longestSurvivalTime)),
            profile.longestSurvivalTime
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
        profile.longestSurvivalTime = 1e300

        let progress = ArenaProgressionRules.awardProgress(for: .survivor, profile: profile)

        XCTAssertEqual(progress.progress, 120)
        XCTAssertTrue(progress.isComplete)
    }

    func testLegacyDecoyBeaconWeaponDecodesAsPowerWave() throws {
        let data = Data("""
        {
          "bestScore": 0,
          "highestCombo": 0,
          "longestSurvivalTime": 0,
          "totalRuns": 1,
          "totalEnemiesDestroyed": 0,
          "recentRuns": [
            {
              "score": 100,
              "survivalTime": 5,
              "maxCombo": 2,
              "enemiesDestroyed": 1,
              "bestWeapon": "decoyBeacon",
              "timestamp": 1,
              "mode": "classic"
            }
          ],
          "unlockedWeapons": ["decoyBeacon"],
          "earnedAwardIDs": [],
          "dailyParticipationSeeds": []
        }
        """.utf8)

        let profile = try JSONDecoder().decode(RunProfile.self, from: data)

        XCTAssertEqual(profile.recentRuns.first?.bestWeapon, .powerWave)
        XCTAssertTrue(profile.unlockedWeapons.contains(.powerWave))
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
                mode: .daily
            )
        )

        let reloadedProfile = RunProfileStore(defaults: defaults).profile

        XCTAssertEqual(result.profile.dailyParticipationSeeds, [ArenaModeRules.dailySeed(for: timestamp)])
        XCTAssertEqual(reloadedProfile.dailyParticipationSeeds, [ArenaModeRules.dailySeed(for: timestamp)])
        XCTAssertEqual(reloadedProfile.unlockedWeapons, Set(ArenaProgressionRules.allGameplayWeapons))
        XCTAssertTrue(reloadedProfile.earnedAwardIDs.contains(.comboSpark))
        XCTAssertTrue(reloadedProfile.earnedAwardIDs.contains(.weaponMaster))
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

private struct OldRunProfile: Encodable {
    let bestScore: Int
    let highestCombo: Int
    let longestSurvivalTime: TimeInterval
    let totalRuns: Int
    let totalEnemiesDestroyed: Int
    let recentRuns: [OldRunSummary]
}

private struct OldRunSummary: Encodable {
    let score: Int
    let survivalTime: TimeInterval
    let maxCombo: Int
    let enemiesDestroyed: Int
    let bestWeapon: WeaponKind?
    let timestamp: Date
}
