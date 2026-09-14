import Foundation
#if canImport(GameKit)
import GameKit
#endif
import UIKit

#if canImport(GameKit)
@MainActor
struct GameKitLeaderboardFactory: GameCenterLeaderboardFactory {
    func makeLeaderboardsViewController() -> UIViewController? {
        GKGameCenterViewController(state: .leaderboards)
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
    func makeLeaderboardsViewController() -> UIViewController? {
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
