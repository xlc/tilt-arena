import Foundation

struct GameCenterScoreSubmission: Codable, Equatable {
    let runKey: String
    let leaderboardID: String
    let score: Int
    let context: Int
    let createdAt: Date

    var queueKey: String {
        "\(leaderboardID)|\(runKey)"
    }

    static func classicSurvival(from summary: RunSummary) -> GameCenterScoreSubmission {
        GameCenterScoreSubmission(
            runKey: [
                summary.mode.rawValue,
                String(summary.timestamp.timeIntervalSince1970.bitPattern),
                String(summary.score),
                String(summary.maxCombo),
                String(summary.enemiesDestroyed)
            ].joined(separator: ":"),
            leaderboardID: GameCenterIdentifiers.Leaderboard.classicSurvivalHighScore,
            score: max(0, summary.score),
            context: 0,
            createdAt: Date()
        )
    }
}

final class GameCenterScoreSubmissionStore {
    private let defaults: UserDefaults
    private let pendingSubmissionsKey: String
    private let maxPendingSubmissions: Int

    init(
        defaults: UserDefaults = .standard,
        pendingSubmissionsKey: String = "tiltArena.gameCenter.pendingScores",
        maxPendingSubmissions: Int = 25
    ) {
        self.defaults = defaults
        self.pendingSubmissionsKey = pendingSubmissionsKey
        self.maxPendingSubmissions = max(1, maxPendingSubmissions)
    }

    var pendingSubmissions: [GameCenterScoreSubmission] {
        get {
            guard
                let data = defaults.data(forKey: pendingSubmissionsKey),
                let submissions = try? JSONDecoder().decode([GameCenterScoreSubmission].self, from: data)
            else {
                return []
            }

            let normalizedSubmissions = normalized(submissions)
            if normalizedSubmissions != submissions {
                save(normalizedSubmissions)
            }
            return normalizedSubmissions
        }
        set {
            save(normalized(newValue))
        }
    }

    @discardableResult
    func enqueue(_ submission: GameCenterScoreSubmission) -> Bool {
        var submissions = pendingSubmissions
        guard !submissions.contains(where: { $0.queueKey == submission.queueKey }) else {
            return false
        }

        submissions.append(submission)
        pendingSubmissions = submissions
        return true
    }

    func removeSubmissions(withQueueKeys queueKeys: Set<String>) {
        guard !queueKeys.isEmpty else {
            return
        }

        pendingSubmissions = pendingSubmissions.filter { !queueKeys.contains($0.queueKey) }
    }

    func reset() {
        defaults.removeObject(forKey: pendingSubmissionsKey)
    }

    private func save(_ submissions: [GameCenterScoreSubmission]) {
        guard let data = try? JSONEncoder().encode(submissions) else {
            return
        }

        defaults.set(data, forKey: pendingSubmissionsKey)
    }

    private func normalized(_ submissions: [GameCenterScoreSubmission]) -> [GameCenterScoreSubmission] {
        var seenQueueKeys = Set<String>()
        let deduplicated = submissions.filter { submission in
            seenQueueKeys.insert(submission.queueKey).inserted
        }
        return Array(deduplicated.suffix(maxPendingSubmissions))
    }
}

enum GameCenterAchievementEvent: Equatable {
    case weaponOrbCollected
    case enemyClear(count: Int, weaponKind: WeaponKind?, maxCombo: Int)
    case runFinished(RunSummary)
}

struct GameCenterAchievementProgress: Codable, Equatable {
    let achievementID: String
    let percentComplete: Double
    let createdAt: Date

    var queueKey: String {
        achievementID
    }

    init(achievement: GameCenterIdentifiers.Achievement, percentComplete: Double, createdAt: Date = Date()) {
        self.achievementID = achievement.rawValue
        self.percentComplete = Self.normalizedPercent(percentComplete)
        self.createdAt = createdAt
    }

    private static func normalizedPercent(_ percentComplete: Double) -> Double {
        min(100, max(0, percentComplete))
    }
}

enum GameCenterAchievementProgressMapper {
    static func progress(for event: GameCenterAchievementEvent) -> [GameCenterAchievementProgress] {
        switch event {
        case .weaponOrbCollected:
            return [completed(.firstWeaponOrb)]
        case let .enemyClear(count, weaponKind, maxCombo):
            return enemyClearProgress(count: count, weaponKind: weaponKind, maxCombo: maxCombo)
        case let .runFinished(summary):
            return runFinishedProgress(summary)
        }
    }

    private static func enemyClearProgress(
        count: Int,
        weaponKind: WeaponKind?,
        maxCombo: Int
    ) -> [GameCenterAchievementProgress] {
        guard count > 0 else {
            return []
        }

        var progress = [
            completed(.firstEnemyClear),
            milestone(.combo10, currentValue: Double(maxCombo), targetValue: 10),
            milestone(.combo50, currentValue: Double(maxCombo), targetValue: 50)
        ]

        if weaponKind != nil && count >= 2 {
            progress.append(completed(.firstChainReaction))
        }

        return progress
    }

    private static func runFinishedProgress(_ summary: RunSummary) -> [GameCenterAchievementProgress] {
        guard summary.mode == .classic else {
            return []
        }

        var progress = [
            completed(.firstRun),
            milestone(.combo10, currentValue: Double(summary.maxCombo), targetValue: 10),
            milestone(.combo50, currentValue: Double(summary.maxCombo), targetValue: 50),
            milestone(.survive60, currentValue: summary.survivalTime, targetValue: 60),
            milestone(.score100000, currentValue: Double(summary.score), targetValue: 100_000)
        ]

        if summary.enemiesDestroyed > 0 {
            progress.append(completed(.firstEnemyClear))
        }

        return progress
    }

    private static func completed(_ achievement: GameCenterIdentifiers.Achievement) -> GameCenterAchievementProgress {
        GameCenterAchievementProgress(achievement: achievement, percentComplete: 100)
    }

    private static func milestone(
        _ achievement: GameCenterIdentifiers.Achievement,
        currentValue: Double,
        targetValue: Double
    ) -> GameCenterAchievementProgress {
        let percentComplete = targetValue > 0 ? currentValue / targetValue * 100 : 0
        return GameCenterAchievementProgress(achievement: achievement, percentComplete: percentComplete)
    }
}

final class GameCenterAchievementProgressStore {
    private let defaults: UserDefaults
    private let pendingProgressKey: String
    private let reportedProgressKey: String
    private let maxPendingProgress: Int

    init(
        defaults: UserDefaults = .standard,
        pendingProgressKey: String = "tiltArena.gameCenter.pendingAchievements",
        reportedProgressKey: String = "tiltArena.gameCenter.reportedAchievementProgress",
        maxPendingProgress: Int = 25
    ) {
        self.defaults = defaults
        self.pendingProgressKey = pendingProgressKey
        self.reportedProgressKey = reportedProgressKey
        self.maxPendingProgress = max(1, maxPendingProgress)
    }

    var pendingProgress: [GameCenterAchievementProgress] {
        get {
            guard
                let data = defaults.data(forKey: pendingProgressKey),
                let progress = try? JSONDecoder().decode([GameCenterAchievementProgress].self, from: data)
            else {
                return []
            }

            let normalizedProgress = normalized(progress)
            if normalizedProgress != progress {
                savePendingProgress(normalizedProgress)
            }
            return normalizedProgress
        }
        set {
            savePendingProgress(normalized(newValue))
        }
    }

    func reportableProgress(from progress: [GameCenterAchievementProgress]) -> [GameCenterAchievementProgress] {
        let reportedProgress = reportedProgressByAchievementID
        let pendingProgressByID = Dictionary(uniqueKeysWithValues: pendingProgress.map {
            ($0.achievementID, $0.percentComplete)
        })

        return normalized(progress).filter { item in
            let alreadyKnownProgress = max(
                reportedProgress[item.achievementID, default: 0],
                pendingProgressByID[item.achievementID, default: 0]
            )
            return item.percentComplete > alreadyKnownProgress
        }
    }

    @discardableResult
    func enqueue(_ progress: [GameCenterAchievementProgress]) -> [GameCenterAchievementProgress] {
        let newProgress = reportableProgress(from: progress)
        guard !newProgress.isEmpty else {
            return []
        }

        var updatedProgress = pendingProgress
        updatedProgress += newProgress
        pendingProgress = updatedProgress
        return newProgress
    }

    func markSubmitted(_ progress: [GameCenterAchievementProgress]) {
        guard !progress.isEmpty else {
            return
        }

        var reportedProgress = reportedProgressByAchievementID
        for item in progress {
            reportedProgress[item.achievementID] = max(
                reportedProgress[item.achievementID, default: 0],
                item.percentComplete
            )
        }

        reportedProgressByAchievementID = reportedProgress
        pendingProgress = pendingProgress.filter { item in
            item.percentComplete > reportedProgress[item.achievementID, default: 0]
        }
    }

    func removeProgress(withAchievementIDs achievementIDs: Set<String>) {
        guard !achievementIDs.isEmpty else {
            return
        }

        pendingProgress = pendingProgress.filter { !achievementIDs.contains($0.achievementID) }
    }

    func reset() {
        defaults.removeObject(forKey: pendingProgressKey)
        defaults.removeObject(forKey: reportedProgressKey)
    }

    private var reportedProgressByAchievementID: [String: Double] {
        get {
            guard
                let data = defaults.data(forKey: reportedProgressKey),
                let progress = try? JSONDecoder().decode([String: Double].self, from: data)
            else {
                return [:]
            }

            return progress.mapValues { min(100, max(0, $0)) }
        }
        set {
            let normalizedProgress = newValue.mapValues { min(100, max(0, $0)) }
            guard let data = try? JSONEncoder().encode(normalizedProgress) else {
                return
            }

            defaults.set(data, forKey: reportedProgressKey)
        }
    }

    private func savePendingProgress(_ progress: [GameCenterAchievementProgress]) {
        guard let data = try? JSONEncoder().encode(progress) else {
            return
        }

        defaults.set(data, forKey: pendingProgressKey)
    }

    private func normalized(_ progress: [GameCenterAchievementProgress]) -> [GameCenterAchievementProgress] {
        var byAchievementID: [String: GameCenterAchievementProgress] = [:]
        for item in progress {
            guard item.percentComplete > 0 else {
                continue
            }

            if let existing = byAchievementID[item.achievementID],
               existing.percentComplete >= item.percentComplete {
                continue
            }

            byAchievementID[item.achievementID] = item
        }

        let orderedKnownAchievements = GameCenterIdentifiers.Achievement.allCases
            .compactMap { byAchievementID.removeValue(forKey: $0.rawValue) }
        let orderedUnknownAchievements = byAchievementID.values.sorted { lhs, rhs in
            lhs.achievementID < rhs.achievementID
        }

        return Array((orderedKnownAchievements + orderedUnknownAchievements).suffix(maxPendingProgress))
    }
}
