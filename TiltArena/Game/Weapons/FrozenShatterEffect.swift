import SpriteKit

extension ArenaScene {
    func playFrozenShatterEffect(at positions: [CGPoint], color: SKColor) {
        for position in WeaponImpactPlan.evenlySampled(positions) {
            let ring = SKShapeNode(circleOfRadius: 16)
            ring.position = position
            ring.strokeColor = color.withAlphaComponent(0.66)
            ring.fillColor = .clear
            ring.lineWidth = 1.2
            ring.glowWidth = 0.8
            ring.zPosition = 18
            ring.setScale(0.35)
            addWeaponEffectNode(ring)

            let burst = SKAction.group([
                .scale(to: 1.2, duration: 0.1),
                .fadeOut(withDuration: 0.1)
            ])

            let shards = SKShapeNode(path: Self.shatterShardBurstPath(radius: 14))
            shards.position = position
            shards.strokeColor = color.withAlphaComponent(0.64)
            shards.lineWidth = 0.9
            shards.lineCap = .round
            shards.glowWidth = 0.65
            shards.zPosition = 19
            shards.setScale(0.4)
            addWeaponEffectNode(shards)
            shards.run(.sequence([burst, .removeFromParent()]))

            ring.run(.sequence([burst, .removeFromParent()]))
        }
    }

    private static func shatterShardBurstPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 4
            path.move(to: CGPoint(x: -cos(angle) * radius * 0.45, y: -sin(angle) * radius * 0.45))
            path.addLine(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
        }
        return path
    }
}
