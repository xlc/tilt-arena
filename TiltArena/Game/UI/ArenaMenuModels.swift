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
    let detailText: String
    let progressFraction: Double
    let isComplete: Bool
    let isPlaceholderProgress: Bool
}

struct ArenaMenuContent {
    static func modeRows(profile: RunProfile, selectedMode: ArenaModeKind) -> [ArenaModeRow] {
        let redlineAvailable = profile.bestScore >= 5_000
        let dailyAvailable = profile.totalEnemiesDestroyed >= 400

        return [
            ArenaModeRow(
                kind: .classic,
                title: ArenaModeKind.classic.displayName,
                subtitle: "Classic Survival",
                statusText: selectedMode == .classic ? "SELECTED" : "AVAILABLE",
                progressText: "BEST \(profile.bestScore)",
                isAvailable: true
            ),
            ArenaModeRow(
                kind: .redline,
                title: ArenaModeKind.redline.displayName,
                subtitle: "Faster pressure curve",
                statusText: modeStatus(kind: .redline, selectedMode: selectedMode, isAvailable: redlineAvailable),
                progressText: "\(min(profile.bestScore, 5_000))/5000 CLASSIC BEST",
                isAvailable: redlineAvailable
            ),
            ArenaModeRow(
                kind: .daily,
                title: ArenaModeKind.daily.displayName,
                subtitle: "Local fixed-seed arena",
                statusText: modeStatus(kind: .daily, selectedMode: selectedMode, isAvailable: dailyAvailable),
                progressText: "\(min(profile.totalEnemiesDestroyed, 400))/400 UNLOCK TRACK",
                isAvailable: dailyAvailable
            )
        ]
    }

    static func awardRows(profile: RunProfile) -> [ArenaAwardRow] {
        [
            award(
                title: "COMBO SPARK",
                progress: profile.highestCombo,
                target: 10,
                detail: "Reach a 10 combo",
                placeholder: false
            ),
            award(
                title: "SCORE CREST",
                progress: profile.bestScore,
                target: 5_000,
                detail: "Score 5000 in Classic",
                placeholder: false
            ),
            award(
                title: "FREEZE SHATTER",
                progress: min(profile.totalEnemiesDestroyed, 25),
                target: 25,
                detail: "Shatter frozen enemies",
                placeholder: true
            ),
            award(
                title: "DANGER GRAB",
                progress: min(profile.totalRuns, 5),
                target: 5,
                detail: "Take risky weapon pickups",
                placeholder: true
            ),
            award(
                title: "WEAPON MASTER",
                progress: profile.totalEnemiesDestroyed,
                target: 250,
                detail: "Destroy enemies with weapons",
                placeholder: true
            ),
            award(
                title: "SURVIVOR",
                progress: Int(profile.longestSurvivalTime),
                target: 120,
                detail: "Survive for 120 seconds",
                placeholder: false
            )
        ]
    }

    static func activeUnlockText(profile: RunProfile) -> String {
        if profile.bestScore < 5_000 {
            return "REDLINE \(min(profile.bestScore, 5_000))/5000"
        }

        if profile.totalEnemiesDestroyed < 400 {
            return "DAILY \(min(profile.totalEnemiesDestroyed, 400))/400"
        }

        return "ALL LOCAL MODES READY"
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
        detail: String,
        placeholder: Bool
    ) -> ArenaAwardRow {
        let clampedTarget = max(1, target)
        let clampedProgress = max(0, min(progress, clampedTarget))
        return ArenaAwardRow(
            title: title,
            progressText: "\(clampedProgress)/\(clampedTarget)",
            detailText: detail,
            progressFraction: Double(clampedProgress) / Double(clampedTarget),
            isComplete: clampedProgress >= clampedTarget,
            isPlaceholderProgress: placeholder
        )
    }

    private static func modeStatus(
        kind: ArenaModeKind,
        selectedMode: ArenaModeKind,
        isAvailable: Bool
    ) -> String {
        guard isAvailable else {
            return "LOCKED"
        }

        return kind == selectedMode ? "SELECTED" : "AVAILABLE"
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }
}
