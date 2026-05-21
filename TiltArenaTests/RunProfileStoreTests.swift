import XCTest
@testable import TiltArena

final class RunProfileStoreTests: XCTestCase {
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

    func testDailyParticipationAndAwardsPersist() throws {
        let store = RunProfileStore(defaults: defaults)
        let timestamp = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 21)))

        let result = store.record(
            RunSummary(
                score: 5_000,
                survivalTime: 120,
                maxCombo: 20,
                enemiesDestroyed: 300,
                bestWeapon: .novaBomb,
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
