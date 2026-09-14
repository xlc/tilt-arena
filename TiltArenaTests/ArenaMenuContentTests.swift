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

        profile.lifetimeBestScore = 5_000
        profile.modeRecords[.classic] = RunRecord(bestScore: 5_000)
        profile.totalEnemiesDestroyed = 300
        rows = ArenaMenuContent.modeRows(profile: profile, selectedMode: .classic)

        XCTAssertTrue(rows[1].isAvailable)
        XCTAssertEqual(rows[1].statusText, "AVAILABLE")
        XCTAssertFalse(rows[2].isAvailable)
        XCTAssertEqual(rows[2].statusText, "LOCKED")

        profile.lifetimeHighestCombo = 30
        rows = ArenaMenuContent.modeRows(profile: profile, selectedMode: .classic)

        XCTAssertTrue(rows[2].isAvailable)
        XCTAssertEqual(rows[2].statusText, "AVAILABLE")
    }

    func testActiveUnlockTextComesFromModeRules() {
        var profile = RunProfile()

        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "NEXT FREEZE BURST 0/50 KILLS")

        profile.totalEnemiesDestroyed = 50
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "NEXT GRAVITY WELL 50/100 KILLS")

        profile.lifetimeBestScore = 3_000
        profile.modeRecords[.classic] = RunRecord(bestScore: 3_000)
        profile.lifetimeHighestCombo = 20
        profile.totalEnemiesDestroyed = 300
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "NEXT RICOCHET LANCE 20/30 COMBO")

        profile.lifetimeHighestCombo = 30
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "REDLINE 3000/5000 CLASSIC BEST")

        profile.lifetimeBestScore = 5_000
        profile.modeRecords[.classic] = RunRecord(bestScore: 5_000)
        XCTAssertEqual(ArenaMenuContent.activeUnlockText(profile: profile), "ALL LOCAL MODES READY")
    }

    func testAwardRowsUseProfileData() {
        var profile = RunProfile()
        profile.lifetimeBestScore = 2_500
        profile.modeRecords[.classic] = RunRecord(bestScore: 2_500)
        profile.lifetimeHighestCombo = 8
        profile.totalEnemiesDestroyed = 30

        let rows = ArenaMenuContent.awardRows(profile: profile)

        XCTAssertEqual(rows.first?.title, "COMBO SPARK")
        XCTAssertEqual(rows.first?.progressText, "8/10")
        XCTAssertEqual(rows[1].progressText, "2500/5000")
        XCTAssertFalse(rows.first?.isComplete ?? true)
    }

    func testWeaponCodexRowsShowLockStateRequirementsAndDescriptions() {
        var profile = RunProfile()
        profile.totalEnemiesDestroyed = 50

        let rows = ArenaMenuContent.weaponCodexRows(profile: profile)

        XCTAssertEqual(rows.map(\.kind), ArenaProgressionRules.allGameplayWeapons)
        XCTAssertEqual(rows.first?.title, "SHOCKWAVE")
        XCTAssertEqual(rows.first?.statusText, "UNLOCKED")
        XCTAssertEqual(rows.first?.unlockText, "STARTER")

        let freezeBurst = rows.first { $0.kind == .freezeBurst }
        XCTAssertEqual(freezeBurst?.statusText, "UNLOCKED")
        XCTAssertEqual(freezeBurst?.unlockText, "50 KILLS")

        let gravityWell = rows.first { $0.kind == .gravityWell }
        XCTAssertEqual(gravityWell?.statusText, "LOCKED")
        XCTAssertEqual(gravityWell?.unlockText, "50/100 KILLS")

        for row in rows {
            XCTAssertFalse(row.description.isEmpty, "Missing description for \(row.kind)")
        }

        let descriptions = Dictionary(uniqueKeysWithValues: rows.map { ($0.kind, $0.description) })
        XCTAssertEqual(descriptions[.freezeBurst], "Touch to shatter; no splits.")
        XCTAssertEqual(descriptions[.ricochetLance], "Beam bounces off arena walls.")
        XCTAssertEqual(descriptions[.novaBomb], "Random 50–100%; no splits.")
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
        XCTAssertTrue(highlights.contains("AWARDS COMBO SPARK, ENEMY SWEEP"))
        XCTAssertEqual(highlights.last, "NEXT GRAVITY WELL 50/100 KILLS")

        let customHighlights = ArenaMenuContent.postRunHighlights(
            summary: summary, profile: profile, previousBestScore: 500,
            progressionResult: result, isCustomRun: true
        )
        XCTAssertEqual(customHighlights.first, "CUSTOM RUN · NOT SAVED")
        XCTAssertTrue(customHighlights.contains("WEAPON SHOCKWAVE"))
        XCTAssertFalse(customHighlights.contains { $0.hasPrefix("UNLOCK") || $0.hasPrefix("AWARDS") || $0.hasPrefix("NEXT") })
    }
}
