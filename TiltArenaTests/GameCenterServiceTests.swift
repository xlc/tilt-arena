import GameKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class GameCenterServiceTests: XCTestCase {
    func testUnsupportedClientDoesNotInstallAuthenticationHandler() {
        let client = FakeGameCenterLocalPlayerClient(isAvailable: false)
        let service = GameCenterService(localPlayer: client)

        service.authenticate(presenter: nil)

        XCTAssertEqual(service.authenticationState, .unsupported)
        XCTAssertFalse(client.didInstallAuthenticateHandler)
    }

    func testAlreadyAuthenticatedClientBecomesAuthenticatedWithoutInstallingHandler() {
        let client = FakeGameCenterLocalPlayerClient(isAuthenticated: true)
        let service = GameCenterService(localPlayer: client)

        service.authenticate(presenter: nil)

        XCTAssertEqual(service.authenticationState, .authenticated)
        XCTAssertFalse(client.didInstallAuthenticateHandler)
    }

    func testAuthenticationCompletionBecomesAuthenticated() {
        let client = FakeGameCenterLocalPlayerClient()
        let service = GameCenterService(localPlayer: client)

        service.authenticate(presenter: nil)
        client.isAuthenticated = true
        client.completeAuthentication(viewController: nil, error: nil)

        XCTAssertEqual(service.authenticationState, .authenticated)
    }

    func testPromptIsPresentedWhenAllowed() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = GameCenterService(localPlayer: client)
        let viewController = UIViewController()

        service.authenticate(presenter: presenter)
        client.completeAuthentication(viewController: viewController, error: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertTrue(presenter.presentedViewController === viewController)
    }

    func testPromptIsDeferredWhenAutomaticPromptIsNotAllowed() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = GameCenterService(localPlayer: client)

        service.authenticate(presenter: presenter, allowsPrompt: false)
        client.completeAuthentication(viewController: UIViewController(), error: nil)

        XCTAssertEqual(service.authenticationState, .needsUserAuthentication)
        XCTAssertNil(presenter.presentedViewController)
    }

    func testCancelledAuthenticationSuppressesLaterAutomaticPrompt() {
        let client = FakeGameCenterLocalPlayerClient()
        let presenter = FakeGameCenterAuthenticationPresenter()
        let service = GameCenterService(localPlayer: client)

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
        let service = GameCenterService(localPlayer: client)

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
        let service = GameCenterService(localPlayer: client)
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
        let service = GameCenterService(localPlayer: client)

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
}

@MainActor
private final class FakeGameCenterLocalPlayerClient: GameCenterLocalPlayerClient {
    var isAvailable: Bool
    var isAuthenticated: Bool
    private(set) var authenticateHandlerInstallCount = 0

    var didInstallAuthenticateHandler: Bool {
        authenticateHandlerInstallCount > 0
    }

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
}

@MainActor
private final class FakeGameCenterAuthenticationPresenter: GameCenterAuthenticationPresenting {
    private(set) var presentedViewController: UIViewController?

    func presentGameCenterAuthentication(_ viewController: UIViewController) {
        presentedViewController = viewController
    }
}
