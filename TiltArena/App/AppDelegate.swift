import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppDiagnostics.bootstrap()
        AppDiagnostics.logger(.app).notice("app.launch_completed", metadata: [
            "hasLaunchOptions": "\(launchOptions?.isEmpty == false)"
        ])
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        AppDiagnostics.logger(.app).info("app.scene_configuration_created", metadata: [
            "role": "\(connectingSceneSession.role.rawValue)"
        ])
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AppDiagnostics.logger(.app).warning("app.memory_warning")
        Task.detached(priority: .utility) {
            DiagnosticLogStore.shared.flushPendingWrites()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AppDiagnostics.logger(.app).notice("app.terminating")
        DiagnosticLogStore.shared.flushPendingWrites()
    }
}
