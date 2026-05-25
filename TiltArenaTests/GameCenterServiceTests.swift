import GameKit
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

    func testRunFinishedAchievementEventSubmitsMilestoneProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)
        let summary = makeRunSummary(
            score: 50_000,
            survivalTime: 30,
            maxCombo: 25,
            enemiesDestroyed: 4
        )

        service.reportAchievementEvent(.runFinished(summary))

        XCTAssertEqual(client.submittedAchievementBatches.count, 1)
        let progress = client.submittedAchievementBatches[0].progressByAchievementID
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstRun.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstEnemyClear.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo10.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo50.rawValue], 50)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.survive60.rawValue], 50)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.score100000.rawValue], 50)
    }

    func testEnemyClearAchievementEventSubmitsFirstClearChainAndComboProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.enemyClear(count: 2, weaponKind: .chainLightning, maxCombo: 12))

        XCTAssertEqual(client.submittedAchievementBatches.count, 1)
        let progress = client.submittedAchievementBatches[0].progressByAchievementID
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstEnemyClear.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstChainReaction.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo10.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo50.rawValue], 24)
        XCTAssertNil(progress[GameCenterIdentifiers.Achievement.firstRun.rawValue])
    }

    func testWeaponOrbAchievementEventSubmitsFirstOrbProgress() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = makeService(localPlayer: client)

        service.reportAchievementEvent(.weaponOrbCollected)

        XCTAssertEqual(
            client.submittedAchievementBatches.flatMap { $0 }.map(\.achievementID),
            [GameCenterIdentifiers.Achievement.firstWeaponOrb.rawValue]
        )
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

    private func makeService(
        localPlayer: FakeGameCenterLocalPlayerClient,
        leaderboardFactory: GameCenterLeaderboardFactory = FakeLeaderboardFactory()
    ) -> GameCenterService {
        GameCenterService(
            localPlayer: localPlayer,
            scoreSubmissionStore: scoreSubmissionStore,
            achievementProgressStore: achievementProgressStore,
            leaderboardFactory: leaderboardFactory
        )
    }

    private func makeRunSummary(
        score: Int,
        survivalTime: TimeInterval = 12,
        maxCombo: Int = 3,
        enemiesDestroyed: Int = 4,
        timestamp: TimeInterval = 1,
        mode: ArenaModeKind = .classic
    ) -> RunSummary {
        RunSummary(
            score: score,
            survivalTime: survivalTime,
            maxCombo: maxCombo,
            enemiesDestroyed: enemiesDestroyed,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: timestamp),
            mode: mode
        )
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

private extension Array where Element == SubmittedGameCenterAchievement {
    var progressByAchievementID: [String: Double] {
        Dictionary(uniqueKeysWithValues: map { ($0.achievementID, $0.percentComplete) })
    }
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

    var didInstallAuthenticateHandler: Bool { authenticateHandlerInstallCount > 0 }

    private var handler: ((UIViewController?, Error?) -> Void)?

    init(isAvailable: Bool = true, isAuthenticated: Bool = false) {
        self.isAvailable = isAvailable
        self.isAuthenticated = isAuthenticated
    }

    func setAuthenticateHandler(
        _ handler: @escaping @MainActor (_ viewController: UIViewController?, _ error: Error?) -> Void
    ) {
        authenticateHandlerInstallCount += 1
        self.handler = handler
    }

    func completeAuthentication(viewController: UIViewController?, error: Error?) {
        handler?(viewController, error)
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
