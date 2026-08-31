import Foundation
import Logging

struct RunProfile: Codable, Equatable {
    /// Persisted survival time feeds whole-second progression. `Double(Int.max)`
    /// rounds above `Int.max`, so its preceding representable value is the
    /// largest duration that can be converted without trapping.
    static let maximumPersistedSurvivalTime = TimeInterval(Int.max).nextDown

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

        let repairedFieldCount = normalizePersistedNumericFields()
        (decoder.userInfo[RunProfileDecodingContext.repairObserverKey]
            as? RunProfileDecodingRepairObserver)?.record(repairedFieldCount)

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
        totalRuns = Self.saturatedSum(totalRuns, 1)
        totalEnemiesDestroyed = Self.saturatedSum(
            totalEnemiesDestroyed,
            max(0, summary.enemiesDestroyed)
        )

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

    private static func saturatedSum(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }

    static func normalizedPersistedSurvivalTime(_ value: TimeInterval) -> TimeInterval {
        guard !value.isNaN else {
            return 0
        }

        return min(maximumPersistedSurvivalTime, max(0, value))
    }

    @discardableResult
    private mutating func normalizePersistedNumericFields() -> Int {
        var repairedFieldCount = 0

        if bestScore < 0 {
            bestScore = 0
            repairedFieldCount += 1
        }
        if highestCombo < 0 {
            highestCombo = 0
            repairedFieldCount += 1
        }

        let normalizedSurvivalTime = Self.normalizedPersistedSurvivalTime(longestSurvivalTime)
        if normalizedSurvivalTime != longestSurvivalTime {
            longestSurvivalTime = normalizedSurvivalTime
            repairedFieldCount += 1
        }

        if totalRuns < 0 {
            totalRuns = 0
            repairedFieldCount += 1
        }
        if totalEnemiesDestroyed < 0 {
            totalEnemiesDestroyed = 0
            repairedFieldCount += 1
        }

        return repairedFieldCount
    }
}

private enum RunProfileDecodingContext {
    static let repairObserverKey = CodingUserInfoKey(
        rawValue: "com.xlc.TiltArena.runProfileRepairObserver"
    )!
}

private final class RunProfileDecodingRepairObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRepairedFieldCount = 0

    var repairedFieldCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedRepairedFieldCount
    }

    func record(_ repairedFieldCount: Int) {
        lock.lock()
        storedRepairedFieldCount = repairedFieldCount
        lock.unlock()
    }
}

final class RunProfileStore {
    private let defaults: UserDefaults
    private let profileKey = "tiltArena.runProfile"
    private let logger: Logger

    init(
        defaults: UserDefaults = .standard,
        logger: Logger = AppDiagnostics.logger(.profile)
    ) {
        self.defaults = defaults
        self.logger = logger
    }

    var profile: RunProfile {
        get {
            guard let data = defaults.data(forKey: profileKey) else {
                return RunProfile()
            }

            do {
                let repairObserver = RunProfileDecodingRepairObserver()
                let decoder = JSONDecoder()
                decoder.userInfo[RunProfileDecodingContext.repairObserverKey] = repairObserver
                let profile = try decoder.decode(RunProfile.self, from: data)
                let repairedFieldCount = repairObserver.repairedFieldCount

                if repairedFieldCount > 0 {
                    do {
                        try persist(profile)
                        logger.warning("profile.numeric_fields_repaired", metadata: [
                            "field_count": "\(repairedFieldCount)"
                        ])
                    } catch {
                        logger.error("profile.repair_save_failed", error: error, metadata: [
                            "field_count": "\(repairedFieldCount)"
                        ])
                    }
                }

                return profile
            } catch {
                logger.warning("profile.load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
                defaults.removeObject(forKey: profileKey)
                return RunProfile()
            }
        }
        set {
            do {
                try persist(newValue)
            } catch {
                logger.error("profile.save_failed", error: error)
            }
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

    private func persist(_ profile: RunProfile) throws {
        defaults.set(try JSONEncoder().encode(profile), forKey: profileKey)
    }
}
