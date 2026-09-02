import SpriteKit

private struct TimeDilationAuraVisuals {
    let outerRing: SKShapeNode
    let innerRing: SKShapeNode
    let sprite: SKSpriteNode
}

extension ArenaScene {
    func playShockwaveEffect(
        at position: CGPoint,
        radius: CGFloat? = nil,
        duration: TimeInterval,
        holdDuration: TimeInterval
    ) {
        let radius = WeaponRuntimeSafetyLimits.distance(
            radius ?? weaponResolver.configuration.shockwaveRadius
        )
        let expansionDuration = max(0.01, WeaponRuntimeSafetyLimits.duration(duration))
        let holdDuration = WeaponRuntimeSafetyLimits.duration(holdDuration)
        let fadeDuration = max(0.01, holdDuration)
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupAmber.withAlphaComponent(0.95),
            fillColor: theme.pickupAmber.withAlphaComponent(0.1),
            lineWidth: 2.6,
            glowWidth: 1.8
        )
        ring.position = position
        ring.setScale(0.08)
        addWeaponEffectNode(ring)
        playWeaponEffectSprite(.shockwave, at: position, size: radius * 2.05, alpha: 0.42)
        playShockwaveEcho(at: position, radius: radius, duration: expansionDuration)

        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            let spoke = SKShapeNode(path: Self.radialLinePath(innerRadius: 10, outerRadius: radius, angle: angle))
            spoke.position = position
            spoke.strokeColor = theme.pickupAmber.withAlphaComponent(0.38)
            spoke.lineWidth = 1
            spoke.glowWidth = 0.7
            spoke.zPosition = 18
            spoke.alpha = 0
            addWeaponEffectNode(spoke)
            spoke.run(.sequence([
                .wait(forDuration: expansionDuration * 0.1),
                .fadeAlpha(to: 0.55, duration: expansionDuration * 0.15),
                .group([
                    .fadeAlpha(to: 0.12, duration: expansionDuration * 0.75),
                    .scale(to: 1.02, duration: expansionDuration * 0.75)
                ]),
                .fadeOut(withDuration: fadeDuration),
                .removeFromParent()
            ]))
        }

        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: expansionDuration),
                .fadeAlpha(to: 0.18, duration: expansionDuration)
            ]),
            .fadeOut(withDuration: fadeDuration),
            .removeFromParent()
        ]))
    }

    private func playShockwaveEcho(at position: CGPoint, radius: CGFloat, duration: TimeInterval) {
        let echoDuration = max(0.01, duration * 0.78)
        let echo = makeEffectRing(
            radius: radius * 0.72, strokeColor: theme.playerColor.withAlphaComponent(0.42),
            fillColor: theme.pickupAmber.withAlphaComponent(0.03), lineWidth: 1.2, glowWidth: 1.15
        )
        echo.position = position
        echo.setScale(0.12)
        addWeaponEffectNode(echo)
        echo.run(.sequence([
            .group([.scale(to: 1.18, duration: echoDuration), .fadeOut(withDuration: echoDuration)]),
            .removeFromParent()
        ]))
    }

    func playNovaBombEffect(targets: [WeaponImpactTarget]) -> TimeInterval {
        let plan = WeaponImpactPlan(targets: targets)
        guard let geometry = novaEffectGeometry() else {
            return 0
        }

        let center = geometry.center
        let radius = geometry.radius
        let duration = weaponEffectTiming.waveDuration(radius: radius)
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupAmber.withAlphaComponent(0.92),
            fillColor: theme.pickupAmber.withAlphaComponent(0.12),
            lineWidth: 2.8,
            glowWidth: 1.95
        )
        ring.position = center
        ring.setScale(0.04)
        addWeaponEffectNode(ring)
        playWeaponEffectSprite(.novaBomb, at: center, size: min(radius * 0.76, 310), alpha: 0.5)

        playNovaSpokes(center: center, radius: radius, duration: duration)

        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))

        for target in plan.visualTargets {
            playTravelingBolt(
                from: center,
                to: target,
                duration: duration,
                color: theme.pickupAmber,
                coreColor: theme.playerColor,
                impactRadius: 18
            )
        }
        return duration
    }

    private func novaEffectGeometry() -> (center: CGPoint, radius: CGFloat)? {
        let playableRect = currentPlayableRect
        guard playableRect.isFinite, playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        return (
            center: CGPoint(x: playableRect.midX, y: playableRect.midY),
            radius: WeaponRuntimeSafetyLimits.distance(hypot(playableRect.width, playableRect.height) / 2)
        )
    }

    private func playNovaSpokes(center: CGPoint, radius: CGFloat, duration: TimeInterval) {
        for index in 0..<16 {
            let angle = CGFloat(index) * .pi / 8
            let spoke = SKShapeNode(path: Self.radialLinePath(innerRadius: 18, outerRadius: radius, angle: angle))
            spoke.position = center
            spoke.strokeColor = theme.playerColor.withAlphaComponent(0.32)
            spoke.lineWidth = 1.15
            spoke.glowWidth = 0.85
            spoke.zPosition = 18
            spoke.alpha = 0
            addWeaponEffectNode(spoke)
            spoke.run(.sequence([
                .wait(forDuration: duration * 0.08),
                .fadeAlpha(to: 0.86, duration: duration * 0.18),
                .fadeOut(withDuration: duration * 0.54),
                .removeFromParent()
            ]))
        }
    }

    func playGravityWellEffect(
        at position: CGPoint,
        radius: CGFloat? = nil,
        duration: TimeInterval? = nil
    ) {
        gravityWellEffectNode?.removeFromParent()
        let container = SKNode()
        container.position = position
        container.zPosition = 18
        addWeaponEffectNode(container)
        gravityWellEffectNode = container

        let radius = WeaponRuntimeSafetyLimits.distance(
            radius ?? weaponResolver.configuration.gravityWellRadius
        )
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupViolet.withAlphaComponent(0.84),
            fillColor: theme.pickupViolet.withAlphaComponent(0.12),
            lineWidth: 2.2,
            glowWidth: 1.7
        )
        container.addChild(ring)

        let sprite = makeWeaponEffectSprite(kind: .gravityWell, size: radius * 1.42, zPosition: -1)
        sprite.alpha = 0.44
        sprite.setScale(0.92)
        container.addChild(sprite)

        let core = SKShapeNode(circleOfRadius: 12)
        core.fillColor = theme.pickupViolet.withAlphaComponent(0.74)
        core.strokeColor = theme.playerColor.withAlphaComponent(0.68)
        core.lineWidth = 1.2
        core.glowWidth = 1.5
        core.zPosition = 1
        container.addChild(core)

        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let arm = SKShapeNode(path: Self.radialLinePath(innerRadius: 16, outerRadius: radius * 0.86, angle: angle))
            arm.strokeColor = theme.playerColor.withAlphaComponent(0.26)
            arm.lineWidth = 1.1
            arm.glowWidth = 0.8
            container.addChild(arm)
        }

        let duration = max(
            0.12,
            WeaponRuntimeSafetyLimits.duration(
                duration ?? weaponResolver.configuration.gravityWellPullDuration
            )
        )
        container.run(.repeatForever(.rotate(byAngle: -.pi * 1.5, duration: 0.9)), withKey: "gravity.spin")
        let pulse = SKAction.group([
            .scale(to: 0.22, duration: duration),
            .fadeOut(withDuration: duration)
        ])
        container.run(.sequence([pulse, .removeFromParent()]), withKey: "gravity.collapse")
    }

    func playGravityWellCollapseEffect(
        at position: CGPoint,
        clearRadius: CGFloat,
        targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let plan = WeaponImpactPlan(targets: targets)
        let delay: TimeInterval = 0.12
        let clearRadius = WeaponRuntimeSafetyLimits.distance(clearRadius)
        let ring = makeEffectRing(
            radius: clearRadius * 1.5,
            strokeColor: theme.pickupViolet.withAlphaComponent(0.95),
            fillColor: theme.pickupViolet.withAlphaComponent(0.12),
            lineWidth: 2,
            glowWidth: 1.6
        )
        ring.position = position
        ring.setScale(1.25)
        addWeaponEffectNode(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 0.2, duration: delay),
                .fadeOut(withDuration: delay)
            ]),
            .removeFromParent()
        ]))

        for target in plan.visualTargets {
            let tether = SKShapeNode(path: Self.linePath(from: target.position, to: position))
            tether.strokeColor = theme.pickupViolet.withAlphaComponent(0.42)
            tether.lineWidth = 1.2
            tether.glowWidth = 0.8
            tether.zPosition = 18
            addWeaponEffectNode(tether)
            tether.run(.sequence([
                .fadeOut(withDuration: delay),
                .removeFromParent()
            ]))
        }

        runImpactBatch(plan.impactEnemyIDs, delay: delay, onImpact: onImpact)
    }

    func playTimeDilationAuraEffect(
        at position: CGPoint,
        radius: CGFloat,
        duration: TimeInterval
    ) -> SKNode {
        let clampedRadius = WeaponRuntimeSafetyLimits.distance(radius)
        let clampedDuration = max(0.05, WeaponRuntimeSafetyLimits.duration(duration))
        let fadeInDuration = min(0.08, clampedDuration * 0.3)
        let fadeOutDuration = min(0.18, max(0.05, clampedDuration * 0.25))
        let holdDuration = max(0, clampedDuration - fadeInDuration - fadeOutDuration)
        let container = SKNode()
        container.position = position
        container.zPosition = 18
        container.alpha = 0
        addWeaponEffectNode(container)

        let visuals = addTimeDilationAuraVisuals(to: container, radius: clampedRadius)
        visuals.outerRing.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.0, duration: 0.28),
                .fadeAlpha(to: 0.62, duration: 0.28)
            ]),
            .group([
                .scale(to: 0.9, duration: 0.28),
                .fadeAlpha(to: 1, duration: 0.28)
            ])
        ])))
        visuals.innerRing.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 1.0)))
        visuals.sprite.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 1.2)))

        container.run(.sequence([
            .fadeAlpha(to: 1, duration: fadeInDuration),
            .wait(forDuration: holdDuration),
            .fadeOut(withDuration: fadeOutDuration),
            .removeFromParent()
        ]))

        return container
    }

    private func addTimeDilationAuraVisuals(
        to container: SKNode,
        radius: CGFloat
    ) -> TimeDilationAuraVisuals {
        let outerRing = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupViolet.withAlphaComponent(0.7),
            fillColor: theme.pickupViolet.withAlphaComponent(0.07),
            lineWidth: 2.2,
            glowWidth: 1.8
        )
        outerRing.setScale(0.86)
        container.addChild(outerRing)

        let innerRing = makeEffectRing(
            radius: radius * 0.46,
            strokeColor: theme.playerAccentColor.withAlphaComponent(0.52),
            fillColor: theme.playerAccentColor.withAlphaComponent(0.03),
            lineWidth: 1.3,
            glowWidth: 1
        )
        container.addChild(innerRing)

        let core = SKShapeNode(circleOfRadius: min(14, max(7, radius * 0.08)))
        core.fillColor = theme.pickupViolet.withAlphaComponent(0.34)
        core.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        core.lineWidth = 1
        core.glowWidth = 1.1
        core.zPosition = 20
        container.addChild(core)

        addTimeDilationTicks(to: container, radius: radius)

        let sprite = makeWeaponEffectSprite(
            kind: .warpDash,
            size: min(92, max(40, radius * 0.72)),
            zPosition: 17
        )
        sprite.alpha = 0.36
        sprite.setScale(0.92)
        container.addChild(sprite)

        return TimeDilationAuraVisuals(
            outerRing: outerRing,
            innerRing: innerRing,
            sprite: sprite
        )
    }

    private func addTimeDilationTicks(to container: SKNode, radius: CGFloat) {
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let tick = SKShapeNode(path: Self.radialLinePath(
                innerRadius: radius * 0.72,
                outerRadius: radius * 0.88,
                angle: angle
            ))
            tick.strokeColor = theme.playerAccentColor.withAlphaComponent(0.24)
            tick.lineWidth = 1
            tick.glowWidth = 0.45
            tick.lineCap = .round
            tick.zPosition = 19
            container.addChild(tick)
        }
    }

    func playRazorShieldImpactEffect(
        from origin: CGPoint,
        targets: [WeaponImpactTarget]
    ) {
        let plan = WeaponImpactPlan(targets: targets)
        for target in plan.visualTargets {
            playTravelingBolt(
                from: origin,
                to: target,
                duration: max(0.08, weaponEffectTiming.projectileDuration(from: origin, to: target.position) * 0.55),
                color: theme.pickupBlue,
                coreColor: theme.playerColor,
                impactRadius: 13
            )
        }
    }

    func playRazorShieldExplosionEffect(
        at position: CGPoint,
        startRadius: CGFloat,
        explosionRadius: CGFloat,
        targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let plan = WeaponImpactPlan(targets: targets)
        let clampedExplosionRadius = WeaponRuntimeSafetyLimits.distance(explosionRadius)
        let startRadius = WeaponRuntimeSafetyLimits.distance(startRadius)
        let delay: TimeInterval = 0.1
        let ring = makeEffectRing(
            radius: clampedExplosionRadius,
            strokeColor: theme.pickupBlue.withAlphaComponent(0.95),
            fillColor: theme.pickupBlue.withAlphaComponent(0.18),
            lineWidth: 2.4,
            glowWidth: 1.7
        )
        ring.position = position
        let scale = clampedExplosionRadius > 0 ? max(0.05, min(1, startRadius / clampedExplosionRadius)) : 1
        ring.setScale(scale)
        addWeaponEffectNode(ring)
        playWeaponEffectSprite(.razorShield, at: position, size: clampedExplosionRadius * 2.25, alpha: 0.5)
        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: delay),
                .fadeAlpha(to: 0.7, duration: delay)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))

        for target in plan.visualTargets {
            playImpactBurst(
                at: target,
                delay: delay,
                color: theme.pickupBlue,
                radius: 12
            )
        }
        runImpactBatch(plan.impactEnemyIDs, delay: delay, onImpact: onImpact)
    }

    func playFlameTrailImpactEffect(at targets: [WeaponImpactTarget]) {
        let plan = WeaponImpactPlan(targets: targets)
        for target in plan.visualTargets {
            playImpactBurst(
                at: target,
                delay: 0.06,
                color: theme.pickupAmber,
                radius: 12
            )
        }
    }

    func playPowerWaveChargeEffect(at position: CGPoint, direction: CGVector, duration: TimeInterval) {
        powerWaveChargeNode?.removeFromParent()

        let container = SKNode()
        container.position = position
        container.zRotation = Self.rotation(for: direction)
        container.zPosition = 19
        addWeaponEffectNode(container)
        powerWaveChargeNode = container

        let radius = movementController.configuration.visualRadius * 2.5
        let wedge = SKShapeNode(path: Self.powerWaveFanPath(range: radius, fanAngleRadians: .pi / 2))
        wedge.fillColor = theme.pickupAmber.withAlphaComponent(0.1)
        wedge.strokeColor = theme.playerAccentColor.withAlphaComponent(0.68)
        wedge.lineWidth = 1.2
        wedge.glowWidth = 1
        container.addChild(wedge)

        let core = SKShapeNode(circleOfRadius: movementController.configuration.visualRadius * 0.7)
        core.fillColor = theme.pickupAmber.withAlphaComponent(0.18)
        core.strokeColor = theme.playerColor.withAlphaComponent(0.64)
        core.lineWidth = 1.2
        core.glowWidth = 0.8
        container.addChild(core)

        let duration = WeaponRuntimeSafetyLimits.duration(duration)
        let pulseDuration = max(0.08, min(0.18, max(0.01, duration) / 2))
        container.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.16, duration: pulseDuration),
                .fadeAlpha(to: 0.44, duration: pulseDuration)
            ]),
            .group([
                .scale(to: 0.92, duration: pulseDuration),
                .fadeAlpha(to: 1, duration: pulseDuration)
            ])
        ])))
    }

    func updatePowerWaveChargeEffect(at position: CGPoint, direction: CGVector) {
        powerWaveChargeNode?.position = position
        powerWaveChargeNode?.zRotation = Self.rotation(for: direction)
    }

    func playPowerWaveReleaseEffect(
        at position: CGPoint,
        direction: CGVector,
        range: CGFloat,
        fanAngleDegrees: CGFloat,
        travelDistance: CGFloat,
        duration: TimeInterval
    ) {
        let range = WeaponRuntimeSafetyLimits.distance(range)
        let fanAngleDegrees = fanAngleDegrees.isFinite ? min(360, max(0, fanAngleDegrees)) : 0
        let fanAngleRadians = fanAngleDegrees * .pi / 180
        let wave = SKShapeNode(path: Self.powerWaveFanPath(range: range, fanAngleRadians: fanAngleRadians))
        let position = position.isFinite ? position : .zero
        wave.position = position
        wave.zRotation = Self.rotation(for: direction)
        wave.zPosition = 18
        wave.fillColor = theme.pickupAmber.withAlphaComponent(0.14)
        wave.strokeColor = theme.playerAccentColor.withAlphaComponent(0.68)
        wave.lineWidth = 2
        wave.glowWidth = 1.8
        wave.alpha = 0
        addWeaponEffectNode(wave)

        let sprite = makeWeaponEffectSprite(kind: .powerWave, size: max(44, range * 1.15), zPosition: 19)
        sprite.position = position
        sprite.zRotation = wave.zRotation
        sprite.alpha = 0
        sprite.setScale(0.9)
        addWeaponEffectNode(sprite)

        let travel = Self.powerWaveTravel(
            from: position,
            direction: direction,
            range: range,
            distance: travelDistance,
            expansionDuration: duration
        )
        wave.run(.sequence([
            .group([
                .move(to: travel.endPosition, duration: travel.duration),
                .sequence([
                    .fadeAlpha(to: 0.54, duration: min(0.08, travel.duration * 0.35)),
                    .wait(forDuration: max(0, travel.duration - 0.16)),
                    .fadeOut(withDuration: 0.08)
                ])
            ]),
            .removeFromParent()
        ]))
        sprite.run(.sequence([
            .group([
                .move(to: travel.endPosition, duration: travel.duration),
                .sequence([
                    .fadeAlpha(to: 0.62, duration: min(0.08, travel.duration * 0.35)),
                    .wait(forDuration: max(0, travel.duration - 0.16)),
                    .fadeOut(withDuration: 0.08)
                ])
            ]),
            .removeFromParent()
        ]))
    }

    func deactivatePowerWaveChargeEffect() {
        powerWaveChargeNode?.removeFromParent()
        powerWaveChargeNode = nil
    }

}
