import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
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
        GameCenterService.shared.retryQueuedScores()
        GameCenterService.shared.retryQueuedAchievements()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        AppDiagnostics.logger(.app).notice("app.scene_disconnected")
    }
}
