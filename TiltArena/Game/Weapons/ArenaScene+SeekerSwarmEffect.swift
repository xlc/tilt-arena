import SpriteKit

extension ArenaScene {
    @discardableResult
    func playSeekerSwarmEffect(
        from origin: CGPoint,
        to targets: [WeaponImpactTarget],
        configuration: StartingWeaponConfiguration? = nil,
        targetPosition: @escaping (Int) -> CGPoint? = { _ in nil },
        onImpact: @escaping (WeaponImpactTarget) -> Void
    ) -> TimeInterval {
        var lastImpact: TimeInterval = 0
        let configuration = (configuration ?? weaponResolver.configuration)
        for (index, target) in targets.enumerated() {
            let duration = seekerTravelDuration(
                from: origin,
                to: target.position,
                configuration: configuration
            )
            lastImpact = max(lastImpact, TimeInterval(index) * 0.035 + duration)
            playSeekerBolt(
                SeekerBoltSpec(
                    origin: origin,
                    target: target,
                    delay: TimeInterval(index) * 0.035,
                    duration: duration,
                    configuration: configuration
                ),
                targetPosition: targetPosition,
                onImpact: onImpact
            )
        }
        return lastImpact
    }

    private func seekerTravelDuration(
        from origin: CGPoint,
        to target: CGPoint,
        configuration: StartingWeaponConfiguration
    ) -> TimeInterval {
        let timing = weaponEffectTiming
        let distance = hypot(target.x - origin.x, target.y - origin.y)
        guard distance.isFinite, distance > 0 else {
            return timing.minimumTravelDuration
        }

        let speed = max(1, configuration.seekerTravelSpeed)
        let rawDuration = TimeInterval(distance / speed)
        let maximumDuration = max(
            timing.minimumTravelDuration,
            timing.maximumProjectileTravelDuration
        )
        guard rawDuration.isFinite else {
            return maximumDuration
        }
        return min(maximumDuration, max(timing.minimumTravelDuration, rawDuration))
    }

    private func playSeekerBolt(
        _ spec: SeekerBoltSpec,
        targetPosition: @escaping (Int) -> CGPoint?,
        onImpact: @escaping (WeaponImpactTarget) -> Void
    ) {
        let trail = makeSeekerTrail(from: spec.origin, to: spec.target.position)
        addWeaponEffectNode(trail)

        let projectile = makeSeekerProjectile(at: spec.origin)
        addWeaponEffectNode(projectile)

        trail.run(seekerTrailAction(delay: spec.delay, duration: spec.duration))
        projectile.run(seekerProjectileAction(
            spec: spec,
            trail: trail,
            targetPosition: targetPosition,
            onImpact: onImpact
        ))
    }

    private func makeSeekerTrail(from origin: CGPoint, to target: CGPoint) -> SKShapeNode {
        let trail = SKShapeNode(path: Self.linePath(from: origin, to: target))
        trail.strokeColor = theme.pickupViolet.withAlphaComponent(0.22)
        trail.lineWidth = 0.9
        trail.glowWidth = 0.65
        trail.zPosition = 18
        trail.alpha = 0
        return trail
    }

    private func makeSeekerProjectile(at origin: CGPoint) -> SKShapeNode {
        let projectile = SKShapeNode(circleOfRadius: 4)
        projectile.position = origin
        projectile.fillColor = theme.pickupViolet.withAlphaComponent(0.78)
        projectile.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        projectile.lineWidth = 0.8
        projectile.glowWidth = 0.8
        projectile.zPosition = 19
        projectile.alpha = 0
        return projectile
    }

    private func seekerTrailAction(delay: TimeInterval, duration: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 0.5, duration: min(0.05, duration * 0.35)),
            .wait(forDuration: max(0, duration * 0.45)),
            .fadeOut(withDuration: max(0.04, duration * 0.35)),
            .removeFromParent()
        ])
    }

    private func seekerProjectileAction(
        spec: SeekerBoltSpec,
        trail: SKShapeNode,
        targetPosition: @escaping (Int) -> CGPoint?,
        onImpact: @escaping (WeaponImpactTarget) -> Void
    ) -> SKAction {
        var impactTarget = spec.target

        return .sequence([
            .wait(forDuration: spec.delay),
            .group([
                .fadeAlpha(to: 1, duration: min(0.02, spec.duration)),
                Self.seekAction(
                    from: spec.origin,
                    toward: spec.target,
                    duration: spec.duration,
                    targetPosition: targetPosition,
                    trail: trail
                ) { updatedTarget in
                    impactTarget = updatedTarget
                },
                .scale(to: 1.35, duration: spec.duration)
            ]),
            .run { [weak self] in
                if let trackedPosition = targetPosition(spec.target.id) {
                    impactTarget = WeaponImpactTarget(id: spec.target.id, position: trackedPosition)
                }
                onImpact(impactTarget)
                self?.playSeekerExplosion(
                    at: impactTarget,
                    configuration: spec.configuration
                )
            },
            .removeFromParent()
        ])
    }

    private static func seekAction(
        from origin: CGPoint,
        toward target: WeaponImpactTarget,
        duration: TimeInterval,
        targetPosition: @escaping (Int) -> CGPoint?,
        trail: SKShapeNode,
        updateImpactTarget: @escaping (WeaponImpactTarget) -> Void
    ) -> SKAction {
        var lastKnownPosition = target.position

        return SKAction.customAction(withDuration: duration) { node, elapsedTime in
            let progress = duration > 0 ? min(1, max(0, elapsedTime / CGFloat(duration))) : 1
            if let trackedPosition = targetPosition(target.id) {
                lastKnownPosition = trackedPosition
            }
            let projectilePosition = CGPoint(
                x: origin.x + (lastKnownPosition.x - origin.x) * progress,
                y: origin.y + (lastKnownPosition.y - origin.y) * progress
            )
            node.position = projectilePosition
            trail.path = linePath(from: origin, to: projectilePosition)
            updateImpactTarget(WeaponImpactTarget(id: target.id, position: lastKnownPosition))
        }
    }

    private func playSeekerExplosion(
        at target: WeaponImpactTarget,
        configuration: StartingWeaponConfiguration
    ) {
        let radius = configuration.seekerExplosionRadius
        let holdDuration = configuration.seekerExplosionHoldDuration
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
        playWeaponEffectSprite(.seekerSwarm, at: target.position, size: radius * 2.2, alpha: 0.58)

        ring.run(.sequence([
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
            delay: 0
        )
        playSeekerExplosionSpark(at: target.position, radius: radius)
    }

    private func playSeekerExplosionSpark(at position: CGPoint, radius: CGFloat) {
        let spark = SKShapeNode(path: Self.crossPath(radius: min(18, max(8, radius * 0.32))))
        spark.position = position
        spark.strokeColor = theme.playerColor.withAlphaComponent(0.74)
        spark.lineWidth = 1.1
        spark.glowWidth = 0.8
        spark.zPosition = 20
        spark.alpha = 0
        addWeaponEffectNode(spark)

        spark.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .rotate(byAngle: .pi / 3, duration: 0.1),
                .scale(to: 1.2, duration: 0.1)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }
}

private struct SeekerBoltSpec {
    let origin: CGPoint
    let target: WeaponImpactTarget
    let delay: TimeInterval
    let duration: TimeInterval
    let configuration: StartingWeaponConfiguration
}
