import XCTest
@testable import TiltArena

final class AppLifecycleConfigurationTests: XCTestCase {
    func testInfoPlistDeclaresSingleApplicationSceneDelegate() throws {
        let infoDictionary = try XCTUnwrap(Bundle(for: AppDelegate.self).infoDictionary)
        let manifest = try XCTUnwrap(
            infoDictionary["UIApplicationSceneManifest"] as? [String: Any]
        )

        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, false)

        let configurations = try XCTUnwrap(
            manifest["UISceneConfigurations"] as? [String: Any]
        )
        let applicationConfigurations = try XCTUnwrap(
            configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]]
        )
        XCTAssertEqual(applicationConfigurations.count, 1)

        let configuration = try XCTUnwrap(applicationConfigurations.first)

        XCTAssertEqual(configuration["UISceneConfigurationName"] as? String, "Default Configuration")

        let sceneDelegateClassName = try XCTUnwrap(
            configuration["UISceneDelegateClassName"] as? String
        )
        XCTAssertEqual(sceneDelegateClassName, String(reflecting: SceneDelegate.self))
    }
}
