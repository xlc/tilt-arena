import SpriteKit

extension ArenaScene {
    func playSeekerSwarmEffect(
        from origin: CGPoint,
        to targets: [WeaponImpactTarget],
        onImpact: @escaping (WeaponImpactTarget) -> Void
    ) {
        for (index, target) in targets.enumerated() {
            let duration = seekerTravelDuration(from: origin, to: target.position)
            playSeekerBolt(
                from: origin,
                to: target,
                delay: TimeInterval(index) * 0.035,
                duration: duration,
                onImpact: onImpact
            )
        }
    }

    private func seekerTravelDuration(from origin: CGPoint, to target: CGPoint) -> TimeInterval {
        let distance = hypot(target.x - origin.x, target.y - origin.y)
        guard distance > 0 else {
            return weaponEffectTiming.minimumTravelDuration
        }

        let speed = max(1, weaponResolver.configuration.seekerTravelSpeed)
        return max(weaponEffectTiming.minimumTravelDuration, TimeInterval(distance / speed))
    }

    private func playSeekerBolt(
        from origin: CGPoint,
        to target: WeaponImpactTarget,
        delay: TimeInterval,
        duration: TimeInterval,
        onImpact: @escaping (WeaponImpactTarget) -> Void
    ) {
        let trail = SKShapeNode(path: Self.seekerLinePath(from: origin, to: target.position))
        trail.strokeColor = theme.pickupViolet.withAlphaComponent(0.22)
        trail.lineWidth = 0.9
        trail.glowWidth = 0.65
        trail.zPosition = 18
        trail.alpha = 0
        addWeaponEffectNode(trail)

        let projectile = SKShapeNode(circleOfRadius: 4)
        projectile.position = origin
        projectile.fillColor = theme.pickupViolet.withAlphaComponent(0.78)
        projectile.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        projectile.lineWidth = 0.8
        projectile.glowWidth = 0.8
        projectile.zPosition = 19
        projectile.alpha = 0
        addWeaponEffectNode(projectile)

        trail.run(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 0.5, duration: min(0.05, duration * 0.35)),
            .wait(forDuration: max(0, duration * 0.45)),
            .fadeOut(withDuration: max(0.04, duration * 0.35)),
            .removeFromParent()
        ]))

        projectile.run(.sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .move(to: target.position, duration: duration),
                .scale(to: 1.35, duration: duration)
            ]),
            .removeFromParent()
        ]))

        playSeekerExplosion(at: target, delay: delay + duration, onImpact: onImpact)
    }

    private func playSeekerExplosion(
        at target: WeaponImpactTarget,
        delay: TimeInterval,
        onImpact: @escaping (WeaponImpactTarget) -> Void
    ) {
        let radius = weaponResolver.configuration.seekerExplosionRadius
        let holdDuration = max(0, weaponResolver.configuration.seekerExplosionHoldDuration)
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupViolet.withAlphaComponent(0.95),
            fillColor: theme.pickupViolet.withAlphaComponent(0.13),
            lineWidth: 1.6,
            glowWidth: 1.2
        )
        ring.position = target.position
        ring.alpha = 0
        ring.setScale(0.3)
        addWeaponEffectNode(ring)
        playWeaponEffectSprite(.seekerSwarm, at: target.position, size: radius * 2.2, delay: delay, alpha: 0.58)

        ring.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .run {
                onImpact(target)
            },
            .group([
                .fadeAlpha(to: 1, duration: 0.02),
                .scale(to: 1, duration: 0.08)
            ]),
            .wait(forDuration: holdDuration),
            .fadeOut(withDuration: 0.1),
            .removeFromParent()
        ]))
        playImpactResidue(
            at: target.position,
            color: theme.pickupViolet,
            coreColor: theme.playerColor,
            radius: radius,
            delay: delay
        )
        playSeekerExplosionSpark(at: target.position, radius: radius, delay: delay)
    }

    private func playSeekerExplosionSpark(at position: CGPoint, radius: CGFloat, delay: TimeInterval) {
        let spark = SKShapeNode(path: Self.seekerCrossPath(radius: min(18, max(8, radius * 0.32))))
        spark.position = position
        spark.strokeColor = theme.playerColor.withAlphaComponent(0.74)
        spark.lineWidth = 1.1
        spark.glowWidth = 0.8
        spark.zPosition = 20
        spark.alpha = 0
        addWeaponEffectNode(spark)

        spark.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .rotate(byAngle: .pi / 3, duration: 0.1),
                .scale(to: 1.2, duration: 0.1)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private static func seekerLinePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private static func seekerCrossPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius, y: 0))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.move(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: 0, y: radius))
        return path
    }
}
