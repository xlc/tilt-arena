import UIKit
import XCTest
@testable import TiltArena

final class GameViewControllerTests: XCTestCase {
    @MainActor
    func testSupportedOrientationsAreLandscapeOnly() {
        let controller = GameViewController()

        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscape)
    }
}
