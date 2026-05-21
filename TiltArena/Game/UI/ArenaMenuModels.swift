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
        ArenaAwardID.allCases.map { award(id: $0, profile: profile) }
    }

    static func activeUnlockText(profile: RunProfile) -> String {
        ArenaModeRules.activeUnlockText(profile: profile)
    }

    static func postRunHighlights(
        summary: RunSummary?,
        profile: RunProfile,
        previousBestScore: Int,
        progressionResult: ArenaProgressionResult? = nil
    ) -> [String] {
        guard let summary else {
            return ["NO RUN SUMMARY"]
        }

        let bestText = summary.score > previousBestScore ? "NEW BEST" : "BEST \(profile.bestScore)"
        var highlights = [
            bestText,
            "TIME \(formatTime(summary.survivalTime))",
            "MAX COMBO \(summary.maxCombo)",
            "KILLS \(summary.enemiesDestroyed)",
            "WEAPON \(summary.bestWeapon?.displayName.uppercased() ?? "NONE")"
        ]

        if let unlockText = ArenaProgressionRules.unlockSummaryText(
            weapons: progressionResult?.newlyUnlockedWeapons ?? []
        ) {
            highlights.append(unlockText)
        }

        if let awardText = ArenaProgressionRules.awardSummaryText(
            ids: progressionResult?.newlyEarnedAwardIDs ?? []
        ) {
            highlights.append(awardText)
        }

        highlights.append(activeUnlockText(profile: profile))
        return highlights
    }

    private static func award(id: ArenaAwardID, profile: RunProfile) -> ArenaAwardRow {
        let progress = ArenaProgressionRules.awardProgress(for: id, profile: profile)

        return ArenaAwardRow(
            title: progress.title,
            progressText: "\(progress.progress)/\(progress.target)",
            progressFraction: Double(progress.progress) / Double(progress.target),
            isComplete: progress.isComplete
        )
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }
}
