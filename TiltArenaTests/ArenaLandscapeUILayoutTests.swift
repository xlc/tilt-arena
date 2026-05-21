import UIKit
import XCTest
@testable import TiltArena

final class ArenaLandscapeUILayoutTests: XCTestCase {
    func testSafeRectHonorsLandscapeInsetsAndMargin() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 852, height: 393),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
            margin: 24
        )

        XCTAssertEqual(layout.safeRect, CGRect(x: 83, y: 45, width: 686, height: 324))
        XCTAssertEqual(layout.titlePosition, CGPoint(x: 83, y: 369))
        XCTAssertEqual(layout.bottomCenterPosition, CGPoint(x: 426, y: 45))
    }

    func testBottomButtonsRemainCenteredInLandscapeSafeRect() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 800, height: 360),
            safeAreaInsets: .zero,
            margin: 24
        )

        let first = layout.bottomButtonFrame(
            index: 0,
            count: 3,
            buttonSize: CGSize(width: 100, height: 40)
        )
        let last = layout.bottomButtonFrame(
            index: 2,
            count: 3,
            buttonSize: CGSize(width: 100, height: 40)
        )

        XCTAssertEqual(first.minX, 238)
        XCTAssertEqual(last.maxX, 562)
    }

    func testStackedLowerRightButtonClearsBottomControlsOnCompactLandscape() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 667, height: 375),
            safeAreaInsets: .zero,
            margin: 24
        )
        let bottomButtonSize = CGSize(width: 108, height: 38)
        let playFrame = layout.stackedLowerRightButtonFrame(
            aboveBottomControlHeight: bottomButtonSize.height
        )

        for index in 0..<3 {
            let bottomFrame = layout.bottomButtonFrame(
                index: index,
                count: 3,
                buttonSize: bottomButtonSize
            )
            XCTAssertFalse(playFrame.intersects(bottomFrame))
        }

        XCTAssertEqual(playFrame.minY, 78)
        XCTAssertEqual(playFrame.maxX, layout.safeRect.maxX)
    }
}
