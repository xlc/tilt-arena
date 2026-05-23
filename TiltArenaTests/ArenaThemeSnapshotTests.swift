import SnapshotTesting
import SpriteKit
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
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        view.contentScaleFactor = 1
        view.ignoresSiblingOrder = false
        view.shouldCullNonVisibleNodes = false

        let scene = SKScene(size: sceneSize)
        scene.anchorPoint = .zero
        scene.backgroundColor = theme.backgroundColor
        scene.scaleMode = .resizeFill
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

        view.presentScene(scene)
        view.layoutIfNeeded()

        guard let texture = view.texture(from: scene) else {
            throw SnapshotRenderError.missingTexture
        }

        let cgImage = texture.cgImage()
        let sourceScale = max(1, CGFloat(cgImage.width) / sceneSize.width)
        let sourceImage = UIImage(cgImage: cgImage, scale: sourceScale, orientation: .up)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(size: sceneSize, format: format).image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: sceneSize))
        }
    }
}

private enum SnapshotRenderError: Error {
    case missingTexture
}
