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
        profile.totalEnemiesDestroyed = 300
        rows = ArenaMenuContent.modeRows(profile: profile, selectedMode: .classic)

        XCTAssertTrue(rows[1].isAvailable)
        XCTAssertEqual(rows[1].statusText, "AVAILABLE")
        XCTAssertFalse(rows[2].isAvailable)
        XCTAssertEqual(rows[2].statusText, "LOCKED")

        profile.highestCombo = 20
        rows = ArenaMenuContent.modeRows(profile: profile, selectedMode: .classic)

        XCTAssertTrue(rows[2].isAvailable)
        XCTAssertEqual(rows[2].statusText, "AVAILABLE")
    }

    func testActiveUnlockTextComesFromModeRules() {
        var profile = RunProfile()

        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "NEXT FREEZE BURST 0/50 KILLS")

        profile.totalEnemiesDestroyed = 50
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "NEXT GRAVITY WELL 50/100 KILLS")

        profile.bestScore = 3_000
        profile.highestCombo = 20
        profile.totalEnemiesDestroyed = 300
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "REDLINE 3000/5000 BEST")

        profile.bestScore = 5_000
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "ALL LOCAL MODES READY")
    }

    func testAwardRowsUseProfileData() {
        var profile = RunProfile()
        profile.bestScore = 2_500
        profile.highestCombo = 8
        profile.totalEnemiesDestroyed = 30

        let rows = ArenaMenuContent.awardRows(profile: profile)

        XCTAssertEqual(rows.first?.title, "COMBO SPARK")
        XCTAssertEqual(rows.first?.progressText, "8/10")
        XCTAssertEqual(rows[1].progressText, "2500/5000")
        XCTAssertFalse(rows.first?.isComplete ?? true)
    }

    func testPostRunHighlightsReportNewAwardsAndNextUnlock() {
        let summary = RunSummary(
            score: 600,
            survivalTime: 12.5,
            maxCombo: 10,
            enemiesDestroyed: 50,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        var profile = RunProfile()
        let result = profile.record(summary)

        let highlights = ArenaMenuContent.postRunHighlights(
            summary: summary,
            profile: profile,
            previousBestScore: 500,
            progressionResult: result
        )

        XCTAssertEqual(highlights.first, "NEW BEST")
        XCTAssertTrue(highlights.contains("WEAPON SHOCKWAVE"))
        XCTAssertTrue(highlights.contains("UNLOCK FREEZE BURST"))
        XCTAssertTrue(highlights.contains("AWARDS COMBO SPARK, FREEZE SHATTER"))
        XCTAssertEqual(highlights.last, "NEXT GRAVITY WELL 50/100 KILLS")
    }
}
