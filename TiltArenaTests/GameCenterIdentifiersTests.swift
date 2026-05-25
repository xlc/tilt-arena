import XCTest
@testable import TiltArena

final class GameCenterIdentifiersTests: XCTestCase {
    func testClassicSurvivalLeaderboardIdentifierIsStable() {
        XCTAssertEqual(
            GameCenterIdentifiers.Leaderboard.classicSurvivalHighScore,
            "com.xlc.tiltarena.leaderboard.classic_survival_high_score"
        )
    }

    func testInitialAchievementIdentifiersAreStableAndUnique() {
        let identifiers = GameCenterIdentifiers.Achievement.allCases.map(\.rawValue)

        XCTAssertEqual(
            identifiers,
            [
                "com.xlc.tiltarena.achievement.first_run",
                "com.xlc.tiltarena.achievement.first_weapon_orb",
                "com.xlc.tiltarena.achievement.first_enemy_clear",
                "com.xlc.tiltarena.achievement.first_chain_reaction",
                "com.xlc.tiltarena.achievement.combo_10",
                "com.xlc.tiltarena.achievement.combo_50",
                "com.xlc.tiltarena.achievement.survive_60",
                "com.xlc.tiltarena.achievement.score_100000"
            ]
        )
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }
}
