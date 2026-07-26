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

struct WeaponCodexRow: Equatable {
    let kind: WeaponKind
    let title: String
    let description: String
    let statusText: String
    let unlockText: String
    let isUnlocked: Bool
}

struct ArenaMenuContent {
    private static let weaponDescriptions: [WeaponKind: String] = [
        .shockwave: "Growing ring clears threats.",
        .seekerSwarm: "Nearest targets; impact bursts.",
        .razorShield: "Orbiting blades, then burst.",
        .freezeBurst: "Freeze, then touch to shatter.",
        .gravityWell: "Pulls inward; clears center.",
        .chainLightning: "Strike jumps between threats.",
        .flameTrail: "Boost, guard, damaging trail.",
        .warpDash: "Slows and pushes nearby foes.",
        .powerWave: "Charge, aim, clear a wide cone.",
        .ricochetLance: "Beam bounces off arena walls.",
        .novaBomb: "Random 50%; charge clears more."
    ]

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

    static func weaponCodexRows(profile: RunProfile) -> [WeaponCodexRow] {
        let unlockedWeapons = Set(ArenaProgressionRules.unlockedWeapons(for: profile))

        return ArenaProgressionRules.allGameplayWeapons.map { kind in
            let milestone = weaponUnlockMilestone(for: kind)
            let isUnlocked = unlockedWeapons.contains(kind)

            return WeaponCodexRow(
                kind: kind,
                title: kind.displayName.uppercased(),
                description: weaponDescription(for: kind),
                statusText: isUnlocked ? "UNLOCKED" : "LOCKED",
                unlockText: weaponUnlockText(milestone: milestone, profile: profile, isUnlocked: isUnlocked),
                isUnlocked: isUnlocked
            )
        }
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

    private static func weaponUnlockMilestone(for kind: WeaponKind) -> WeaponUnlockMilestone? {
        ArenaProgressionRules.weaponUnlockMilestones.first { $0.weapon == kind }
    }

    private static func weaponUnlockText(
        milestone: WeaponUnlockMilestone?,
        profile: RunProfile,
        isUnlocked: Bool
    ) -> String {
        guard let milestone else {
            return "STARTER"
        }

        if isUnlocked {
            return "\(milestone.requirement.target) \(milestone.requirement.label)"
        }

        let progress = milestone.requirement.progress(in: profile)
        let target = milestone.requirement.target
        return "\(min(max(0, progress), target))/\(target) \(milestone.requirement.label)"
    }

    private static func weaponDescription(for kind: WeaponKind) -> String {
        guard let description = weaponDescriptions[kind] else {
            preconditionFailure("Missing weapon codex description for \(kind.rawValue).")
        }

        return description
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }
}
