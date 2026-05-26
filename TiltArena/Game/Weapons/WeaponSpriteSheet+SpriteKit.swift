import SpriteKit

extension WeaponSpriteSheet {
    static func texture(for kind: WeaponKind, role: Role) -> SKTexture {
        SKTexture(
            rect: textureRect(for: kind, role: role),
            in: SKTexture(imageNamed: assetName)
        )
    }
}
