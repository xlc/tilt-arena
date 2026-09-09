import Foundation
import Logging

struct GameCenterScoreSubmission: Codable, Equatable {
    let runKey: String
    let leaderboardID: String
    let score: Int
    let context: Int
    let createdAt: Date

    var queueKey: String {
        "\(leaderboardID)|\(runKey)"
    }

    fileprivate init(
        runKey: String,
        leaderboardID: String,
        score: Int,
        context: Int,
        createdAt: Date
    ) {
        self.runKey = runKey
        self.leaderboardID = leaderboardID
        self.score = max(0, score)
        self.context = context
        self.createdAt = createdAt
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
    private let logger: Logger

    init(
        defaults: UserDefaults = .standard,
        pendingSubmissionsKey: String = "tiltArena.gameCenter.pendingScores.v\(ArenaRunContext.currentRulesVersion)",
        maxPendingSubmissions: Int = 25,
        logger: Logger = AppDiagnostics.logger(.gameCenter)
    ) {
        self.defaults = defaults
        self.pendingSubmissionsKey = pendingSubmissionsKey
        self.maxPendingSubmissions = max(1, maxPendingSubmissions)
        self.logger = logger
    }

    var pendingSubmissions: [GameCenterScoreSubmission] {
        get {
            guard let data = defaults.data(forKey: pendingSubmissionsKey) else {
                return []
            }

            let submissions: [GameCenterScoreSubmission]
            do {
                submissions = try JSONDecoder().decode([GameCenterScoreSubmission].self, from: data)
            } catch {
                logger.warning("game_center.score_queue_load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
                defaults.removeObject(forKey: pendingSubmissionsKey)
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

    private func save(_ submissions: [GameCenterScoreSubmission]) {
        do {
            defaults.set(try JSONEncoder().encode(submissions), forKey: pendingSubmissionsKey)
        } catch {
            logger.error("game_center.score_queue_save_failed", error: error, metadata: [
                "count": "\(submissions.count)"
            ])
        }
    }

    private func normalized(_ submissions: [GameCenterScoreSubmission]) -> [GameCenterScoreSubmission] {
        var seenQueueKeys = Set<String>()
        let deduplicated = submissions.compactMap { submission -> GameCenterScoreSubmission? in
            let runKey = submission.runKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let leaderboardID = submission.leaderboardID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !runKey.isEmpty, !leaderboardID.isEmpty else {
                return nil
            }

            let normalizedSubmission = GameCenterScoreSubmission(
                runKey: runKey,
                leaderboardID: leaderboardID,
                score: submission.score,
                context: submission.context,
                createdAt: submission.createdAt
            )
            return seenQueueKeys.insert(normalizedSubmission.queueKey).inserted
                ? normalizedSubmission
                : nil
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

    init(achievement: GameCenterIdentifiers.Achievement, percentComplete: Double, createdAt: Date = Date()) {
        self.init(
            achievementID: achievement.rawValue,
            percentComplete: percentComplete,
            createdAt: createdAt
        )
    }

    fileprivate init(achievementID: String, percentComplete: Double, createdAt: Date) {
        self.achievementID = achievementID
        self.percentComplete = Self.normalizedPercent(percentComplete)
        self.createdAt = createdAt
    }

    private static func normalizedPercent(_ percentComplete: Double) -> Double {
        guard percentComplete.isFinite else {
            return 0
        }
        return min(100, max(0, percentComplete))
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
            completed(.firstEnemyClear)
        ]

        // Enemy clears happen during the frame-critical gameplay loop. Report
        // completed combo milestones immediately, while runFinished reports
        // partial progress once per run, instead of issuing a Game Center
        // request after every increase in combo count.
        if maxCombo >= 10 {
            progress.append(completed(.combo10))
        }
        if maxCombo >= 50 {
            progress.append(completed(.combo50))
        }

        if weaponKind != nil && count >= 2 {
            progress.append(completed(.firstChainReaction))
        }

        return progress
    }

    private static func runFinishedProgress(_ summary: RunSummary) -> [GameCenterAchievementProgress] {
        guard summary.rulesVersion == ArenaRunContext.currentRulesVersion else { return [] }
        var progress = [
            completed(.firstRun),
            milestone(.combo10, currentValue: Double(summary.maxCombo), targetValue: 10),
            milestone(.combo50, currentValue: Double(summary.maxCombo), targetValue: 50),
            milestone(.survive60, currentValue: summary.survivalTime, targetValue: 60)
        ]

        if summary.mode == .classic {
            progress.append(milestone(.score100000, currentValue: Double(summary.score), targetValue: 100_000))
        }

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
    private let logger: Logger

    init(
        defaults: UserDefaults = .standard,
        pendingProgressKey: String = "tiltArena.gameCenter.pendingAchievements.v\(ArenaRunContext.currentRulesVersion)",
        reportedProgressKey: String = "tiltArena.gameCenter.reportedAchievementProgress.v\(ArenaRunContext.currentRulesVersion)",
        maxPendingProgress: Int = 25,
        logger: Logger = AppDiagnostics.logger(.gameCenter)
    ) {
        self.defaults = defaults
        self.pendingProgressKey = pendingProgressKey
        self.reportedProgressKey = reportedProgressKey
        self.maxPendingProgress = max(1, maxPendingProgress)
        self.logger = logger
    }

    var pendingProgress: [GameCenterAchievementProgress] {
        get {
            guard let data = defaults.data(forKey: pendingProgressKey) else {
                return []
            }

            let progress: [GameCenterAchievementProgress]
            do {
                progress = try JSONDecoder().decode([GameCenterAchievementProgress].self, from: data)
            } catch {
                logger.warning("game_center.achievement_queue_load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
                defaults.removeObject(forKey: pendingProgressKey)
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

    func discardFailedProgress(_ failed: [GameCenterAchievementProgress]) {
        pendingProgress = pendingProgress.filter { pending in
            !failed.contains { $0.achievementID == pending.achievementID && $0.percentComplete >= pending.percentComplete }
        }
    }

    private var reportedProgressByAchievementID: [String: Double] {
        get {
            guard let data = defaults.data(forKey: reportedProgressKey) else {
                return [:]
            }

            let progress: [String: Double]
            do {
                progress = try JSONDecoder().decode([String: Double].self, from: data)
            } catch {
                logger.warning("game_center.reported_progress_load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
                defaults.removeObject(forKey: reportedProgressKey)
                return [:]
            }

            return progress.mapValues { min(100, max(0, $0)) }
        }
        set {
            let normalizedProgress = newValue.mapValues { min(100, max(0, $0)) }
            do {
                defaults.set(try JSONEncoder().encode(normalizedProgress), forKey: reportedProgressKey)
            } catch {
                logger.error("game_center.reported_progress_save_failed", error: error, metadata: [
                    "count": "\(normalizedProgress.count)"
                ])
            }
        }
    }

    private func savePendingProgress(_ progress: [GameCenterAchievementProgress]) {
        do {
            defaults.set(try JSONEncoder().encode(progress), forKey: pendingProgressKey)
        } catch {
            logger.error("game_center.achievement_queue_save_failed", error: error, metadata: [
                "count": "\(progress.count)"
            ])
        }
    }

    private func normalized(_ progress: [GameCenterAchievementProgress]) -> [GameCenterAchievementProgress] {
        var byAchievementID: [String: GameCenterAchievementProgress] = [:]
        for item in progress {
            let achievementID = item.achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedItem = GameCenterAchievementProgress(
                achievementID: achievementID,
                percentComplete: item.percentComplete,
                createdAt: item.createdAt
            )
            guard !achievementID.isEmpty, normalizedItem.percentComplete > 0 else {
                continue
            }

            if let existing = byAchievementID[achievementID],
               existing.percentComplete >= normalizedItem.percentComplete {
                continue
            }

            byAchievementID[achievementID] = normalizedItem
        }

        let orderedKnownAchievements = GameCenterIdentifiers.Achievement.allCases
            .compactMap { byAchievementID.removeValue(forKey: $0.rawValue) }
        let orderedUnknownAchievements = byAchievementID.values.sorted { lhs, rhs in
            lhs.achievementID < rhs.achievementID
        }

        return Array((orderedKnownAchievements + orderedUnknownAchievements).suffix(maxPendingProgress))
    }
}
