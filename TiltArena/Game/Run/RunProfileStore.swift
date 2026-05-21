import Foundation

struct RunProfile: Codable, Equatable {
    var bestScore = 0
    var highestCombo = 0
    var longestSurvivalTime: TimeInterval = 0
    var totalRuns = 0
    var totalEnemiesDestroyed = 0
    var recentRuns: [RunSummary] = []
    var unlockedWeapons: Set<WeaponKind> = Set(ArenaProgressionRules.startingWeapons)
    var earnedAwardIDs: Set<ArenaAwardID> = []
    var dailyParticipationSeeds: Set<Int> = []

    private enum CodingKeys: String, CodingKey {
        case bestScore
        case highestCombo
        case longestSurvivalTime
        case totalRuns
        case totalEnemiesDestroyed
        case recentRuns
        case unlockedWeapons
        case earnedAwardIDs
        case dailyParticipationSeeds
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        highestCombo = try container.decodeIfPresent(Int.self, forKey: .highestCombo) ?? 0
        longestSurvivalTime = try container.decodeIfPresent(TimeInterval.self, forKey: .longestSurvivalTime) ?? 0
        totalRuns = try container.decodeIfPresent(Int.self, forKey: .totalRuns) ?? 0
        totalEnemiesDestroyed = try container.decodeIfPresent(Int.self, forKey: .totalEnemiesDestroyed) ?? 0
        recentRuns = try container.decodeIfPresent([RunSummary].self, forKey: .recentRuns) ?? []
        unlockedWeapons = try container.decodeIfPresent(Set<WeaponKind>.self, forKey: .unlockedWeapons) ?? []
        earnedAwardIDs = try container.decodeIfPresent(Set<ArenaAwardID>.self, forKey: .earnedAwardIDs) ?? []
        dailyParticipationSeeds = try container.decodeIfPresent(Set<Int>.self, forKey: .dailyParticipationSeeds) ?? []

        unlockedWeapons = ArenaProgressionRules.normalizedUnlockedWeapons(
            Set(ArenaProgressionRules.unlockedWeapons(for: self))
        )
        earnedAwardIDs.formUnion(ArenaProgressionRules.completedAwardIDs(for: self))
    }

    @discardableResult
    mutating func record(_ summary: RunSummary, recentRunLimit: Int = 5) -> ArenaProgressionResult {
        let previousProfile = self

        bestScore = max(bestScore, summary.score)
        highestCombo = max(highestCombo, summary.maxCombo)
        longestSurvivalTime = max(longestSurvivalTime, summary.survivalTime)
        totalRuns += 1
        totalEnemiesDestroyed += summary.enemiesDestroyed

        recentRuns.insert(summary, at: 0)
        recentRuns = Array(recentRuns.prefix(max(0, recentRunLimit)))

        if summary.mode == .daily {
            dailyParticipationSeeds.insert(ArenaModeRules.dailySeed(for: summary.timestamp))
        }

        let newlyUnlockedWeapons = ArenaProgressionRules.newlyUnlockedWeapons(
            before: previousProfile,
            after: self
        )
        unlockedWeapons = ArenaProgressionRules.normalizedUnlockedWeapons(
            Set(ArenaProgressionRules.unlockedWeapons(for: self))
        )

        let newlyEarnedAwardIDs = ArenaProgressionRules.newlyEarnedAwardIDs(
            before: previousProfile,
            after: self
        )
        earnedAwardIDs.formUnion(ArenaProgressionRules.completedAwardIDs(for: self))

        return ArenaProgressionResult(
            profile: self,
            newlyUnlockedWeapons: newlyUnlockedWeapons,
            newlyEarnedAwardIDs: newlyEarnedAwardIDs
        )
    }
}

final class RunProfileStore {
    private let defaults: UserDefaults
    private let profileKey = "tiltArena.runProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var profile: RunProfile {
        get {
            guard
                let data = defaults.data(forKey: profileKey),
                let profile = try? JSONDecoder().decode(RunProfile.self, from: data)
            else {
                return RunProfile()
            }

            return profile
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            defaults.set(data, forKey: profileKey)
        }
    }

    @discardableResult
    func record(_ summary: RunSummary) -> ArenaProgressionResult {
        var updatedProfile = profile
        let result = updatedProfile.record(summary)
        profile = updatedProfile
        return result
    }

    func reset() {
        defaults.removeObject(forKey: profileKey)
    }
}
