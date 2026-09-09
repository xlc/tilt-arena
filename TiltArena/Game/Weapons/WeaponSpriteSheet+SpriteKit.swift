import SpriteKit
import UIKit

@MainActor
extension WeaponSpriteSheet {
    private static let atlasTexture: SKTexture = {
        guard let image = UIImage(named: assetName) else {
            preconditionFailure("Missing weapon glyph atlas.")
        }
        // Normalize the generated alpha mask once; SpriteKit multiplies texture RGB when tinting.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let bounds = CGRect(origin: .zero, size: image.size)
        let mask = UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            image.draw(in: bounds)
            context.cgContext.setBlendMode(.sourceIn)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(bounds)
        }
        return SKTexture(image: mask)
    }()

    static func texture(for kind: WeaponKind) -> SKTexture {
        SKTexture(
            rect: textureRect(for: kind),
            in: atlasTexture
        )
    }
}
