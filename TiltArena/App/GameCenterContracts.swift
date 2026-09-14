import Foundation
#if canImport(GameKit)
import GameKit
#endif
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
    func makeLeaderboardsViewController() -> UIViewController?
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

enum GameCenterAchievementUnavailableReason: String {
    case unsupported
    case authenticationDeclined
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
