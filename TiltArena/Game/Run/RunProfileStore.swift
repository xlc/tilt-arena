import Foundation

struct RunProfile: Codable, Equatable {
    var bestScore = 0
    var highestCombo = 0
    var longestSurvivalTime: TimeInterval = 0
    var totalRuns = 0
    var totalEnemiesDestroyed = 0
    var recentRuns: [RunSummary] = []

    mutating func record(_ summary: RunSummary, recentRunLimit: Int = 5) {
        bestScore = max(bestScore, summary.score)
        highestCombo = max(highestCombo, summary.maxCombo)
        longestSurvivalTime = max(longestSurvivalTime, summary.survivalTime)
        totalRuns += 1
        totalEnemiesDestroyed += summary.enemiesDestroyed

        recentRuns.insert(summary, at: 0)
        recentRuns = Array(recentRuns.prefix(max(0, recentRunLimit)))
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
    func record(_ summary: RunSummary) -> RunProfile {
        var updatedProfile = profile
        updatedProfile.record(summary)
        profile = updatedProfile
        return updatedProfile
    }
}
