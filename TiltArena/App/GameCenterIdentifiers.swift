import Foundation

enum GameCenterIdentifiers {
    enum Leaderboard {
        static let classicSurvivalHighScore = "com.xlc.tiltarena.leaderboard.classic_survival_high_score"
    }

    enum Achievement: String, CaseIterable {
        case firstRun = "com.xlc.tiltarena.achievement.first_run"
        case firstWeaponOrb = "com.xlc.tiltarena.achievement.first_weapon_orb"
        case firstEnemyClear = "com.xlc.tiltarena.achievement.first_enemy_clear"
        case firstChainReaction = "com.xlc.tiltarena.achievement.first_chain_reaction"
        case combo10 = "com.xlc.tiltarena.achievement.combo_10"
        case combo50 = "com.xlc.tiltarena.achievement.combo_50"
        case survive60 = "com.xlc.tiltarena.achievement.survive_60"
        case score100000 = "com.xlc.tiltarena.achievement.score_100000"
    }
}
