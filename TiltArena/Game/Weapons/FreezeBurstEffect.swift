import SpriteKit

extension ArenaScene {
    func playFreezeBurstEffect(
        at position: CGPoint,
        radius: CGFloat? = nil,
        duration: TimeInterval? = nil
    ) {
        let radius = WeaponRuntimeSafetyLimits.distance(
            radius ?? weaponResolver.configuration.freezeBurstRadius
        )
        let duration = max(
            0.05,
            WeaponRuntimeSafetyLimits.duration(
                duration ?? weaponEffectTiming.waveDuration(radius: radius)
            )
        )
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupBlue.withAlphaComponent(0.88),
            fillColor: .clear,
            lineWidth: 1.8,
            glowWidth: theme.kind == .darkTacticalRadar ? 0.8 : 0
        )
        ring.position = position
        ring.setScale(0.08)
        addWeaponEffectNode(ring)
        playWeaponEffectSprite(.freezeBurst, at: position, size: radius * 1.85, alpha: 0.44)

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
                .fadeAlpha(to: 0.42, duration: duration)
            ]),
            .fadeOut(withDuration: 0.12),
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
        let path = CGMutablePath()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let direction = CGVector(dx: cos(angle), dy: sin(angle))
            let normal = CGVector(dx: -direction.dy, dy: direction.dx)
            path.move(to: CGPoint(x: direction.dx * radius * 0.94, y: direction.dy * radius * 0.94))
            path.addLine(to: CGPoint(
                x: (direction.dx * 0.74 + normal.dx * 0.035) * radius,
                y: (direction.dy * 0.74 + normal.dy * 0.035) * radius
            ))
            path.addLine(to: CGPoint(x: direction.dx * radius * 0.6, y: direction.dy * radius * 0.6))
            path.addLine(to: CGPoint(
                x: (direction.dx * 0.74 - normal.dx * 0.035) * radius,
                y: (direction.dy * 0.74 - normal.dy * 0.035) * radius
            ))
            path.closeSubpath()
        }
        let shards = SKShapeNode(path: path)
        shards.position = position
        shards.fillColor = theme.pickupBlue.withAlphaComponent(0.3)
        shards.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        shards.lineWidth = 0.8
        shards.zPosition = 18.1
        shards.setScale(0.08)
        addWeaponEffectNode(shards)
        shards.run(.sequence([
            .group([.scale(to: 1, duration: duration), .fadeAlpha(to: 0.5, duration: duration)]),
            .fadeOut(withDuration: 0.14),
            .removeFromParent()
        ]))
    }
}
