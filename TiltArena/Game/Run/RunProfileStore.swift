import Foundation
import Logging

struct RunRecord: Codable, Equatable {
    var bestScore = 0
    var highestCombo = 0
    var longestSurvivalTime: TimeInterval = 0
    var attempts = 0

    mutating func record(_ summary: RunSummary) {
        bestScore = max(bestScore, summary.score)
        highestCombo = max(highestCombo, summary.maxCombo)
        longestSurvivalTime = max(longestSurvivalTime, summary.survivalTime)
        attempts = attempts == Int.max ? Int.max : attempts + 1
    }

    mutating func normalize() -> Int {
        let previous = self
        bestScore = max(0, bestScore)
        highestCombo = max(0, highestCombo)
        longestSurvivalTime = RunProfile.normalizedPersistedSurvivalTime(longestSurvivalTime)
        attempts = max(0, attempts)
        return [
            bestScore != previous.bestScore, highestCombo != previous.highestCombo,
            longestSurvivalTime != previous.longestSurvivalTime, attempts != previous.attempts
        ].filter { $0 }.count
    }
}

struct RunProfile: Codable, Equatable {
    let rulesVersion: Int
    /// Persisted survival time feeds whole-second progression. `Double(Int.max)`
    /// rounds above `Int.max`, so its preceding representable value is the
    /// largest duration that can be converted without trapping.
    static let maximumPersistedSurvivalTime = TimeInterval(Int.max).nextDown

    var lifetimeBestScore = 0
    var lifetimeHighestCombo = 0
    var lifetimeLongestSurvivalTime: TimeInterval = 0
    var totalRuns = 0
    var totalEnemiesDestroyed = 0
    var recentRuns: [RunSummary] = []
    var unlockedWeapons: Set<WeaponKind> = Set(ArenaProgressionRules.startingWeapons)
    var earnedAwardIDs: Set<ArenaAwardID> = []
    var modeRecords: [ArenaModeKind: RunRecord] = [:]
    var dailyRecords: [Int: RunRecord] = [:]

    private enum CodingKeys: String, CodingKey {
        case rulesVersion
        case lifetimeBestScore
        case lifetimeHighestCombo
        case lifetimeLongestSurvivalTime
        case totalRuns
        case totalEnemiesDestroyed
        case recentRuns
        case unlockedWeapons
        case earnedAwardIDs
        case modeRecords
        case dailyRecords
    }

    init() { rulesVersion = ArenaRunContext.currentRulesVersion }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        guard rulesVersion == ArenaRunContext.currentRulesVersion else {
            throw DecodingError.dataCorruptedError(forKey: .rulesVersion, in: container, debugDescription: "Unsupported game rules")
        }
        lifetimeBestScore = try container.decode(Int.self, forKey: .lifetimeBestScore)
        lifetimeHighestCombo = try container.decode(Int.self, forKey: .lifetimeHighestCombo)
        lifetimeLongestSurvivalTime = try container.decode(TimeInterval.self, forKey: .lifetimeLongestSurvivalTime)
        totalRuns = try container.decode(Int.self, forKey: .totalRuns)
        totalEnemiesDestroyed = try container.decode(Int.self, forKey: .totalEnemiesDestroyed)
        recentRuns = try container.decode([RunSummary].self, forKey: .recentRuns)
        unlockedWeapons = try container.decode(Set<WeaponKind>.self, forKey: .unlockedWeapons)
        earnedAwardIDs = try container.decode(Set<ArenaAwardID>.self, forKey: .earnedAwardIDs)

        modeRecords = try container.decode([ArenaModeKind: RunRecord].self, forKey: .modeRecords)
        dailyRecords = try container.decode([Int: RunRecord].self, forKey: .dailyRecords)

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

        lifetimeBestScore = max(lifetimeBestScore, summary.score)
        lifetimeHighestCombo = max(lifetimeHighestCombo, summary.maxCombo)
        lifetimeLongestSurvivalTime = max(lifetimeLongestSurvivalTime, summary.survivalTime)
        totalRuns = Self.saturatedSum(totalRuns, 1)
        totalEnemiesDestroyed = Self.saturatedSum(
            totalEnemiesDestroyed,
            max(0, summary.enemiesDestroyed)
        )

        recentRuns.insert(summary, at: 0)
        recentRuns = Array(recentRuns.prefix(max(0, recentRunLimit)))

        if summary.mode == .daily {
            dailyRecords[summary.sequenceSeed, default: RunRecord()].record(summary)
            for seed in dailyRecords.keys.sorted().dropLast(90) {
                dailyRecords.removeValue(forKey: seed)
            }
        } else {
            modeRecords[summary.mode, default: RunRecord()].record(summary)
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

    func competitiveRecord(for mode: ArenaModeKind, seed: Int? = nil) -> RunRecord {
        if mode == .daily {
            return dailyRecords[seed ?? ArenaModeRules.dailySeed()] ?? RunRecord()
        }
        return modeRecords[mode] ?? RunRecord()
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

        if lifetimeBestScore < 0 {
            lifetimeBestScore = 0
            repairedFieldCount += 1
        }
        if lifetimeHighestCombo < 0 {
            lifetimeHighestCombo = 0
            repairedFieldCount += 1
        }

        let normalizedSurvivalTime = Self.normalizedPersistedSurvivalTime(lifetimeLongestSurvivalTime)
        if normalizedSurvivalTime != lifetimeLongestSurvivalTime {
            lifetimeLongestSurvivalTime = normalizedSurvivalTime
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

        for mode in modeRecords.keys {
            repairedFieldCount += modeRecords[mode]?.normalize() ?? 0
        }
        for seed in dailyRecords.keys {
            repairedFieldCount += dailyRecords[seed]?.normalize() ?? 0
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
