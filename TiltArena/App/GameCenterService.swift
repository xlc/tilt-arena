// swiftlint:disable file_length
import Foundation
#if canImport(GameKit)
import GameKit
#endif
import Logging
import UIKit

extension Notification.Name {
    static let gameCenterMenuStatusDidChange = Notification.Name("TiltArena.gameCenterMenuStatusDidChange")
}

@MainActor
protocol GameCenterAuthenticationPresenting: AnyObject {
    func presentGameCenterAuthentication(_ viewController: UIViewController)
}

@MainActor
protocol GameCenterLeaderboardPresenting: AnyObject {
    func presentGameCenterLeaderboard(_ viewController: UIViewController)
}

@MainActor
protocol GameCenterLeaderboardFactory {
    func makeClassicSurvivalLeaderboardViewController() -> UIViewController?
}

@MainActor
protocol GameCenterLocalPlayerClient: AnyObject {
    var isAvailable: Bool { get }
    var isAuthenticated: Bool { get }

    func setAuthenticateHandler(
        _ handler: @escaping @MainActor (_ viewController: UIViewController?, _ error: Error?) -> Void
    )

    func submitScore(
        _ score: Int,
        context: Int,
        leaderboardIDs: [String],
        completion: @escaping @MainActor (Error?) -> Void
    )

    func reportAchievements(
        _ progress: [GameCenterAchievementProgress],
        completion: @escaping @MainActor (Error?) -> Void
    )
}

enum GameCenterAuthenticationState: Equatable {
    case notStarted
    case unsupported
    case authenticating
    case needsUserAuthentication
    case authenticated
    case declined(GameCenterAuthenticationFailure)
    case failed(GameCenterAuthenticationFailure)

    var isAuthenticated: Bool {
        self == .authenticated
    }
}

enum GameCenterAuthenticationFailureReason: String, Equatable {
    case cancelled
    case denied
    case unavailable
    case failed
}

enum GameCenterLeaderboardUnavailableReason: Equatable {
    case unsupported
    case authenticationRequired
}

enum GameCenterLeaderboardPresentationResult: Equatable {
    case presented
    case unavailable(GameCenterLeaderboardUnavailableReason)
}

enum GameCenterMenuStatus: Equatable {
    case hidden
    case ready
    case signInRequired
    case unavailable
    case syncing

    var menuMessage: String? {
        switch self {
        case .hidden:
            return nil
        case .ready:
            return "GAME CENTER READY"
        case .signInRequired:
            return "SIGN IN TO VIEW RANKS"
        case .unavailable:
            return "GAME CENTER UNAVAILABLE"
        case .syncing:
            return "GAME CENTER SYNCING"
        }
    }
}

struct GameCenterAuthenticationFailure: Equatable {
    let reason: GameCenterAuthenticationFailureReason
    let domain: String
    let code: Int

    static func make(from error: Error) -> GameCenterAuthenticationFailure {
        let nsError = error as NSError
        return GameCenterAuthenticationFailure(
            reason: reason(for: nsError),
            domain: nsError.domain,
            code: nsError.code
        )
    }

    private static func reason(for error: NSError) -> GameCenterAuthenticationFailureReason {
        #if canImport(GameKit)
        guard error.domain == GKErrorDomain, let code = GKError.Code(rawValue: error.code) else {
            return .failed
        }

        switch code {
        case .cancelled:
            return .cancelled
        case .userDenied, .notAuthenticated, .notAuthorized, .parentalControlsBlocked, .underage:
            return .denied
        case .notSupported, .apiNotAvailable:
            return .unavailable
        default:
            return .failed
        }
        #else
        return .failed
        #endif
    }
}

@MainActor
final class GameCenterService {
    static let shared = GameCenterService()

    private let localPlayer: GameCenterLocalPlayerClient
    private let scoreSubmissionStore: GameCenterScoreSubmissionStore
    private let achievementProgressStore: GameCenterAchievementProgressStore
    private let leaderboardFactory: GameCenterLeaderboardFactory
    private let logger: Logger
    private var hasInstalledAuthenticationHandler = false
    private var shouldSuppressAutomaticPrompt = false
    private weak var authenticationPresenter: GameCenterAuthenticationPresenting?
    private var canPresentAuthenticationPrompt = false
    private var isRetryingQueuedScores = false
    private var isRetryingQueuedAchievements = false

    private(set) var authenticationState: GameCenterAuthenticationState = .notStarted

    var menuStatus: GameCenterMenuStatus {
        if isRetryingQueuedScores || isRetryingQueuedAchievements {
            return .syncing
        }

        guard localPlayer.isAvailable else {
            return .unavailable
        }

        if localPlayer.isAuthenticated || authenticationState == .authenticated {
            return .ready
        }

        switch authenticationState {
        case .notStarted, .needsUserAuthentication, .declined:
            return .signInRequired
        case .authenticating:
            return .syncing
        case .unsupported, .failed:
            return .unavailable
        case .authenticated:
            return .ready
        }
    }

    init(
        localPlayer: GameCenterLocalPlayerClient = GameKitLocalPlayerClient(),
        scoreSubmissionStore: GameCenterScoreSubmissionStore = GameCenterScoreSubmissionStore(),
        achievementProgressStore: GameCenterAchievementProgressStore = GameCenterAchievementProgressStore(),
        leaderboardFactory: GameCenterLeaderboardFactory = GameKitLeaderboardFactory(),
        logger: Logger = AppDiagnostics.logger(.gameCenter)
    ) {
        self.localPlayer = localPlayer
        self.scoreSubmissionStore = scoreSubmissionStore
        self.achievementProgressStore = achievementProgressStore
        self.leaderboardFactory = leaderboardFactory
        self.logger = logger
    }

    func authenticate(
        presenter: GameCenterAuthenticationPresenting?,
        allowsPrompt: Bool = true
    ) {
        guard localPlayer.isAvailable else {
            updateState(.unsupported)
            logger.info("game_center.auth_unsupported")
            return
        }

        if localPlayer.isAuthenticated {
            updateState(.authenticated)
            logger.notice("game_center.authenticated")
            retryQueuedSubmissions()
            return
        }

        let canPresentPrompt = allowsPrompt && !shouldSuppressAutomaticPrompt
        authenticationPresenter = presenter
        canPresentAuthenticationPrompt = canPresentPrompt
        updateState(.authenticating)
        logger.info("game_center.auth_started")

        installAuthenticationHandlerIfNeeded()
    }

    func retryAuthentication(presenter: GameCenterAuthenticationPresenting?) {
        shouldSuppressAutomaticPrompt = false
        hasInstalledAuthenticationHandler = false
        authenticate(presenter: presenter, allowsPrompt: true)
    }

    func presentClassicSurvivalLeaderboard(
        presenter: GameCenterLeaderboardPresenting
    ) -> GameCenterLeaderboardPresentationResult {
        guard localPlayer.isAvailable else {
            logger.info("game_center.leaderboard_unavailable", metadata: [
                "reason": "unsupported"
            ])
            return .unavailable(.unsupported)
        }

        guard localPlayer.isAuthenticated else {
            logger.info("game_center.leaderboard_unavailable", metadata: [
                "reason": "authenticationRequired"
            ])
            return .unavailable(.authenticationRequired)
        }

        guard let viewController = leaderboardFactory.makeClassicSurvivalLeaderboardViewController() else {
            logger.warning("game_center.leaderboard_unavailable", metadata: [
                "reason": "unsupported"
            ])
            return .unavailable(.unsupported)
        }

        presenter.presentGameCenterLeaderboard(viewController)
        logger.notice("game_center.leaderboard_presented", metadata: [
            "leaderboardID": "\(GameCenterIdentifiers.Leaderboard.classicSurvivalHighScore)"
        ])
        return .presented
    }

    func submitRunScore(_ summary: RunSummary) {
        guard summary.mode == .classic else {
            return
        }

        let submission = GameCenterScoreSubmission.classicSurvival(from: summary)
        guard localPlayer.isAvailable else {
            enqueueScoreSubmission(submission, reason: "unavailable")
            return
        }

        guard localPlayer.isAuthenticated else {
            enqueueScoreSubmission(submission, reason: "unauthenticated")
            return
        }

        submitScore(submission, queueRecoverableFailure: true)
    }

    func reportAchievementEvent(_ event: GameCenterAchievementEvent) {
        let progress = achievementProgressStore.reportableProgress(
            from: GameCenterAchievementProgressMapper.progress(for: event)
        )
        guard !progress.isEmpty else {
            return
        }

        guard localPlayer.isAvailable else {
            logger.info("game_center.achievement_unavailable", metadata: [
                "reason": "unsupported"
            ])
            return
        }

        guard localPlayer.isAuthenticated else {
            guard shouldQueueUnauthenticatedAchievements else {
                logger.info("game_center.achievement_unavailable", metadata: [
                    "reason": "authenticationFailed"
                ])
                return
            }

            enqueueAchievementProgress(progress, reason: "unauthenticated")
            return
        }

        submitAchievements(progress, queueRecoverableFailure: true)
    }

    func retryQueuedScores() {
        guard localPlayer.isAvailable, localPlayer.isAuthenticated else {
            return
        }

        guard !isRetryingQueuedScores else {
            logger.debug("game_center.score_retry_skipped_in_flight")
            return
        }

        let submissions = scoreSubmissionStore.pendingSubmissions
        guard !submissions.isEmpty else {
            return
        }

        isRetryingQueuedScores = true
        notifyMenuStatusChanged()
        logger.info("game_center.score_retry_started", metadata: [
            "pendingCount": "\(submissions.count)"
        ])
        retryQueuedScores(submissions, startingAt: 0, completedQueueKeys: [])
    }

    func retryQueuedAchievements() {
        guard localPlayer.isAvailable, localPlayer.isAuthenticated else {
            return
        }

        guard !isRetryingQueuedAchievements else {
            logger.debug("game_center.achievement_retry_skipped_in_flight")
            return
        }

        let progress = achievementProgressStore.pendingProgress
        guard !progress.isEmpty else {
            return
        }

        isRetryingQueuedAchievements = true
        notifyMenuStatusChanged()
        logger.info("game_center.achievement_retry_started", metadata: [
            "pendingCount": "\(progress.count)"
        ])
        localPlayer.reportAchievements(progress) { [weak self] error in
            guard let self else {
                return
            }

            defer {
                self.isRetryingQueuedAchievements = false
                self.notifyMenuStatusChanged()
            }

            if let error {
                if !self.shouldQueueRecoverableFailure(error) {
                    self.achievementProgressStore.removeProgress(withAchievementIDs: Set(progress.map(\.achievementID)))
                }
                self.logger.warning(
                    "game_center.achievement_retry_failed",
                    error: error,
                    metadata: self.achievementProgressMetadata(progress)
                )
                return
            }

            self.achievementProgressStore.markSubmitted(progress)
            self.logger.notice("game_center.achievement_retry_submitted", metadata: [
                "submittedCount": "\(progress.count)",
                "remainingCount": "\(self.achievementProgressStore.pendingProgress.count)"
            ])
        }
    }

    private func installAuthenticationHandlerIfNeeded() {
        guard !hasInstalledAuthenticationHandler else {
            return
        }

        hasInstalledAuthenticationHandler = true
        localPlayer.setAuthenticateHandler { [weak self] viewController, error in
            self?.handleAuthenticationCallback(
                viewController: viewController,
                error: error
            )
        }
    }

    private func handleAuthenticationCallback(
        viewController: UIViewController?,
        error: Error?
    ) {
        if let error {
            handleAuthenticationError(error)
            return
        }

        if let viewController {
            guard !shouldSuppressAutomaticPrompt else {
                logger.info("game_center.auth_prompt_suppressed")
                return
            }

            guard
                canPresentAuthenticationPrompt,
                let authenticationPresenter
            else {
                updateState(.needsUserAuthentication)
                logger.info("game_center.auth_prompt_deferred")
                return
            }

            updateState(.needsUserAuthentication)
            logger.info("game_center.auth_prompt_presented")
            authenticationPresenter.presentGameCenterAuthentication(viewController)
            return
        }

        if localPlayer.isAuthenticated {
            updateState(.authenticated)
            logger.notice("game_center.authenticated")
            retryQueuedSubmissions()
        } else {
            updateState(.needsUserAuthentication)
            logger.info("game_center.auth_incomplete")
        }
    }

    private func handleAuthenticationError(_ error: Error) {
        let failure = GameCenterAuthenticationFailure.make(from: error)
        let metadata: Logger.Metadata = [
            "reason": "\(failure.reason.rawValue)",
            "domain": "\(failure.domain)",
            "code": "\(failure.code)"
        ]

        switch failure.reason {
        case .cancelled, .denied:
            shouldSuppressAutomaticPrompt = true
            updateState(.declined(failure))
            logger.info("game_center.auth_declined", metadata: metadata)
        case .unavailable:
            updateState(.unsupported)
            logger.warning("game_center.auth_unavailable", error: error, metadata: metadata)
        case .failed:
            updateState(.failed(failure))
            logger.warning("game_center.auth_failed", error: error, metadata: metadata)
        }
    }

    private func updateState(_ state: GameCenterAuthenticationState) {
        let previousState = authenticationState
        authenticationState = state
        if state != previousState {
            notifyMenuStatusChanged()
        }
    }

    private func retryQueuedSubmissions() {
        retryQueuedScores()
        retryQueuedAchievements()
    }

    private func submitScore(
        _ submission: GameCenterScoreSubmission,
        queueRecoverableFailure: Bool
    ) {
        localPlayer.submitScore(
            submission.score,
            context: submission.context,
            leaderboardIDs: [submission.leaderboardID]
        ) { [weak self] error in
            guard let self else {
                return
            }

            if let error {
                self.handleScoreSubmissionFailure(
                    submission,
                    error: error,
                    queueRecoverableFailure: queueRecoverableFailure
                )
                return
            }

            self.logger.notice("game_center.score_submitted", metadata: [
                "leaderboardID": "\(submission.leaderboardID)",
                "score": "\(submission.score)"
            ])
        }
    }

    private func handleScoreSubmissionFailure(
        _ submission: GameCenterScoreSubmission,
        error: Error,
        queueRecoverableFailure: Bool
    ) {
        let nsError = error as NSError
        let metadata = scoreSubmissionMetadata(
            submission,
            additionalMetadata: [
                "domain": "\(nsError.domain)",
                "code": "\(nsError.code)"
            ]
        )

        guard queueRecoverableFailure, shouldQueueRecoverableFailure(error) else {
            logger.warning("game_center.score_submit_failed", error: error, metadata: metadata)
            return
        }

        enqueueScoreSubmission(submission, reason: "recoverableFailure")
        logger.warning("game_center.score_submit_queued_after_failure", error: error, metadata: metadata)
    }

    private func enqueueScoreSubmission(_ submission: GameCenterScoreSubmission, reason: String) {
        let didEnqueue = scoreSubmissionStore.enqueue(submission)
        logger.info("game_center.score_queued", metadata: scoreSubmissionMetadata(
            submission,
            additionalMetadata: [
                "reason": "\(reason)",
                "alreadyPending": "\(!didEnqueue)"
            ]
        ))
    }

    private var shouldQueueUnauthenticatedAchievements: Bool {
        switch authenticationState {
        case .unsupported, .declined, .failed:
            return false
        case .notStarted, .authenticating, .needsUserAuthentication, .authenticated:
            return true
        }
    }

    private func submitAchievements(
        _ progress: [GameCenterAchievementProgress],
        queueRecoverableFailure: Bool
    ) {
        achievementProgressStore.enqueue(progress)
        localPlayer.reportAchievements(progress) { [weak self] error in
            guard let self else {
                return
            }

            if let error {
                self.handleAchievementSubmissionFailure(
                    progress,
                    error: error,
                    queueRecoverableFailure: queueRecoverableFailure
                )
                return
            }

            self.achievementProgressStore.markSubmitted(progress)
            self.logger.notice("game_center.achievement_submitted", metadata: self.achievementProgressMetadata(progress))
        }
    }

    private func handleAchievementSubmissionFailure(
        _ progress: [GameCenterAchievementProgress],
        error: Error,
        queueRecoverableFailure: Bool
    ) {
        var metadata = achievementProgressMetadata(progress)
        let nsError = error as NSError
        metadata.merge([
            "domain": "\(nsError.domain)",
            "code": "\(nsError.code)"
        ]) { _, new in new }

        guard queueRecoverableFailure, shouldQueueRecoverableFailure(error) else {
            achievementProgressStore.removeProgress(withAchievementIDs: Set(progress.map(\.achievementID)))
            logger.warning("game_center.achievement_submit_failed", error: error, metadata: metadata)
            return
        }

        enqueueAchievementProgress(progress, reason: "recoverableFailure")
        logger.warning("game_center.achievement_queued_after_failure", error: error, metadata: metadata)
    }

    private func enqueueAchievementProgress(_ progress: [GameCenterAchievementProgress], reason: String) {
        let enqueuedProgress = achievementProgressStore.enqueue(progress)
        guard !enqueuedProgress.isEmpty else {
            logger.debug("game_center.achievement_queue_skipped", metadata: [
                "reason": "\(reason)",
                "alreadyPending": "true"
            ])
            return
        }

        logger.info("game_center.achievement_queued", metadata: [
            "reason": "\(reason)",
            "pendingCount": "\(achievementProgressStore.pendingProgress.count)",
            "updatedCount": "\(enqueuedProgress.count)"
        ])
    }

    private func retryQueuedScores(
        _ submissions: [GameCenterScoreSubmission],
        startingAt index: Int,
        completedQueueKeys: Set<String>
    ) {
        guard index < submissions.count else {
            scoreSubmissionStore.removeSubmissions(withQueueKeys: completedQueueKeys)
            isRetryingQueuedScores = false
            notifyMenuStatusChanged()
            logger.info("game_center.score_retry_finished", metadata: [
                "submittedCount": "\(completedQueueKeys.count)",
                "remainingCount": "\(scoreSubmissionStore.pendingSubmissions.count)"
            ])
            return
        }

        let submission = submissions[index]
        localPlayer.submitScore(
            submission.score,
            context: submission.context,
            leaderboardIDs: [submission.leaderboardID]
        ) { [weak self] error in
            guard let self else {
                return
            }

            var updatedCompletedQueueKeys = completedQueueKeys
            if let error {
                self.logger.warning(
                    "game_center.score_retry_failed",
                    error: error,
                    metadata: self.scoreSubmissionMetadata(submission)
                )
            } else {
                updatedCompletedQueueKeys.insert(submission.queueKey)
                self.logger.notice("game_center.score_retry_submitted", metadata: self.scoreSubmissionMetadata(submission))
            }

            self.retryQueuedScores(
                submissions,
                startingAt: index + 1,
                completedQueueKeys: updatedCompletedQueueKeys
            )
        }
    }

    private func shouldQueueRecoverableFailure(_ error: Error) -> Bool {
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

    private func achievementProgressMetadata(_ progress: [GameCenterAchievementProgress]) -> Logger.Metadata {
        [
            "achievementCount": "\(progress.count)",
            "maxPercentComplete": "\(progress.map(\.percentComplete).max() ?? 0)"
        ]
    }

    private func notifyMenuStatusChanged() {
        NotificationCenter.default.post(name: .gameCenterMenuStatusDidChange, object: self)
    }

    private func scoreSubmissionMetadata(
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

#if canImport(GameKit)
@MainActor
struct GameKitLeaderboardFactory: GameCenterLeaderboardFactory {
    func makeClassicSurvivalLeaderboardViewController() -> UIViewController? {
        GKGameCenterViewController(
            leaderboardID: GameCenterIdentifiers.Leaderboard.classicSurvivalHighScore,
            playerScope: .global,
            timeScope: .allTime
        )
    }
}

@MainActor
final class GameKitLocalPlayerClient: GameCenterLocalPlayerClient {
    var isAvailable: Bool {
        true
    }

    var isAuthenticated: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    func setAuthenticateHandler(
        _ handler: @escaping @MainActor (_ viewController: UIViewController?, _ error: Error?) -> Void
    ) {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            Task { @MainActor in
                handler(viewController, error)
            }
        }
    }

    func submitScore(
        _ score: Int,
        context: Int,
        leaderboardIDs: [String],
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        GKLeaderboard.submitScore(
            score,
            context: context,
            player: GKLocalPlayer.local,
            leaderboardIDs: leaderboardIDs
        ) { error in
            Task { @MainActor in
                completion(error)
            }
        }
    }

    func reportAchievements(
        _ progress: [GameCenterAchievementProgress],
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        let achievements = progress.map { item in
            let achievement = GKAchievement(identifier: item.achievementID)
            achievement.percentComplete = item.percentComplete
            achievement.showsCompletionBanner = item.percentComplete >= 100
            return achievement
        }

        GKAchievement.report(achievements) { error in
            Task { @MainActor in
                completion(error)
            }
        }
    }
}
#else
@MainActor
struct GameKitLeaderboardFactory: GameCenterLeaderboardFactory {
    func makeClassicSurvivalLeaderboardViewController() -> UIViewController? {
        nil
    }
}

@MainActor
final class GameKitLocalPlayerClient: GameCenterLocalPlayerClient {
    var isAvailable: Bool {
        false
    }

    var isAuthenticated: Bool {
        false
    }

    func setAuthenticateHandler(
        _ handler: @escaping @MainActor (_ viewController: UIViewController?, _ error: Error?) -> Void
    ) {}

    func submitScore(
        _ score: Int,
        context: Int,
        leaderboardIDs: [String],
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        completion(NSError(domain: "GameCenterUnavailable", code: 1))
    }

    func reportAchievements(
        _ progress: [GameCenterAchievementProgress],
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        completion(NSError(domain: "GameCenterUnavailable", code: 1))
    }
}
#endif
