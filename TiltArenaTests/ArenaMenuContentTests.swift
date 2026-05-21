import XCTest
@testable import TiltArena

final class ArenaMenuContentTests: XCTestCase {
    func testModeRowsUseModeRulesForAvailabilityAndStatus() {
        var profile = RunProfile()

        var rows = ArenaMenuContent.modeRows(profile: profile, selectedMode: .classic)
        XCTAssertEqual(rows.map(\.kind), [.classic, .redline, .daily])
        XCTAssertTrue(rows[0].isAvailable)
        XCTAssertFalse(rows[1].isAvailable)
        XCTAssertFalse(rows[2].isAvailable)

        profile.bestScore = 5_000
        profile.totalEnemiesDestroyed = 400
        rows = ArenaMenuContent.modeRows(profile: profile, selectedMode: .classic)

        XCTAssertTrue(rows[1].isAvailable)
        XCTAssertEqual(rows[1].statusText, "AVAILABLE")
        XCTAssertTrue(rows[2].isAvailable)
        XCTAssertEqual(rows[2].statusText, "AVAILABLE")
    }

    func testActiveUnlockTextComesFromModeRules() {
        var profile = RunProfile()

        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "REDLINE 0/5000")

        profile.bestScore = 5_000
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "DAILY 0/400")

        profile.totalEnemiesDestroyed = 400
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "ALL LOCAL MODES READY")
    }

    func testAwardRowsUseProfileDataAndMarkPlaceholderProgress() {
        var profile = RunProfile()
        profile.bestScore = 2_500
        profile.highestCombo = 8
        profile.totalEnemiesDestroyed = 30

        let rows = ArenaMenuContent.awardRows(profile: profile)

        XCTAssertEqual(rows.first?.title, "COMBO SPARK")
        XCTAssertEqual(rows.first?.progressText, "8/10")
        XCTAssertEqual(rows[1].progressText, "2500/5000")
        XCTAssertTrue(rows.contains(where: \.isPlaceholderProgress))
    }

    func testPostRunHighlightsReportNewBestAgainstPreviousBest() {
        let summary = RunSummary(
            score: 600,
            survivalTime: 12.5,
            maxCombo: 7,
            enemiesDestroyed: 9,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        var profile = RunProfile()
        profile.record(summary)

        let highlights = ArenaMenuContent.postRunHighlights(
            summary: summary,
            profile: profile,
            previousBestScore: 500
        )

        XCTAssertEqual(highlights.first, "NEW BEST")
        XCTAssertTrue(highlights.contains("WEAPON SHOCKWAVE"))
    }
}
