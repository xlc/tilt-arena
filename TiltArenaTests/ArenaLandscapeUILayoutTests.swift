import UIKit
import XCTest
@testable import TiltArena

final class ArenaLandscapeUILayoutTests: XCTestCase {
    func testLogicalArenaFitsSmallAndLargePhonesWithoutStretching() {
        for (size, insets) in [
            (CGSize(width: 667, height: 375), UIEdgeInsets.zero),
            (CGSize(width: 852, height: 393), UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)),
            (CGSize(width: 932, height: 430), UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59))
        ] {
            let layout = ArenaLandscapeUILayout(sceneSize: size, safeAreaInsets: insets, margin: 24)
            let frame = layout.gameplayWorldFrame
            XCTAssertTrue(layout.gameplayRect.insetBy(dx: -0.0001, dy: -0.0001).contains(frame))
            XCTAssertEqual(frame.width / frame.height, 718 / 377.0, accuracy: 0.0001)
            XCTAssertEqual(frame.midX, layout.gameplayRect.midX, accuracy: 0.0001)
            XCTAssertEqual(frame.midY, layout.gameplayRect.midY, accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(layout.gameplayWorldScale, 0.9)
        }
    }

    func testSafeRectHonorsLandscapeInsetsAndMargin() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 852, height: 393),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
            margin: 24
        )

        XCTAssertEqual(layout.safeRect, CGRect(x: 83, y: 45, width: 686, height: 324))
    }

    func testGameplayRectUsesCameraInsetsWithoutReservingVerticalControlArea() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 852, height: 393),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59),
            margin: 24
        )

        XCTAssertEqual(layout.gameplayRect, CGRect(x: 67, y: 8, width: 718, height: 377))
        XCTAssertLessThan(layout.gameplayRect.minY, layout.safeRect.minY)
        XCTAssertGreaterThan(layout.gameplayRect.maxY, layout.safeRect.maxY)
        XCTAssertGreaterThanOrEqual(layout.gameplayRect.minX, 59)
        XCTAssertLessThanOrEqual(layout.gameplayRect.maxX, 852 - 59)
    }

    func testSafeRectHonorsAsymmetricLandscapeInsets() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 932, height: 430),
            safeAreaInsets: UIEdgeInsets(top: 9, left: 59, bottom: 34, right: 21),
            margin: 24
        )

        XCTAssertEqual(layout.safeRect, CGRect(x: 83, y: 58, width: 804, height: 339))
    }

    func testGameplayRectHonorsAsymmetricCameraInsets() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 932, height: 430),
            safeAreaInsets: UIEdgeInsets(top: 9, left: 59, bottom: 34, right: 21),
            margin: 24
        )

        XCTAssertEqual(layout.gameplayRect, CGRect(x: 67, y: 8, width: 836, height: 414))
        XCTAssertEqual(layout.safeRect.minY, 58)
        XCTAssertEqual(layout.gameplayRect.minY, 8)
        XCTAssertGreaterThanOrEqual(layout.gameplayRect.minX, 59)
        XCTAssertLessThanOrEqual(layout.gameplayRect.maxX, 932 - 21)
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

    func testControlsStayInsidePlayfieldBorder() {
        let layout = ArenaLandscapeUILayout(
            sceneSize: CGSize(width: 667, height: 375),
            safeAreaInsets: .zero,
            margin: 24
        )
        let bottomButtonSize = CGSize(width: 108, height: 38)

        XCTAssertEqual(
            layout.bottomButtonFrame(index: 0, count: 3, buttonSize: bottomButtonSize).minY,
            layout.controlRect.minY
        )
        XCTAssertEqual(layout.lowerRightButtonFrame.maxX, layout.controlRect.maxX)

        for index in 0..<3 {
            XCTAssertTrue(
                layout.controlRect.contains(
                    layout.bottomButtonFrame(index: index, count: 3, buttonSize: bottomButtonSize)
                )
            )
        }
    }
}
