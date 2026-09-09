// swiftlint:disable file_length
import GameKit
import Logging
import UIKit
import XCTest
@testable import TiltArena

final class GameCenterServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var scoreSubmissionStore: GameCenterScoreSubmissionStore!
    private var achievementProgressStore: GameCenterAchievementProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "GameCenterServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        scoreSubmissionStore = GameCenterScoreSubmissionStore(defaults: defaults)
        achievementProgressStore = GameCenterAchievementProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        scoreSubmissionStore = nil
        achievementProgressStore = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }
}

@MainActor extension GameCenterServiceTests {
    func testPreviousRulesQueuesAndAchievementCacheAreNotReused() throws {
        let score = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 100_000))
        let progress = GameCenterAchievementProgress(achievement: .score100000, percentComplete: 100)
        for suffix in ["", ".v\(ArenaRunContext.currentRulesVersion - 1)"] {
            defaults.set(try JSONEncoder().encode([score]), forKey: "tiltArena.gameCenter.pendingScores\(suffix)")
            defaults.set(try JSONEncoder().encode([progress]), forKey: "tiltArena.gameCenter.pendingAchievements\(suffix)")
            defaults.set(try JSONEncoder().encode([progress.achievementID: 100.0]),
                         forKey: "tiltArena.gameCenter.reportedAchievementProgress\(suffix)")
        }
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)
        service.retryQueuedScores()
        service.retryQueuedAchievements()
        XCTAssertTrue(client.submittedScores.isEmpty)
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
        XCTAssertEqual(achievementProgressStore.reportableProgress(from: [progress]), [progress])
    }

    func testPreviousRulesSummaryIsNotSubmittedOrReported() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(score: 100_000, rulesVersion: ArenaRunContext.currentRulesVersion - 1)
        service.submitRunScore(summary)
        XCTAssertTrue(client.submittedScores.isEmpty)
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
        XCTAssertTrue(GameCenterAchievementProgressMapper.progress(for: .runFinished(summary)).isEmpty)
    }

    func testAuthenticatedScoreIsDurableUntilItsRequestCompletes() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.defersScoreSubmissions = true
        let service = makeService(localPlayer: client)
        service.submitRunScore(makeRunSummary(score: 800))
        XCTAssertEqual(GameCenterScoreSubmissionStore(defaults: defaults).pendingSubmissions.map(\.score), [800])
        client.completeNextScoreSubmission()
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testOlderAchievementFailurePreservesNewerQueuedProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.defersAchievementReports = true
        let service = makeService(localPlayer: client)
        service.reportAchievementEvent(.runFinished(makeRunSummary(score: 10_000)))
        service.reportAchievementEvent(.runFinished(makeRunSummary(score: 20_000)))
        client.completeNextAchievementReport(error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError))
        XCTAssertEqual(achievementProgressStore.pendingProgress.first {
            $0.achievementID == GameCenterIdentifiers.Achievement.score100000.rawValue
        }?.percentComplete, 20)
    }

    func testOlderAchievementRetryFailurePreservesNewerQueuedProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)
        service.reportAchievementEvent(.runFinished(makeRunSummary(score: 10_000)))
        client.isAuthenticated = true
        client.defersAchievementReports = true
        service.retryQueuedAchievements()
        service.reportAchievementEvent(.runFinished(makeRunSummary(score: 20_000)))
        client.completeNextAchievementReport(error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError))
        XCTAssertEqual(achievementProgressStore.pendingProgress.first {
            $0.achievementID == GameCenterIdentifiers.Achievement.score100000.rawValue
        }?.percentComplete, 20)
    }

    func testUnsupportedClientDoesNotInstallAuthenticationHandler() {
        let client = FakeGameCenterLocalPlayerClient(isAvailable: false)
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)

        XCTAssertEqual(service.authenticationState, .unsupported)
        XCTAssertFalse(client.didInstallAuthenticateHandler)
    }

    func testAlreadyAuthenticatedClientBecomesAuthenticatedWithoutInstallingHandler() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)

        XCTAssertEqual(service.authenticationState, .authenticated)
        XCTAssertFalse(client.didInstallAuthenticateHandler)
    }

    func testAuthenticationCompletionBecomesAuthenticated() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)
        client.isAuthenticated = true
        client.completeAuthentication(viewController: nil, error: nil)

        XCTAssertEqual(service.authenticationState, .authenticated)
    }

    func testAuthenticationTimeoutLeavesMenuRetryableAndAcceptsLateAccountUpdate() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client, authenticationTimeout: 0)

        service.authenticate(presenter: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertEqual(service.menuStatus, .signInRequired)

        client.isAuthenticated = true
        client.completeAuthentication(viewController: nil, error: nil)

        XCTAssertEqual(service.authenticationState, .authenticated)
        XCTAssertEqual(service.menuStatus, .ready)
    }

    func testPromptIsPresentedWhenAllowed() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = makeService(localPlayer: client)
        let viewController = UIViewController()

        service.authenticate(presenter: presenter)
        client.completeAuthentication(viewController: viewController, error: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertTrue(presenter.presentedViewController === viewController)
    }

    func testPromptIsDeferredWhenAutomaticPromptIsNotAllowedAndExplicitRetryCanPresent() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = makeService(localPlayer: client)
        let explicitPrompt = UIViewController()

        service.authenticate(presenter: nil, allowsPrompt: false)
        client.completeAuthentication(viewController: UIViewController(), error: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertNil(presenter.presentedViewController)

        service.retryAuthentication(presenter: presenter)
        client.completeAuthentication(viewController: explicitPrompt, error: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertEqual(client.authenticateHandlerInstallCount, 2)
        XCTAssertTrue(presenter.presentedViewController === explicitPrompt)
    }

    func testCancelledAuthenticationSuppressesLaterAutomaticPrompt() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: presenter)
        client.completeAuthentication(
            viewController: nil,
            error: NSError(domain: GKErrorDomain, code: GKError.Code.cancelled.rawValue)
        )
        client.completeAuthentication(viewController: UIViewController(), error: nil)

        XCTAssertEqual(
            service.authenticationState,
            .declined(GameCenterAuthenticationFailure(reason: .cancelled, domain: GKErrorDomain, code: GKError.Code.cancelled.rawValue))
        )
        XCTAssertNil(presenter.presentedViewController)
    }

    func testPassiveAuthenticationAfterDeclinePreservesDeclinedState() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client)
        let error = NSError(domain: GKErrorDomain, code: GKError.Code.cancelled.rawValue)

        service.authenticate(presenter: nil, allowsPrompt: false)
        client.completeAuthentication(viewController: nil, error: error)
        service.authenticate(presenter: nil, allowsPrompt: false)

        XCTAssertEqual(
            service.authenticationState,
            .declined(GameCenterAuthenticationFailure(
                reason: .cancelled,
                domain: GKErrorDomain,
                code: GKError.Code.cancelled.rawValue
            ))
        )
        XCTAssertEqual(client.authenticateHandlerInstallCount, 1)
    }

    func testDeniedAuthenticationSuppressesLaterAutomaticPrompt() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)
        client.completeAuthentication(
            viewController: nil,
            error: NSError(domain: GKErrorDomain, code: GKError.Code.userDenied.rawValue)
        )

        XCTAssertEqual(
            service.authenticationState,
            .declined(GameCenterAuthenticationFailure(reason: .denied, domain: GKErrorDomain, code: GKError.Code.userDenied.rawValue))
        )
    }

    func testRetryAfterDeclineAllowsPromptAgain() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = makeService(localPlayer: client)
        let viewController = UIViewController()

        service.authenticate(presenter: presenter)
        client.completeAuthentication(
            viewController: nil,
            error: NSError(domain: GKErrorDomain, code: GKError.Code.cancelled.rawValue)
        )

        service.retryAuthentication(presenter: presenter)
        client.completeAuthentication(viewController: viewController, error: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertEqual(client.authenticateHandlerInstallCount, 2)
        XCTAssertTrue(presenter.presentedViewController === viewController)
    }

    func testStaleAuthenticationHandlerCannotOverwriteNewRetryAttempt() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)
        service.retryAuthentication(presenter: nil)

        client.completeAuthentication(
            usingHandlerAt: 0,
            viewController: nil,
            error: NSError(domain: GKErrorDomain, code: GKError.Code.cancelled.rawValue)
        )

        XCTAssertEqual(service.authenticationState, .authenticating)

        client.isAuthenticated = true
        client.completeAuthentication(usingHandlerAt: 1, viewController: nil, error: nil)

        XCTAssertEqual(service.authenticationState, .authenticated)
    }

    func testFailedAuthenticationRecordsFailure() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)
        client.completeAuthentication(
            viewController: nil,
            error: NSError(domain: NSCocoaErrorDomain, code: 4099)
        )

        XCTAssertEqual(
            service.authenticationState,
            .failed(GameCenterAuthenticationFailure(reason: .failed, domain: NSCocoaErrorDomain, code: 4099))
        )
    }

    func testAuthenticatedRunSubmitsClassicScore() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(score: 1_200)

        service.submitRunScore(summary)

        XCTAssertEqual(
            client.submittedScores,
            [
                SubmittedGameCenterScore(
                    score: 1_200,
                    context: 0,
                    leaderboardIDs: [GameCenterIdentifiers.Leaderboard.classicSurvivalHighScore]
                )
            ]
        )
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testUnauthenticatedRunQueuesClassicScore() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(score: 900)

        service.submitRunScore(summary)

        XCTAssertTrue(client.submittedScores.isEmpty)
        XCTAssertEqual(scoreSubmissionStore.pendingSubmissions.map(\.score), [900])
        XCTAssertEqual(
            scoreSubmissionStore.pendingSubmissions.map(\.leaderboardID),
            [GameCenterIdentifiers.Leaderboard.classicSurvivalHighScore]
        )
    }

    func testRecoverableScoreSubmissionFailureQueuesClassicScore() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.submitScoreError = NSError(domain: GKErrorDomain, code: GKError.Code.communicationsFailure.rawValue)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(score: 700)

        service.submitRunScore(summary)

        XCTAssertEqual(client.submittedScores.count, 1)
        XCTAssertEqual(scoreSubmissionStore.pendingSubmissions.map(\.score), [700])
    }

    func testRetryQueuedScoresRemovesSuccessfulSubmission() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)
        let submission = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 500))
        scoreSubmissionStore.enqueue(submission)

        service.retryQueuedScores()

        XCTAssertEqual(client.submittedScores.map(\.score), [500])
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testRetryQueuedScoresDiscardsNonrecoverableFailure() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.submitScoreError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        let service = makeService(localPlayer: client)
        let submission = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 500))
        scoreSubmissionStore.enqueue(submission)

        service.retryQueuedScores()

        XCTAssertEqual(client.submittedScores.map(\.score), [500])
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testRetryQueuedScoresRetainsRecoverableFailure() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.submitScoreError = NSError(
            domain: GKErrorDomain,
            code: GKError.Code.communicationsFailure.rawValue
        )
        let service = makeService(localPlayer: client)
        let submission = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 500))
        scoreSubmissionStore.enqueue(submission)

        service.retryQueuedScores()

        XCTAssertEqual(client.submittedScores.map(\.score), [500])
        XCTAssertEqual(scoreSubmissionStore.pendingSubmissions.map(\.score), [500])
    }

    func testAuthenticationSuccessRetriesQueuedScores() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = makeService(localPlayer: client)
        let submission = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 600))
        scoreSubmissionStore.enqueue(submission)

        service.authenticate(presenter: nil)
        client.isAuthenticated = true
        client.completeAuthentication(viewController: nil, error: nil)

        XCTAssertEqual(client.submittedScores.map(\.score), [600])
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testDuplicateRunScoreIsQueuedOnce() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(score: 400)

        service.submitRunScore(summary)
        service.submitRunScore(summary)

        XCTAssertEqual(scoreSubmissionStore.pendingSubmissions.map(\.score), [400])
    }

    func testRetryQueuedScoresIgnoresDuplicateInFlightRetry() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.defersScoreSubmissions = true
        let service = makeService(localPlayer: client)
        let submission = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 800))
        scoreSubmissionStore.enqueue(submission)

        service.retryQueuedScores()
        service.retryQueuedScores()

        XCTAssertEqual(client.submittedScores.map(\.score), [800])
        XCTAssertFalse(scoreSubmissionStore.pendingSubmissions.isEmpty)

        client.completeNextScoreSubmission()

        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testRetryQueuedScoresTimeoutReleasesInFlightGateAndRetainsSubmission() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.defersScoreSubmissions = true
        let service = makeService(localPlayer: client, submissionTimeout: 0)
        let submission = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 850))
        scoreSubmissionStore.enqueue(submission)

        service.retryQueuedScores()

        XCTAssertEqual(service.menuStatus, .ready)
        XCTAssertEqual(scoreSubmissionStore.pendingSubmissions.map(\.score), [850])

        service.retryQueuedScores()

        XCTAssertEqual(client.submittedScores.map(\.score), [850, 850])
        client.completeNextScoreSubmission()
        XCTAssertEqual(scoreSubmissionStore.pendingSubmissions.map(\.score), [850])
    }

    func testNonClassicRunScoreIsNotSubmittedOrQueued() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(score: 300, mode: .daily)

        service.submitRunScore(summary)

        XCTAssertTrue(client.submittedScores.isEmpty)
        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)
    }

    func testPendingScoreStorePersistsBoundsAndDeduplicates() {
        let boundedStore = GameCenterScoreSubmissionStore(defaults: defaults, maxPendingSubmissions: 2)
        let first = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 100, timestamp: 1))
        let second = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 200, timestamp: 2))
        let third = GameCenterScoreSubmission.classicSurvival(from: makeRunSummary(score: 300, timestamp: 3))

        XCTAssertTrue(boundedStore.enqueue(first))
        XCTAssertFalse(boundedStore.enqueue(first))
        XCTAssertTrue(boundedStore.enqueue(second))
        XCTAssertTrue(boundedStore.enqueue(third))

        let reloadedStore = GameCenterScoreSubmissionStore(defaults: defaults, maxPendingSubmissions: 2)
        XCTAssertEqual(reloadedStore.pendingSubmissions.map(\.score), [200, 300])
    }

    func testPendingScoreStoreRepairsMalformedPersistedSubmissions() throws {
        let pendingKey = "tiltArena.gameCenter.pendingScores.v\(ArenaRunContext.currentRulesVersion)"
        let submission = GameCenterScoreSubmission.classicSurvival(
            from: makeRunSummary(score: 100, timestamp: 1)
        )
        let encoded = try JSONEncoder().encode([submission])
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [[String: Any]]
        )
        payload[0]["runKey"] = "  \(submission.runKey)  "
        payload[0]["leaderboardID"] = "  \(submission.leaderboardID)  "
        payload[0]["score"] = -100
        var invalidSubmission = payload[0]
        invalidSubmission["runKey"] = "   "
        payload.append(invalidSubmission)
        defaults.set(
            try JSONSerialization.data(withJSONObject: payload),
            forKey: pendingKey
        )

        let reloaded = GameCenterScoreSubmissionStore(defaults: defaults).pendingSubmissions

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].runKey, submission.runKey)
        XCTAssertEqual(reloaded[0].leaderboardID, submission.leaderboardID)
        XCTAssertEqual(reloaded[0].score, 0)
    }

    func testAuthenticatedLeaderboardPresentationPresentsClassicLeaderboard() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let viewController = UIViewController()
        let presenter = FakeGameCenterLeaderboardPresenter()
        let service = makeService(
            localPlayer: client,
            leaderboardFactory: FakeLeaderboardFactory(
                viewController: viewController
            )
        )

        let result = service.presentClassicSurvivalLeaderboard(presenter: presenter)

        XCTAssertEqual(result, .presented)
        XCTAssertTrue(presenter.presentedViewController === viewController)
    }

    func testUnauthenticatedLeaderboardPresentationRequestsAuthentication() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let presenter = FakeGameCenterLeaderboardPresenter()
        let service = makeService(localPlayer: client)

        let result = service.presentClassicSurvivalLeaderboard(presenter: presenter)

        XCTAssertEqual(result, .unavailable(.authenticationRequired))
        XCTAssertNil(presenter.presentedViewController)
    }

    func testUnsupportedLeaderboardPresentationDoesNotPresent() {
        let client = FakeGameCenterLocalPlayerClient(isAvailable: false)
        let presenter = FakeGameCenterLeaderboardPresenter()
        let service = makeService(localPlayer: client)

        let result = service.presentClassicSurvivalLeaderboard(presenter: presenter)

        XCTAssertEqual(result, .unavailable(.unsupported))
        XCTAssertNil(presenter.presentedViewController)
    }

    func testMenuStatusReflectsAuthenticationState() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)

        XCTAssertEqual(service.menuStatus, .signInRequired)
        service.authenticate(presenter: nil)
        XCTAssertEqual(service.menuStatus, .syncing)
        client.completeAuthentication(viewController: UIViewController(), error: nil)
        XCTAssertEqual(service.menuStatus, .signInRequired)
        client.isAuthenticated = true
        client.completeAuthentication(viewController: nil, error: nil)
        XCTAssertEqual(service.menuStatus, .ready)
    }

    func testMenuStatusReportsUnavailableWhenGameCenterIsUnsupported() {
        let client = FakeGameCenterLocalPlayerClient(isAvailable: false)
        let service = makeService(localPlayer: client)

        XCTAssertEqual(service.menuStatus, .unavailable)
    }

    func testDuplicateAchievementProgressIsNotResubmittedAfterSuccess() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.weaponOrbCollected)
        service.reportAchievementEvent(.weaponOrbCollected)
        XCTAssertEqual(client.submittedAchievementBatches.count, 1)
        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
    }

    func testDuplicateAchievementProgressIsNotResubmittedWhileInFlight() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.defersAchievementReports = true
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.weaponOrbCollected)
        service.reportAchievementEvent(.weaponOrbCollected)
        XCTAssertEqual(client.submittedAchievementBatches.count, 1)
        XCTAssertEqual(achievementProgressStore.pendingProgress.count, 1)
        client.completeNextAchievementReport()
        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
    }

    func testUnauthenticatedAchievementProgressIsQueuedOnceAndDoesNotRegress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.runFinished(makeRunSummary(score: 50_000, maxCombo: 25)))
        service.reportAchievementEvent(.runFinished(makeRunSummary(score: 10_000, maxCombo: 10)))

        let progress = achievementProgressStore.pendingProgress.progressByAchievementID
        XCTAssertTrue(client.submittedAchievementBatches.isEmpty)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.score100000.rawValue], 50)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo50.rawValue], 50)
    }

    func testRetryQueuedAchievementsRemovesSuccessfulProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.weaponOrbCollected)
        client.isAuthenticated = true
        service.retryQueuedAchievements()

        XCTAssertEqual(client.submittedAchievementBatches.count, 1)
        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
    }

    func testRetryQueuedAchievementsTimeoutReleasesInFlightGateAndRetainsProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client, submissionTimeout: 0)
        service.reportAchievementEvent(.weaponOrbCollected)
        client.isAuthenticated = true
        client.defersAchievementReports = true

        service.retryQueuedAchievements()

        XCTAssertEqual(service.menuStatus, .ready)
        XCTAssertEqual(achievementProgressStore.pendingProgress.count, 1)

        service.retryQueuedAchievements()

        XCTAssertEqual(client.submittedAchievementBatches.count, 2)
        client.completeNextAchievementReport()
        XCTAssertEqual(achievementProgressStore.pendingProgress.count, 1)
    }

    func testRecoverableAchievementSubmissionFailureQueuesProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        client.reportAchievementsError = NSError(domain: GKErrorDomain, code: GKError.Code.communicationsFailure.rawValue)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.weaponOrbCollected)

        XCTAssertEqual(client.submittedAchievementBatches.count, 1)
        XCTAssertEqual(
            achievementProgressStore.pendingProgress.map(\.achievementID),
            [GameCenterIdentifiers.Achievement.firstWeaponOrb.rawValue]
        )
    }

    func testUnsupportedAchievementProgressDoesNotQueue() {
        let client = FakeGameCenterLocalPlayerClient(isAvailable: false)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.weaponOrbCollected)

        XCTAssertTrue(client.submittedAchievementBatches.isEmpty)
        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
    }

    func testFailedAuthenticationDoesNotQueueAchievementProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client)

        service.authenticate(presenter: nil)
        client.completeAuthentication(viewController: nil, error: NSError(domain: NSCocoaErrorDomain, code: 4099))
        service.reportAchievementEvent(.weaponOrbCollected)

        XCTAssertTrue(client.submittedAchievementBatches.isEmpty)
        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
    }

    func testTerminalAuthenticationFailureLogsAchievementUnavailabilityOncePerEpisode() {
        let logRecorder = GameCenterLogRecorder()
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: false)
        let service = makeService(localPlayer: client, logger: logRecorder.logger)
        service.authenticate(presenter: nil)
        client.completeAuthentication(
            viewController: nil,
            error: NSError(domain: NSCocoaErrorDomain, code: 4_099)
        )

        for _ in 0..<3 {
            service.reportAchievementEvent(.enemyClear(
                count: 1,
                weaponKind: .shockwave,
                maxCombo: 1
            ))
        }

        XCTAssertEqual(logRecorder.count(of: "game_center.achievement_unavailable"), 1)

        client.isAuthenticated = true
        service.reportAchievementEvent(.weaponOrbCollected)
        XCTAssertEqual(logRecorder.count(of: "game_center.achievement_available"), 1)

        client.isAuthenticated = false
        service.reportAchievementEvent(.enemyClear(
            count: 1,
            weaponKind: .shockwave,
            maxCombo: 1
        ))
        XCTAssertEqual(logRecorder.count(of: "game_center.achievement_unavailable"), 2)
    }

    func testCorruptedAchievementProgressBlobsAreDiscardedAfterFirstFailedRead() {
        let pendingKey = "tiltArena.gameCenter.pendingAchievements.v\(ArenaRunContext.currentRulesVersion)"
        let reportedKey = "tiltArena.gameCenter.reportedAchievementProgress.v\(ArenaRunContext.currentRulesVersion)"
        defaults.set(Data("not-json".utf8), forKey: pendingKey)
        defaults.set(Data("also-not-json".utf8), forKey: reportedKey)

        _ = achievementProgressStore.reportableProgress(
            from: GameCenterAchievementProgressMapper.progress(for: .weaponOrbCollected)
        )

        XCTAssertNil(defaults.data(forKey: pendingKey))
        XCTAssertNil(defaults.data(forKey: reportedKey))
    }

    func testPendingAchievementStoreRepairsMalformedPersistedProgress() throws {
        let pendingKey = "tiltArena.gameCenter.pendingAchievements.v\(ArenaRunContext.currentRulesVersion)"
        let progress = try XCTUnwrap(
            GameCenterAchievementProgressMapper.progress(for: .weaponOrbCollected).first
        )
        let encoded = try JSONEncoder().encode([progress])
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [[String: Any]]
        )
        payload[0]["achievementID"] = "  \(progress.achievementID)  "
        payload[0]["percentComplete"] = 150
        var invalidProgress = payload[0]
        invalidProgress["achievementID"] = "   "
        payload.append(invalidProgress)
        defaults.set(
            try JSONSerialization.data(withJSONObject: payload),
            forKey: pendingKey
        )

        let reloaded = achievementProgressStore.pendingProgress

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].achievementID, progress.achievementID)
        XCTAssertEqual(reloaded[0].percentComplete, 100)
    }

    func testAchievementProgressRejectsNonfinitePercentages() {
        achievementProgressStore.pendingProgress = [
            GameCenterAchievementProgress(
                achievement: .firstWeaponOrb,
                percentComplete: .infinity
            )
        ]

        XCTAssertTrue(achievementProgressStore.pendingProgress.isEmpty)
    }

    func testCorruptedScoreQueueBlobIsDiscardedAfterFirstFailedRead() {
        let pendingKey = "tiltArena.gameCenter.pendingScores.v\(ArenaRunContext.currentRulesVersion)"
        defaults.set(Data("not-json".utf8), forKey: pendingKey)

        XCTAssertTrue(scoreSubmissionStore.pendingSubmissions.isEmpty)

        XCTAssertNil(defaults.data(forKey: pendingKey))
    }

    private func makeService(
        localPlayer: FakeGameCenterLocalPlayerClient,
        leaderboardFactory: GameCenterLeaderboardFactory = FakeLeaderboardFactory(),
        authenticationTimeout: TimeInterval = 20,
        submissionTimeout: TimeInterval = 30,
        logger: Logger = AppDiagnostics.logger(.gameCenter)
    ) -> GameCenterService {
        GameCenterService(
            localPlayer: localPlayer,
            scoreSubmissionStore: scoreSubmissionStore,
            achievementProgressStore: achievementProgressStore,
            leaderboardFactory: leaderboardFactory,
            logger: logger,
            authenticationTimeout: authenticationTimeout,
            submissionTimeout: submissionTimeout
        )
    }

    private func makeRunSummary(
        score: Int,
        survivalTime: TimeInterval = 12,
        maxCombo: Int = 3,
        enemiesDestroyed: Int = 4,
        timestamp: TimeInterval = 1,
        mode: ArenaModeKind = .classic,
        rulesVersion: Int = ArenaRunContext.currentRulesVersion
    ) -> RunSummary {
        RunSummary(
            score: score,
            survivalTime: survivalTime,
            maxCombo: maxCombo,
            enemiesDestroyed: enemiesDestroyed,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: timestamp),
            mode: mode,
            rulesVersion: rulesVersion
        )
    }
}

private final class GameCenterLogRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    var logger: Logger {
        Logger(label: "GameCenterServiceTests") { _ in
            GameCenterRecordingLogHandler(recorder: self)
        }
    }

    func record(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
    }

    func count(of message: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return messages.count { $0 == message }
    }
}

private struct GameCenterRecordingLogHandler: LogHandler {
    let recorder: GameCenterLogRecorder
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?
    var logLevel: Logger.Level = .trace

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        recorder.record(event.message.description)
    }
}

private struct SubmittedGameCenterScore: Equatable {
    let score: Int
    let context: Int
    let leaderboardIDs: [String]
}
private struct SubmittedGameCenterAchievement: Equatable {
    let achievementID: String
    let percentComplete: Double
}

private extension Array where Element == GameCenterAchievementProgress {
    var progressByAchievementID: [String: Double] {
        Dictionary(uniqueKeysWithValues: map { ($0.achievementID, $0.percentComplete) })
    }
}

@MainActor
private struct FakeLeaderboardFactory: GameCenterLeaderboardFactory {
    var viewController: UIViewController?

    init(viewController: UIViewController? = nil) {
        self.viewController = viewController
    }

    func makeClassicSurvivalLeaderboardViewController() -> UIViewController? {
        viewController
    }
}

@MainActor
private final class FakeGameCenterLocalPlayerClient: GameCenterLocalPlayerClient {
    var isAvailable: Bool
    var isAuthenticated: Bool
    var submitScoreError: Error?
    var reportAchievementsError: Error?
    var defersScoreSubmissions = false
    var defersAchievementReports = false
    private(set) var authenticateHandlerInstallCount = 0
    private(set) var submittedScores: [SubmittedGameCenterScore] = []
    private(set) var submittedAchievementBatches: [[SubmittedGameCenterAchievement]] = []
    private var pendingScoreCompletions: [@MainActor (Error?) -> Void] = []
    private var pendingAchievementCompletions: [@MainActor (Error?) -> Void] = []
    private var authenticationHandlers: [@MainActor (UIViewController?, Error?) -> Void] = []

    var didInstallAuthenticateHandler: Bool { authenticateHandlerInstallCount > 0 }

    init(isAvailable: Bool = true, isAuthenticated: Bool = false) {
        self.isAvailable = isAvailable
        self.isAuthenticated = isAuthenticated
    }

    func setAuthenticateHandler(
        _ handler: @escaping @MainActor (_ viewController: UIViewController?, _ error: Error?) -> Void
    ) {
        authenticateHandlerInstallCount += 1
        authenticationHandlers.append(handler)
    }

    func completeAuthentication(viewController: UIViewController?, error: Error?) {
        authenticationHandlers.last?(viewController, error)
    }

    func completeAuthentication(
        usingHandlerAt index: Int,
        viewController: UIViewController?,
        error: Error?
    ) {
        authenticationHandlers[index](viewController, error)
    }

    func submitScore(
        _ score: Int,
        context: Int,
        leaderboardIDs: [String],
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        submittedScores.append(SubmittedGameCenterScore(
            score: score,
            context: context,
            leaderboardIDs: leaderboardIDs
        ))

        if defersScoreSubmissions {
            pendingScoreCompletions.append(completion)
        } else {
            completion(submitScoreError)
        }
    }

    func completeNextScoreSubmission(error: Error? = nil) {
        pendingScoreCompletions.removeFirst()(error ?? submitScoreError)
    }

    func reportAchievements(
        _ progress: [GameCenterAchievementProgress],
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        submittedAchievementBatches.append(progress.map {
            SubmittedGameCenterAchievement(
                achievementID: $0.achievementID,
                percentComplete: $0.percentComplete
            )
        })
        if defersAchievementReports {
            pendingAchievementCompletions.append(completion)
        } else {
            completion(reportAchievementsError)
        }
    }

    func completeNextAchievementReport(error: Error? = nil) {
        pendingAchievementCompletions.removeFirst()(error ?? reportAchievementsError)
    }
}

@MainActor
private final class FakeGameCenterAuthenticationPresenter: GameCenterAuthenticationPresenting {
    private(set) var presentedViewController: UIViewController?

    func presentGameCenterAuthentication(_ viewController: UIViewController) {
        presentedViewController = viewController
    }
}

@MainActor
private final class FakeGameCenterLeaderboardPresenter: GameCenterLeaderboardPresenting {
    private(set) var presentedViewController: UIViewController?

    func presentGameCenterLeaderboard(_ viewController: UIViewController) {
        presentedViewController = viewController
    }
}
