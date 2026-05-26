import SpriteKit

extension ArenaScene {
    func playFrozenShatterEffect(at positions: [CGPoint], color: SKColor) {
        for position in positions {
            let ring = SKShapeNode(circleOfRadius: 16)
            ring.position = position
            ring.strokeColor = color.withAlphaComponent(0.66)
            ring.fillColor = .clear
            ring.lineWidth = 1.2
            ring.glowWidth = 1.4
            ring.zPosition = 18
            ring.setScale(0.35)
            addWeaponEffectNode(ring)

            let burst = SKAction.group([
                .scale(to: 1.2, duration: 0.1),
                .fadeOut(withDuration: 0.1)
            ])

            for index in 0..<4 {
                let shard = SKShapeNode(path: Self.shatterShardPath(radius: 14, angle: CGFloat(index) * .pi / 4))
                shard.position = position
                shard.strokeColor = color.withAlphaComponent(0.64)
                shard.lineWidth = 0.9
                shard.lineCap = .round
                shard.glowWidth = 1.1
                shard.zPosition = 19
                shard.setScale(0.4)
                addWeaponEffectNode(shard)
                shard.run(.sequence([burst, .removeFromParent()]))
            }

            ring.run(.sequence([burst, .removeFromParent()]))
        }
    }

    private static func shatterShardPath(radius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -cos(angle) * radius * 0.45, y: -sin(angle) * radius * 0.45))
        path.addLine(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
        return path
    }
}
