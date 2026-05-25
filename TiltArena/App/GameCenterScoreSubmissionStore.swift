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
