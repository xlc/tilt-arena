import SpriteKit
import UIKit

@MainActor
enum SnapshotImageRenderer {
    static func render(
        size: CGSize,
        backgroundColor: SKColor,
        ignoresSiblingOrder: Bool = true,
        buildScene: (SKScene) -> Void
    ) throws -> UIImage {
        let scene = SKScene(size: size)
        scene.anchorPoint = .zero
        scene.backgroundColor = backgroundColor
        scene.scaleMode = .resizeFill
        buildScene(scene)

        return try render(scene: scene, ignoresSiblingOrder: ignoresSiblingOrder)
    }

    static func render(
        scene: SKScene,
        ignoresSiblingOrder: Bool = true,
        beforeSnapshot: () -> Void = {}
    ) throws -> UIImage {
        let size = scene.size
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.contentScaleFactor = 1
        // Match the shipping renderer so snapshots exercise its draw-order rules.
        view.ignoresSiblingOrder = ignoresSiblingOrder
        view.shouldCullNonVisibleNodes = false

        view.presentScene(scene)
        view.layoutIfNeeded()
        beforeSnapshot()
        view.layoutIfNeeded()

        guard let texture = view.texture(from: scene) else {
            throw SnapshotRenderError.missingTexture
        }

        let cgImage = texture.cgImage()
        let sourceScale = max(1, CGFloat(cgImage.width) / size.width)
        let sourceImage = UIImage(cgImage: cgImage, scale: sourceScale, orientation: .up)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private enum SnapshotRenderError: Error {
    case missingTexture
}
