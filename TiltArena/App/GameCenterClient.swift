@MainActor
protocol GameCenterRunReporting: AnyObject {
    func submitRunScore(_ summary: RunSummary)
    func reportAchievementEvent(_ event: GameCenterAchievementEvent)
}

@MainActor
protocol GameCenterClient: GameCenterRunReporting {
    var menuStatus: GameCenterMenuStatus { get }

    func authenticate(
        presenter: GameCenterAuthenticationPresenting?,
        allowsPrompt: Bool
    )
    func retryAuthentication(presenter: GameCenterAuthenticationPresenting?)
    func presentLeaderboards(
        presenter: GameCenterLeaderboardPresenting
    ) -> GameCenterLeaderboardPresentationResult
    func retryQueuedScores()
    func retryQueuedAchievements()
}

@MainActor
final class NoopGameCenterClient: GameCenterClient {
    var menuStatus: GameCenterMenuStatus {
        .hidden
    }

    func authenticate(
        presenter: GameCenterAuthenticationPresenting?,
        allowsPrompt: Bool
    ) {}

    func retryAuthentication(presenter: GameCenterAuthenticationPresenting?) {}

    func presentLeaderboards(
        presenter: GameCenterLeaderboardPresenting
    ) -> GameCenterLeaderboardPresentationResult {
        .unavailable(.unsupported)
    }

    func submitRunScore(_ summary: RunSummary) {}

    func reportAchievementEvent(_ event: GameCenterAchievementEvent) {}

    func retryQueuedScores() {}

    func retryQueuedAchievements() {}
}
