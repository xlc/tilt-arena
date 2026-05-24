import SpriteKit

extension ArenaScene {
    func playFreezeBurstEffect(at position: CGPoint, duration: TimeInterval? = nil) {
        let radius = weaponResolver.configuration.freezeBurstRadius
        let duration = max(0.05, duration ?? weaponEffectTiming.waveDuration(radius: radius))
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupBlue.withAlphaComponent(0.9),
            fillColor: theme.pickupBlue.withAlphaComponent(0.1),
            lineWidth: 2,
            glowWidth: 6
        )
        ring.position = position
        ring.setScale(0.08)
        addWeaponEffectNode(ring)

        let innerRing = makeEffectRing(
            radius: radius * 0.46,
            strokeColor: theme.playerColor.withAlphaComponent(0.7),
            fillColor: .clear,
            lineWidth: 1.2,
            glowWidth: 3
        )
        innerRing.position = position
        innerRing.setScale(0.1)
        addWeaponEffectNode(innerRing)

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
            strokeColor: theme.pickupBlue.withAlphaComponent(0.82),
            fillColor: theme.pickupBlue.withAlphaComponent(0.12),
            lineWidth: 1.4,
            glowWidth: 5
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
}
