import Foundation
#if canImport(GameKit)
import GameKit
#endif
import Logging
import UIKit

@MainActor
protocol GameCenterAuthenticationPresenting: AnyObject {
    func presentGameCenterAuthentication(_ viewController: UIViewController)
}

@MainActor
protocol GameCenterLocalPlayerClient: AnyObject {
    var isAvailable: Bool { get }
    var isAuthenticated: Bool { get }

    func setAuthenticateHandler(
        _ handler: @escaping @MainActor (_ viewController: UIViewController?, _ error: Error?) -> Void
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
    private let logger: Logger
    private var hasInstalledAuthenticationHandler = false
    private var shouldSuppressAutomaticPrompt = false
    private weak var authenticationPresenter: GameCenterAuthenticationPresenting?
    private var canPresentAuthenticationPrompt = false

    private(set) var authenticationState: GameCenterAuthenticationState = .notStarted

    init(
        localPlayer: GameCenterLocalPlayerClient = GameKitLocalPlayerClient(),
        logger: Logger = AppDiagnostics.logger(.gameCenter)
    ) {
        self.localPlayer = localPlayer
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
        authenticationState = state
    }
}

#if canImport(GameKit)
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
}
#else
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
}
#endif
