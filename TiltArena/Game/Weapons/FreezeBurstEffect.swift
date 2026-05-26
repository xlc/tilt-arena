import SpriteKit

extension ArenaScene {
    func playFreezeBurstEffect(at position: CGPoint, duration: TimeInterval? = nil) {
        let radius = weaponResolver.configuration.freezeBurstRadius
        let duration = max(0.05, duration ?? weaponEffectTiming.waveDuration(radius: radius))
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupBlue.withAlphaComponent(0.66),
            fillColor: theme.pickupBlue.withAlphaComponent(0.06),
            lineWidth: 1.6,
            glowWidth: 1.25
        )
        ring.position = position
        ring.setScale(0.08)
        addWeaponEffectNode(ring)

        let innerRing = makeEffectRing(
            radius: radius * 0.46,
            strokeColor: theme.playerColor.withAlphaComponent(0.48),
            fillColor: .clear,
            lineWidth: 1,
            glowWidth: 0.65
        )
        innerRing.position = position
        innerRing.setScale(0.1)
        addWeaponEffectNode(innerRing)

        playFreezeShardSpokes(at: position, radius: radius, duration: duration)

        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))
        innerRing.run(.sequence([
            .wait(forDuration: duration * 0.2),
            .group([
                .scale(to: 1, duration: duration * 0.78),
                .fadeOut(withDuration: duration * 0.78)
            ]),
            .removeFromParent()
        ]))
    }

    func playFreezeAppliedEffect(at position: CGPoint, radius: CGFloat) {
        let ring = makeEffectRing(
            radius: max(8, radius * 2.1),
            strokeColor: theme.pickupBlue.withAlphaComponent(0.58),
            fillColor: theme.pickupBlue.withAlphaComponent(0.07),
            lineWidth: 1.1,
            glowWidth: 1
        )
        ring.position = position
        ring.setScale(0.35)
        addWeaponEffectNode(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 1.15, duration: 0.14),
                .fadeOut(withDuration: 0.14)
            ]),
            .removeFromParent()
        ]))
    }

    private func playFreezeShardSpokes(at position: CGPoint, radius: CGFloat, duration: TimeInterval) {
        for index in 0..<6 {
            let shard = SKShapeNode(path: Self.freezeShardPath(
                innerRadius: radius * 0.16,
                outerRadius: radius * 0.88,
                angle: CGFloat(index) * .pi / 3
            ))
            shard.position = position
            shard.strokeColor = theme.playerColor.withAlphaComponent(0.5)
            shard.lineWidth = 0.9
            shard.lineCap = .round
            shard.glowWidth = 0.65
            shard.zPosition = 18
            shard.alpha = 0
            shard.setScale(0.08)
            addWeaponEffectNode(shard)
            shard.run(.sequence([
                .wait(forDuration: duration * 0.08),
                .group([.fadeAlpha(to: 0.62, duration: duration * 0.22), .scale(to: 1, duration: duration * 0.55)]),
                .fadeOut(withDuration: duration * 0.25),
                .removeFromParent()
            ]))
        }
    }

    private static func freezeShardPath(innerRadius: CGFloat, outerRadius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius))
        path.addLine(to: CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius))
        return path
    }
}
