import Foundation

struct ArenaModeRow: Equatable {
    let kind: ArenaModeKind
    let title: String
    let subtitle: String
    let statusText: String
    let progressText: String
    let isAvailable: Bool
}

struct ArenaAwardRow: Equatable {
    let title: String
    let progressText: String
    let progressFraction: Double
    let isComplete: Bool
    let isPlaceholderProgress: Bool
}

struct ArenaMenuContent {
    static func modeRows(profile: RunProfile, selectedMode: ArenaModeKind) -> [ArenaModeRow] {
        ArenaModeKind.allCases.map { mode in
            ArenaModeRow(
                kind: mode,
                title: mode.displayName,
                subtitle: ArenaModeRules.subtitle(for: mode),
                statusText: ArenaModeRules.statusText(for: mode, selectedMode: selectedMode, profile: profile),
                progressText: ArenaModeRules.progressText(for: mode, profile: profile),
                isAvailable: ArenaModeRules.isAvailable(mode, profile: profile)
            )
        }
    }

    static func awardRows(profile: RunProfile) -> [ArenaAwardRow] {
        [
            award(
                title: "COMBO SPARK",
                progress: profile.highestCombo,
                target: 10,
                placeholder: false
            ),
            award(
                title: "SCORE CREST",
                progress: profile.bestScore,
                target: 5_000,
                placeholder: false
            ),
            award(
                title: "FREEZE SHATTER",
                progress: min(profile.totalEnemiesDestroyed, 25),
                target: 25,
                placeholder: true
            ),
            award(
                title: "DANGER GRAB",
                progress: min(profile.totalRuns, 5),
                target: 5,
                placeholder: true
            ),
            award(
                title: "WEAPON MASTER",
                progress: profile.totalEnemiesDestroyed,
                target: 250,
                placeholder: true
            ),
            award(
                title: "SURVIVOR",
                progress: Int(profile.longestSurvivalTime),
                target: 120,
                placeholder: false
            )
        ]
    }

    static func activeUnlockText(profile: RunProfile) -> String {
        ArenaModeRules.activeUnlockText(profile: profile)
    }

    static func postRunHighlights(
        summary: RunSummary?,
        profile: RunProfile,
        previousBestScore: Int
    ) -> [String] {
        guard let summary else {
            return ["NO RUN SUMMARY"]
        }

        let bestText = summary.score > previousBestScore ? "NEW BEST" : "BEST \(profile.bestScore)"
        return [
            bestText,
            "TIME \(formatTime(summary.survivalTime))",
            "MAX COMBO \(summary.maxCombo)",
            "KILLS \(summary.enemiesDestroyed)",
            "WEAPON \(summary.bestWeapon?.displayName.uppercased() ?? "NONE")",
            activeUnlockText(profile: profile)
        ]
    }

    private static func award(
        title: String,
        progress: Int,
        target: Int,
        placeholder: Bool
    ) -> ArenaAwardRow {
        let clampedTarget = max(1, target)
        let clampedProgress = max(0, min(progress, clampedTarget))
        return ArenaAwardRow(
            title: title,
            progressText: "\(clampedProgress)/\(clampedTarget)",
            progressFraction: Double(clampedProgress) / Double(clampedTarget),
            isComplete: clampedProgress >= clampedTarget,
            isPlaceholderProgress: placeholder
        )
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }
}
