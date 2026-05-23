import SnapshotTesting
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaThemeSnapshotTests: XCTestCase {
    private let sceneSize = CGSize(width: 426, height: 196)
    private let safeAreaInsets = UIEdgeInsets(top: 0, left: 30, bottom: 11, right: 30)

    func testDarkTacticalRadarBackground() throws {
        assertSnapshot(
            of: try makeArenaBackgroundImage(theme: .darkTacticalRadar),
            as: .image(precision: 0.99)
        )
    }

    func testWhitePrecisionBoardBackground() throws {
        assertSnapshot(
            of: try makeArenaBackgroundImage(theme: .whitePrecisionBoard),
            as: .image(precision: 0.99)
        )
    }

    private func makeArenaBackgroundImage(theme: ArenaTheme) throws -> UIImage {
        try SnapshotImageRenderer.render(size: sceneSize, backgroundColor: theme.backgroundColor) { scene in
            scene.addChild(
                ArenaThemeRenderer(theme: theme).makeArenaBackground(
                    size: sceneSize,
                    arenaRect: ArenaGeometry.safeRect(
                        sceneSize: sceneSize,
                        safeAreaInsets: safeAreaInsets,
                        margin: 24
                    )
                )
            )
        }
    }
}
