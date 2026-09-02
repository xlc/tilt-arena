import Foundation
#if canImport(GameKit)
import GameKit
#endif
import Logging

enum GameCenterFailurePolicy {
    static func normalizedTimeout(_ timeout: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        guard timeout.isFinite else {
            return fallback
        }
        return max(0, timeout)
    }

    static func shouldQueue(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        #if canImport(GameKit)
        guard nsError.domain == GKErrorDomain, let code = GKError.Code(rawValue: nsError.code) else {
            return false
        }

        switch code {
        case .unknown, .communicationsFailure, .notAuthenticated, .authenticationInProgress, .connectionTimeout:
            return true
        default:
            return false
        }
        #else
        return false
        #endif
    }
}

enum GameCenterLogMetadata {
    static func achievementProgress(_ progress: [GameCenterAchievementProgress]) -> Logger.Metadata {
        [
            "achievementCount": "\(progress.count)",
            "maxPercentComplete": "\(progress.map(\.percentComplete).max() ?? 0)"
        ]
    }

    static func scoreSubmission(
        _ submission: GameCenterScoreSubmission,
        additionalMetadata: Logger.Metadata = [:]
    ) -> Logger.Metadata {
        var metadata: Logger.Metadata = [
            "leaderboardID": "\(submission.leaderboardID)",
            "score": "\(submission.score)"
        ]
        metadata.merge(additionalMetadata) { _, new in new }
        return metadata
    }
}

@MainActor
final class GameCenterOperationWatchdog {
    private var task: Task<Void, Never>?
    private(set) var requestID: UUID?

    func begin() -> UUID {
        cancel()
        let requestID = UUID()
        self.requestID = requestID
        return requestID
    }

    func isCurrent(_ requestID: UUID) -> Bool {
        self.requestID == requestID
    }

    @discardableResult
    func complete(_ requestID: UUID) -> Bool {
        guard isCurrent(requestID) else {
            return false
        }

        cancel()
        return true
    }

    func arm(
        requestID: UUID,
        after timeout: TimeInterval,
        operation: @escaping @MainActor @Sendable () -> Void
    ) {
        guard isCurrent(requestID) else {
            return
        }
        guard timeout > 0 else {
            operation()
            return
        }

        task = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(timeout))
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            operation()
        }
    }

    func cancel() {
        requestID = nil
        task?.cancel()
        task = nil
    }
}
