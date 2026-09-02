import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let gameCenterClient: any GameCenterClient = SceneDelegate.makeGameCenterClient()

    private static func makeGameCenterClient() -> any GameCenterClient {
        #if DEBUG
        // The test host launches the scene delegate before tests can inject dependencies.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return NoopGameCenterClient()
        }
        #endif
        return GameCenterService.shared
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController(gameCenterClient: gameCenterClient)
        window.makeKeyAndVisible()
        self.window = window
        AppDiagnostics.logger(.app).notice("app.scene_connected")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppDiagnostics.logger(.app).info("app.active")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        (window?.rootViewController as? GameViewController)?.pauseActiveRunIfNeeded()
        AppDiagnostics.logger(.app).info("app.inactive")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AppDiagnostics.logger(.app).notice("app.background")
        Task.detached(priority: .utility) {
            DiagnosticLogStore.shared.flushPendingWrites()
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        AppDiagnostics.logger(.app).notice("app.foreground")
        gameCenterClient.retryQueuedScores()
        gameCenterClient.retryQueuedAchievements()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        AppDiagnostics.logger(.app).notice("app.scene_disconnected")
    }
}
