import Foundation

enum ArenaAwardID: String, CaseIterable, Codable, Equatable {
    case comboSpark
    case scoreCrest
    case freezeShatter
    case dangerGrab
    case weaponMaster
    case survivor

    var displayName: String {
        switch self {
        case .comboSpark:
            return "Combo Spark"
        case .scoreCrest:
            return "Score Crest"
        case .freezeShatter:
            return "Freeze Shatter"
        case .dangerGrab:
            return "Danger Grab"
        case .weaponMaster:
            return "Weapon Master"
        case .survivor:
            return "Survivor"
        }
    }
}

struct ArenaProgressionResult: Equatable {
    let profile: RunProfile
    let newlyUnlockedWeapons: [WeaponKind]
    let newlyEarnedAwardIDs: [ArenaAwardID]
}

struct WeaponUnlockMilestone: Equatable {
    let weapon: WeaponKind
    let requirement: ArenaProgressionRequirement
}

enum ArenaProgressionRequirement: Equatable {
    case totalEnemiesDestroyed(Int)
    case bestScore(Int)
    case highestCombo(Int)

    var target: Int {
        switch self {
        case let .totalEnemiesDestroyed(target), let .bestScore(target), let .highestCombo(target):
            return target
        }
    }

    var label: String {
        switch self {
        case .totalEnemiesDestroyed:
            return "KILLS"
        case .bestScore:
            return "BEST"
        case .highestCombo:
            return "COMBO"
        }
    }

    func progress(in profile: RunProfile) -> Int {
        switch self {
        case .totalEnemiesDestroyed:
            return profile.totalEnemiesDestroyed
        case .bestScore:
            return profile.bestScore
        case .highestCombo:
            return profile.highestCombo
        }
    }

    func isMet(by profile: RunProfile) -> Bool {
        progress(in: profile) >= target
    }
}

struct ArenaAwardProgress: Equatable {
    let title: String
    let progress: Int
    let target: Int
    let isComplete: Bool
}

struct ArenaProgressionRules {
    static let redlineBestScoreRequirement = 5_000

    static let startingWeapons: [WeaponKind] = [
        .shockwave,
        .seekerSwarm,
        .razorShield
    ]

    static let weaponUnlockMilestones: [WeaponUnlockMilestone] = [
        WeaponUnlockMilestone(weapon: .freezeBurst, requirement: .totalEnemiesDestroyed(50)),
        WeaponUnlockMilestone(weapon: .gravityWell, requirement: .totalEnemiesDestroyed(100)),
        WeaponUnlockMilestone(weapon: .flameTrail, requirement: .bestScore(1_500)),
        WeaponUnlockMilestone(weapon: .chainLightning, requirement: .totalEnemiesDestroyed(175)),
        WeaponUnlockMilestone(weapon: .warpDash, requirement: .highestCombo(20)),
        WeaponUnlockMilestone(weapon: .powerWave, requirement: .bestScore(3_000)),
        WeaponUnlockMilestone(weapon: .novaBomb, requirement: .totalEnemiesDestroyed(300))
    ]

    static var allGameplayWeapons: [WeaponKind] {
        startingWeapons + weaponUnlockMilestones.map(\.weapon)
    }

    static func unlockedWeapons(for profile: RunProfile) -> [WeaponKind] {
        var unlockedWeapons = Set(startingWeapons)
        unlockedWeapons.formUnion(profile.unlockedWeapons)

        for milestone in weaponUnlockMilestones where milestone.requirement.isMet(by: profile) {
            unlockedWeapons.insert(milestone.weapon)
        }

        return allGameplayWeapons.filter { unlockedWeapons.contains($0) }
    }

    static func newlyUnlockedWeapons(before previousProfile: RunProfile, after updatedProfile: RunProfile) -> [WeaponKind] {
        let previous = Set(unlockedWeapons(for: previousProfile))
        let updated = Set(unlockedWeapons(for: updatedProfile))

        return weaponUnlockMilestones
            .map(\.weapon)
            .filter { updated.contains($0) && !previous.contains($0) }
    }

    static func allGameplayWeaponsUnlocked(profile: RunProfile) -> Bool {
        Set(unlockedWeapons(for: profile)) == Set(allGameplayWeapons)
    }

    static func isRedlineAvailable(profile: RunProfile) -> Bool {
        profile.bestScore >= redlineBestScoreRequirement
    }

    static func isDailyAvailable(profile: RunProfile) -> Bool {
        allGameplayWeaponsUnlocked(profile: profile)
    }

    static func filteredWeaponCycle(_ cycle: [WeaponKind], profile: RunProfile) -> [WeaponKind] {
        let unlocked = Set(unlockedWeapons(for: profile))
        let filteredCycle = cycle.filter { unlocked.contains($0) }
        return filteredCycle.isEmpty ? startingWeapons : filteredCycle
    }

    static func nextUnlockText(profile: RunProfile) -> String {
        if let milestone = weaponUnlockMilestones.first(where: { !unlockedWeapons(for: profile).contains($0.weapon) }) {
            return unlockText(
                title: "NEXT \(milestone.weapon.displayName.uppercased())",
                progress: milestone.requirement.progress(in: profile),
                target: milestone.requirement.target,
                label: milestone.requirement.label
            )
        }

        if !isRedlineAvailable(profile: profile) {
            return unlockText(
                title: "REDLINE",
                progress: profile.bestScore,
                target: redlineBestScoreRequirement,
                label: "BEST"
            )
        }

        return "ALL LOCAL MODES READY"
    }

    static func awardProgress(for id: ArenaAwardID, profile: RunProfile) -> ArenaAwardProgress {
        let progress: Int
        let target: Int

        switch id {
        case .comboSpark:
            progress = profile.highestCombo
            target = 10
        case .scoreCrest:
            progress = profile.bestScore
            target = 5_000
        case .freezeShatter:
            progress = profile.totalEnemiesDestroyed
            target = 25
        case .dangerGrab:
            progress = profile.totalRuns
            target = 5
        case .weaponMaster:
            progress = unlockedWeapons(for: profile).count
            target = allGameplayWeapons.count
        case .survivor:
            progress = Int(profile.longestSurvivalTime)
            target = 120
        }

        let clampedTarget = max(1, target)
        let clampedProgress = max(0, min(progress, clampedTarget))

        return ArenaAwardProgress(
            title: id.displayName.uppercased(),
            progress: clampedProgress,
            target: clampedTarget,
            isComplete: clampedProgress >= clampedTarget
        )
    }

    static func completedAwardIDs(for profile: RunProfile) -> [ArenaAwardID] {
        ArenaAwardID.allCases.filter { awardProgress(for: $0, profile: profile).isComplete }
    }

    static func newlyEarnedAwardIDs(before previousProfile: RunProfile, after updatedProfile: RunProfile) -> [ArenaAwardID] {
        let previous = previousProfile.earnedAwardIDs.union(completedAwardIDs(for: previousProfile))
        let updated = Set(completedAwardIDs(for: updatedProfile))

        return ArenaAwardID.allCases.filter { updated.contains($0) && !previous.contains($0) }
    }

    static func awardSummaryText(ids: [ArenaAwardID]) -> String? {
        guard !ids.isEmpty else {
            return nil
        }

        let names = ids.prefix(2).map { $0.displayName.uppercased() }
        let suffix = ids.count > 2 ? " +\(ids.count - 2)" : ""
        return "AWARDS \(names.joined(separator: ", "))\(suffix)"
    }

    static func unlockSummaryText(weapons: [WeaponKind]) -> String? {
        guard !weapons.isEmpty else {
            return nil
        }

        let names = weapons.prefix(2).map { $0.displayName.uppercased() }
        let suffix = weapons.count > 2 ? " +\(weapons.count - 2)" : ""
        return "UNLOCK \(names.joined(separator: ", "))\(suffix)"
    }

    static func normalizedUnlockedWeapons(_ weapons: Set<WeaponKind>) -> Set<WeaponKind> {
        Set(allGameplayWeapons).intersection(weapons).union(startingWeapons)
    }

    private static func unlockText(title: String, progress: Int, target: Int, label: String) -> String {
        "\(title) \(min(max(0, progress), target))/\(target) \(label)"
    }
}
