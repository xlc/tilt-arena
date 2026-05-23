import SpriteKit
import UIKit

@MainActor
enum SnapshotImageRenderer {
    static func render(
        size: CGSize,
        backgroundColor: SKColor,
        buildScene: (SKScene) -> Void
    ) throws -> UIImage {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.contentScaleFactor = 1
        view.ignoresSiblingOrder = false
        view.shouldCullNonVisibleNodes = false

        let scene = SKScene(size: size)
        scene.anchorPoint = .zero
        scene.backgroundColor = backgroundColor
        scene.scaleMode = .resizeFill
        buildScene(scene)

        view.presentScene(scene)
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
