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
        XCTAssertEqual(reloadedProfile.recentRuns.count, 5)
        XCTAssertEqual(reloadedProfile.recentRuns.first?.score, 600)
        XCTAssertEqual(reloadedProfile.recentRuns.last?.score, 200)
    }

    func testMissingOrCorruptProfileFallsBackToEmptyProfile() {
        let store = RunProfileStore(defaults: defaults)

        XCTAssertEqual(store.profile, RunProfile())

        defaults.set(Data([0, 1, 2]), forKey: "tiltArena.runProfile")

        XCTAssertEqual(store.profile, RunProfile())
    }
}
