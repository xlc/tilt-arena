import Foundation
import Logging
import UIKit

@MainActor
final class GameCenterService: GameCenterClient {
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
    private let authenticationTimeout: TimeInterval
    private let submissionTimeout: TimeInterval
    private var authenticationHandlerID: UUID?
    private let authenticationWatchdog = GameCenterOperationWatchdog()
    private let scoreRetryWatchdog = GameCenterOperationWatchdog()
    private let achievementRetryWatchdog = GameCenterOperationWatchdog()
    private var activeAchievementUnavailableReason: GameCenterAchievementUnavailableReason?

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
        logger: Logger = AppDiagnostics.logger(.gameCenter),
        authenticationTimeout: TimeInterval = 20,
        submissionTimeout: TimeInterval = 30
    ) {
        self.localPlayer = localPlayer
        self.scoreSubmissionStore = scoreSubmissionStore
        self.achievementProgressStore = achievementProgressStore
        self.leaderboardFactory = leaderboardFactory
        self.logger = logger
        self.authenticationTimeout = GameCenterFailurePolicy.normalizedTimeout(authenticationTimeout, fallback: 20)
        self.submissionTimeout = GameCenterFailurePolicy.normalizedTimeout(submissionTimeout, fallback: 30)
    }

    func authenticate(
        presenter: GameCenterAuthenticationPresenting?,
        allowsPrompt: Bool = true
    ) {
        guard localPlayer.isAvailable else {
            authenticationWatchdog.cancel()
            updateState(.unsupported)
            logger.info("game_center.auth_unsupported")
            return
        }

        if localPlayer.isAuthenticated {
            authenticationWatchdog.cancel()
            updateState(.authenticated)
            logger.notice("game_center.authenticated")
            retryQueuedSubmissions()
            return
        }

        let canPresentPrompt = allowsPrompt && !shouldSuppressAutomaticPrompt
        authenticationPresenter = presenter
        canPresentAuthenticationPrompt = canPresentPrompt

        // GameKit keeps the authentication handler installed and can invoke it
        // again as account state changes. A passive view appearance must not
        // replace a useful terminal state (for example, declined) with a
        // synthetic in-flight state when there is no new authentication attempt.
        guard !hasInstalledAuthenticationHandler else {
            return
        }

        updateState(.authenticating)
        logger.info("game_center.auth_started")

        let attemptID = authenticationWatchdog.begin()
        authenticationHandlerID = attemptID
        hasInstalledAuthenticationHandler = true
        localPlayer.setAuthenticateHandler { [weak self] viewController, error in
            self?.handleAuthenticationCallback(
                handlerID: attemptID,
                viewController: viewController,
                error: error
            )
        }
        authenticationWatchdog.arm(requestID: attemptID, after: authenticationTimeout) { [weak self] in
            self?.handleAuthenticationTimeout(attemptID: attemptID)
        }
    }

    func retryAuthentication(presenter: GameCenterAuthenticationPresenting?) {
        authenticationWatchdog.cancel()
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

        submitScore(submission)
    }

    func reportAchievementEvent(_ event: GameCenterAchievementEvent) {
        let mappedProgress = GameCenterAchievementProgressMapper.progress(for: event)
        guard !mappedProgress.isEmpty else {
            return
        }

        if let unavailableReason = achievementUnavailableReason {
            reportAchievementUnavailableIfNeeded(unavailableReason)
            return
        }
        reportAchievementAvailabilityRecoveryIfNeeded()

        let progress = achievementProgressStore.reportableProgress(from: mappedProgress)
        guard !progress.isEmpty else {
            return
        }

        guard localPlayer.isAuthenticated else {
            enqueueAchievementProgress(progress, reason: "unauthenticated")
            return
        }

        submitAchievements(progress)
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
        let requestID = achievementRetryWatchdog.begin()
        localPlayer.reportAchievements(progress) { [weak self] error in
            guard let self else {
                return
            }
            guard self.achievementRetryWatchdog.complete(requestID) else {
                self.logger.debug("game_center.achievement_retry_late_completion_ignored")
                return
            }

            defer {
                self.isRetryingQueuedAchievements = false
                self.notifyMenuStatusChanged()
            }

            if let error {
                if !GameCenterFailurePolicy.shouldQueue(error) {
                    self.achievementProgressStore.removeProgress(withAchievementIDs: Set(progress.map(\.achievementID)))
                }
                self.logger.warning(
                    "game_center.achievement_retry_failed",
                    error: error,
                    metadata: GameCenterLogMetadata.achievementProgress(progress)
                )
                return
            }

            self.achievementProgressStore.markSubmitted(progress)
            self.logger.notice("game_center.achievement_retry_submitted", metadata: [
                "submittedCount": "\(progress.count)",
                "remainingCount": "\(self.achievementProgressStore.pendingProgress.count)"
            ])
        }
        achievementRetryWatchdog.arm(requestID: requestID, after: submissionTimeout) { [weak self] in
            self?.handleAchievementRetryTimeout(requestID: requestID, progress: progress)
        }
    }

    private func handleAuthenticationCallback(
        handlerID: UUID,
        viewController: UIViewController?,
        error: Error?
    ) {
        guard authenticationHandlerID == handlerID else {
            logger.debug("game_center.auth_stale_callback_ignored")
            return
        }

        authenticationWatchdog.cancel()

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

    private func submitScore(_ submission: GameCenterScoreSubmission) {
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
                    error: error
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
        error: Error
    ) {
        let nsError = error as NSError
        let metadata = GameCenterLogMetadata.scoreSubmission(
            submission,
            additionalMetadata: [
                "domain": "\(nsError.domain)",
                "code": "\(nsError.code)"
            ]
        )

        guard GameCenterFailurePolicy.shouldQueue(error) else {
            logger.warning("game_center.score_submit_failed", error: error, metadata: metadata)
            return
        }

        enqueueScoreSubmission(submission, reason: "recoverableFailure")
        logger.warning("game_center.score_submit_queued_after_failure", error: error, metadata: metadata)
    }

    private func enqueueScoreSubmission(_ submission: GameCenterScoreSubmission, reason: String) {
        let didEnqueue = scoreSubmissionStore.enqueue(submission)
        logger.info("game_center.score_queued", metadata: GameCenterLogMetadata.scoreSubmission(
            submission,
            additionalMetadata: [
                "reason": "\(reason)",
                "alreadyPending": "\(!didEnqueue)"
            ]
        ))
    }

    private func submitAchievements(_ progress: [GameCenterAchievementProgress]) {
        achievementProgressStore.enqueue(progress)
        localPlayer.reportAchievements(progress) { [weak self] error in
            guard let self else {
                return
            }

            if let error {
                self.handleAchievementSubmissionFailure(
                    progress,
                    error: error
                )
                return
            }

            self.achievementProgressStore.markSubmitted(progress)
            self.logger.notice("game_center.achievement_submitted", metadata: GameCenterLogMetadata.achievementProgress(progress))
        }
    }

    private func handleAchievementSubmissionFailure(
        _ progress: [GameCenterAchievementProgress],
        error: Error
    ) {
        var metadata = GameCenterLogMetadata.achievementProgress(progress)
        let nsError = error as NSError
        metadata.merge([
            "domain": "\(nsError.domain)",
            "code": "\(nsError.code)"
        ]) { _, new in new }

        guard GameCenterFailurePolicy.shouldQueue(error) else {
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
        let requestID = scoreRetryWatchdog.begin()
        localPlayer.submitScore(
            submission.score,
            context: submission.context,
            leaderboardIDs: [submission.leaderboardID]
        ) { [weak self] error in
            guard let self else {
                return
            }
            guard self.scoreRetryWatchdog.complete(requestID) else {
                self.logger.debug("game_center.score_retry_late_completion_ignored")
                return
            }

            var updatedCompletedQueueKeys = completedQueueKeys
            if let error {
                if !GameCenterFailurePolicy.shouldQueue(error) {
                    self.scoreSubmissionStore.removeSubmissions(
                        withQueueKeys: [submission.queueKey]
                    )
                }
                self.logger.warning(
                    "game_center.score_retry_failed",
                    error: error,
                    metadata: GameCenterLogMetadata.scoreSubmission(submission)
                )
            } else {
                updatedCompletedQueueKeys.insert(submission.queueKey)
                self.logger.notice("game_center.score_retry_submitted", metadata: GameCenterLogMetadata.scoreSubmission(submission))
            }

            self.retryQueuedScores(
                submissions,
                startingAt: index + 1,
                completedQueueKeys: updatedCompletedQueueKeys
            )
        }
        scoreRetryWatchdog.arm(requestID: requestID, after: submissionTimeout) { [weak self] in
            self?.handleScoreRetryTimeout(requestID: requestID, submission: submission)
        }
    }

    private func notifyMenuStatusChanged() {
        NotificationCenter.default.post(name: .gameCenterMenuStatusDidChange, object: self)
    }
}

private extension GameCenterService {
    func handleAuthenticationTimeout(attemptID: UUID) {
        guard authenticationWatchdog.isCurrent(attemptID), authenticationState == .authenticating else {
            return
        }

        authenticationWatchdog.cancel()
        updateState(.needsUserAuthentication)
        logger.warning("game_center.auth_timed_out")
    }

    func handleScoreRetryTimeout(
        requestID: UUID,
        submission: GameCenterScoreSubmission
    ) {
        guard scoreRetryWatchdog.isCurrent(requestID), isRetryingQueuedScores else {
            return
        }

        scoreRetryWatchdog.cancel()
        isRetryingQueuedScores = false
        notifyMenuStatusChanged()
        logger.warning(
            "game_center.score_retry_timed_out",
            metadata: GameCenterLogMetadata.scoreSubmission(submission)
        )
    }

    func handleAchievementRetryTimeout(
        requestID: UUID,
        progress: [GameCenterAchievementProgress]
    ) {
        guard achievementRetryWatchdog.isCurrent(requestID), isRetryingQueuedAchievements else {
            return
        }

        achievementRetryWatchdog.cancel()
        isRetryingQueuedAchievements = false
        notifyMenuStatusChanged()
        logger.warning(
            "game_center.achievement_retry_timed_out",
            metadata: GameCenterLogMetadata.achievementProgress(progress)
        )
    }
}

private extension GameCenterService {
    var achievementUnavailableReason: GameCenterAchievementUnavailableReason? {
        guard localPlayer.isAvailable else {
            return .unsupported
        }
        guard !localPlayer.isAuthenticated else {
            return nil
        }

        switch authenticationState {
        case .unsupported:
            return .unsupported
        case .declined:
            return .authenticationDeclined
        case .failed:
            return .authenticationFailed
        case .notStarted, .authenticating, .needsUserAuthentication, .authenticated:
            return nil
        }
    }

    func reportAchievementUnavailableIfNeeded(_ reason: GameCenterAchievementUnavailableReason) {
        guard activeAchievementUnavailableReason != reason else {
            return
        }

        activeAchievementUnavailableReason = reason
        logger.info("game_center.achievement_unavailable", metadata: [
            "reason": "\(reason.rawValue)"
        ])
    }

    func reportAchievementAvailabilityRecoveryIfNeeded() {
        guard let previousReason = activeAchievementUnavailableReason else {
            return
        }

        activeAchievementUnavailableReason = nil
        logger.info("game_center.achievement_available", metadata: [
            "previousReason": "\(previousReason.rawValue)"
        ])
    }
}
