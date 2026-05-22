import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppDiagnostics.bootstrap()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppDiagnostics.logger(.app).info("app.active")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AppDiagnostics.logger(.app).info("app.inactive")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppDiagnostics.logger(.app).notice("app.background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppDiagnostics.logger(.app).notice("app.foreground")
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AppDiagnostics.logger(.app).warning("app.memory_warning")
    }
}
