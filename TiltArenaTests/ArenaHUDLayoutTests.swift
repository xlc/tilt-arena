import UIKit
import XCTest
@testable import TiltArena

final class ArenaHUDLayoutTests: XCTestCase {
    func testLandscapeSafeAreaInsetsKeepHUDInsideSafeMargins() {
        let layout = ArenaHUDLayout(
            sceneSize: CGSize(width: 852, height: 393),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
            margin: 24,
            pauseControlSize: CGSize(width: 48, height: 48)
        )

        XCTAssertEqual(layout.timerPosition.x, 83, accuracy: 0.0001)
        XCTAssertEqual(layout.timerPosition.y, 369, accuracy: 0.0001)
        XCTAssertEqual(layout.comboPosition.x, 426, accuracy: 0.0001)
        XCTAssertEqual(layout.comboPosition.y, 45, accuracy: 0.0001)
        XCTAssertEqual(layout.pauseControlPosition.x, 745, accuracy: 0.0001)
        XCTAssertEqual(layout.pauseControlPosition.y, 345, accuracy: 0.0001)
    }

    func testZeroSafeAreaKeepsHUDAwayFromRawEdges() {
        let layout = ArenaHUDLayout(
            sceneSize: CGSize(width: 800, height: 360),
            safeAreaInsets: .zero,
            margin: 24,
            pauseControlSize: CGSize(width: 48, height: 48)
        )

        XCTAssertEqual(layout.timerPosition, CGPoint(x: 24, y: 336))
        XCTAssertEqual(layout.comboPosition, CGPoint(x: 400, y: 24))
        XCTAssertEqual(layout.pauseControlPosition, CGPoint(x: 752, y: 312))
    }
}
