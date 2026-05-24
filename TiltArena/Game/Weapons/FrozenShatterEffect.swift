import SpriteKit

extension ArenaScene {
    func playFrozenShatterEffect(at positions: [CGPoint], color: SKColor) {
        for position in positions {
            let ring = SKShapeNode(circleOfRadius: 16)
            ring.position = position
            ring.strokeColor = color.withAlphaComponent(0.9)
            ring.fillColor = .clear
            ring.lineWidth = 1.5
            ring.glowWidth = 4
            ring.zPosition = 18
            ring.setScale(0.35)
            addWeaponEffectNode(ring)

            let burst = SKAction.group([
                .scale(to: 1.2, duration: 0.1),
                .fadeOut(withDuration: 0.1)
            ])
            ring.run(.sequence([burst, .removeFromParent()]))
        }
    }
}
