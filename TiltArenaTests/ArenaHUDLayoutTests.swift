import UIKit
import XCTest
@testable import TiltArena

final class ArenaHUDLayoutTests: XCTestCase {
    func testLandscapeSafeAreaInsetsKeepHUDInsideSafeMargins() {
        let layout = ArenaHUDLayout(
            sceneSize: CGSize(width: 852, height: 393),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
            margin: 24
        )

        XCTAssertEqual(layout.scoreCapsuleFrame, CGRect(x: 77, y: 341, width: 190, height: 28))
        XCTAssertEqual(layout.bestCapsuleFrame, CGRect(x: 649, y: 341, width: 126, height: 28))
        XCTAssertEqual(layout.comboCapsuleFrame, CGRect(x: 276, y: 39, width: 300, height: 30))
        XCTAssertEqual(layout.timerPosition, CGPoint(x: 87, y: 355))
        XCTAssertEqual(layout.comboPosition, CGPoint(x: 426, y: 54))
        XCTAssertEqual(layout.bestMarkerPosition, CGPoint(x: 765, y: 355))
    }

    func testZeroSafeAreaKeepsHUDAwayFromRawEdges() {
        let layout = ArenaHUDLayout(
            sceneSize: CGSize(width: 800, height: 360),
            safeAreaInsets: .zero,
            margin: 24
        )

        XCTAssertEqual(layout.scoreCapsuleFrame, CGRect(x: 18, y: 308, width: 190, height: 28))
        XCTAssertEqual(layout.bestCapsuleFrame, CGRect(x: 656, y: 308, width: 126, height: 28))
        XCTAssertEqual(layout.comboCapsuleFrame, CGRect(x: 250, y: 18, width: 300, height: 30))
        XCTAssertEqual(layout.timerPosition, CGPoint(x: 28, y: 322))
        XCTAssertEqual(layout.comboPosition, CGPoint(x: 400, y: 33))
        XCTAssertEqual(layout.bestMarkerPosition, CGPoint(x: 772, y: 322))
    }
}
