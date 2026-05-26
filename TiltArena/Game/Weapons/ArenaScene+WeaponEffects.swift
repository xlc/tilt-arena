import SpriteKit

struct WeaponImpactTarget: Equatable {
    let id: Int
    let position: CGPoint
}

extension ArenaScene {
    func playShockwaveEffect(
        at position: CGPoint,
        duration: TimeInterval,
        holdDuration: TimeInterval
    ) {
        let radius = weaponResolver.configuration.shockwaveRadius
        let expansionDuration = max(0.01, duration)
        let holdDuration = max(0, holdDuration)
        let fadeDuration: TimeInterval = 0.12
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupAmber.withAlphaComponent(0.95),
            fillColor: theme.pickupAmber.withAlphaComponent(0.1),
            lineWidth: 2.6,
            glowWidth: 3.2
        )
        ring.position = position
        ring.setScale(0.08)
        addWeaponEffectNode(ring)
        playShockwaveEcho(at: position, radius: radius, duration: expansionDuration)

        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            let spoke = SKShapeNode(path: Self.radialLinePath(innerRadius: 10, outerRadius: radius, angle: angle))
            spoke.position = position
            spoke.strokeColor = theme.pickupAmber.withAlphaComponent(0.38)
            spoke.lineWidth = 1
            spoke.glowWidth = 1.2
            spoke.zPosition = 18
            spoke.alpha = 0
            addWeaponEffectNode(spoke)
            spoke.run(.sequence([
                .wait(forDuration: expansionDuration * 0.15),
                .group([
                    .fadeAlpha(to: 0.55, duration: expansionDuration * 0.3),
                    .scale(to: 1.02, duration: expansionDuration * 0.3)
                ]),
                .wait(forDuration: holdDuration),
                .fadeOut(withDuration: fadeDuration),
                .removeFromParent()
            ]))
        }

        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: expansionDuration),
                .fadeAlpha(to: 0.82, duration: expansionDuration)
            ]),
            .wait(forDuration: holdDuration),
            .fadeOut(withDuration: fadeDuration),
            .removeFromParent()
        ]))
    }

    private func playShockwaveEcho(at position: CGPoint, radius: CGFloat, duration: TimeInterval) {
        let echoDuration = max(0.01, duration * 0.78)
        let echo = makeEffectRing(
            radius: radius * 0.72, strokeColor: theme.playerColor.withAlphaComponent(0.42),
            fillColor: theme.pickupAmber.withAlphaComponent(0.03), lineWidth: 1.2, glowWidth: 2
        )
        echo.position = position
        echo.setScale(0.12)
        addWeaponEffectNode(echo)
        echo.run(.sequence([
            .group([.scale(to: 1.18, duration: echoDuration), .fadeOut(withDuration: echoDuration)]),
            .removeFromParent()
        ]))
    }

    func playNovaBombEffect(
        targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let playableRect = currentPlayableRect

        guard playableRect.width > 0, playableRect.height > 0 else {
            return
        }

        let center = CGPoint(x: playableRect.midX, y: playableRect.midY)
        let radius = hypot(playableRect.width, playableRect.height) / 2
        let duration = weaponEffectTiming.waveDuration(radius: radius)
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupAmber.withAlphaComponent(0.92),
            fillColor: theme.pickupAmber.withAlphaComponent(0.12),
            lineWidth: 2.8,
            glowWidth: 3.4
        )
        ring.position = center
        ring.setScale(0.04)
        addWeaponEffectNode(ring)

        for index in 0..<16 {
            let angle = CGFloat(index) * .pi / 8
            let spoke = SKShapeNode(path: Self.radialLinePath(innerRadius: 18, outerRadius: radius, angle: angle))
            spoke.position = center
            spoke.strokeColor = theme.playerColor.withAlphaComponent(0.32)
            spoke.lineWidth = 1.15
            spoke.glowWidth = 1.5
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

        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))

        for target in targets {
            let travelDuration = weaponEffectTiming.waveDuration(from: center, to: target.position)
            playTravelingBolt(
                from: center,
                to: target,
                duration: travelDuration,
                color: theme.pickupAmber,
                coreColor: theme.playerColor,
                impactRadius: 18,
                onImpact: onImpact
            )
        }
    }

    func playSeekerSwarmEffect(
        from origin: CGPoint,
        to targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        for (index, target) in targets.enumerated() {
            let duration = weaponEffectTiming.projectileDuration(from: origin, to: target.position)
            let launchDelay = TimeInterval(index) * 0.035
            playTravelingBolt(
                from: origin,
                to: target,
                delay: launchDelay,
                duration: duration,
                color: theme.pickupViolet,
                coreColor: theme.playerColor,
                impactRadius: 12,
                onImpact: onImpact
            )
        }
    }

    func playGravityWellEffect(at position: CGPoint, duration: TimeInterval? = nil) {
        gravityWellEffectNode?.removeFromParent()
        let container = SKNode()
        container.position = position
        container.zPosition = 18
        addWeaponEffectNode(container)
        gravityWellEffectNode = container

        let radius = weaponResolver.configuration.gravityWellRadius
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: theme.pickupViolet.withAlphaComponent(0.84),
            fillColor: theme.pickupViolet.withAlphaComponent(0.12),
            lineWidth: 2.2,
            glowWidth: 3
        )
        container.addChild(ring)

        let core = SKShapeNode(circleOfRadius: 12)
        core.fillColor = theme.pickupViolet.withAlphaComponent(0.74)
        core.strokeColor = theme.playerColor.withAlphaComponent(0.68)
        core.lineWidth = 1.2
        core.glowWidth = 2.6
        core.zPosition = 1
        container.addChild(core)

        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let arm = SKShapeNode(path: Self.radialLinePath(innerRadius: 16, outerRadius: radius * 0.86, angle: angle))
            arm.strokeColor = theme.playerColor.withAlphaComponent(0.26)
            arm.lineWidth = 1.1
            arm.glowWidth = 1.4
            container.addChild(arm)
        }

        let duration = max(0.12, duration ?? weaponResolver.configuration.gravityWellPullDuration)
        container.run(.repeatForever(.rotate(byAngle: -.pi * 1.5, duration: 0.9)), withKey: "gravity.spin")
        let pulse = SKAction.group([
            .scale(to: 0.22, duration: duration),
            .fadeOut(withDuration: duration)
        ])
        container.run(.sequence([pulse, .removeFromParent()]), withKey: "gravity.collapse")
    }

    func playGravityWellCollapseEffect(
        at position: CGPoint,
        targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let delay: TimeInterval = 0.12
        let ring = makeEffectRing(
            radius: weaponResolver.configuration.gravityWellClearRadius * 1.5,
            strokeColor: theme.pickupViolet.withAlphaComponent(0.95),
            fillColor: theme.pickupViolet.withAlphaComponent(0.12),
            lineWidth: 2,
            glowWidth: 2.8
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

        for target in targets {
            let tether = SKShapeNode(path: Self.linePath(from: target.position, to: position))
            tether.strokeColor = theme.pickupViolet.withAlphaComponent(0.42)
            tether.lineWidth = 1.2
            tether.glowWidth = 1.4
            tether.zPosition = 18
            addWeaponEffectNode(tether)
            tether.run(.sequence([
                .fadeOut(withDuration: delay),
                .removeFromParent()
            ]))
        }

        runImpactBatch(targets, delay: delay, onImpact: onImpact)
    }

    func playWarpDashEffect(from startPosition: CGPoint, to endPosition: CGPoint) {
        let path = CGMutablePath()
        path.move(to: startPosition)
        path.addLine(to: endPosition)

        let streak = SKShapeNode(path: path)
        streak.strokeColor = theme.playerAccentColor.withAlphaComponent(0.68)
        streak.lineWidth = 2.4
        streak.glowWidth = 3.2
        streak.zPosition = 18
        addWeaponEffectNode(streak)

        for index in 1...5 {
            let progress = CGFloat(index) / 6
            let ghost = SKShapeNode(path: Self.dashGhostPath(radius: movementController.configuration.visualRadius * 0.75))
            ghost.position = CGPoint(
                x: startPosition.x + (endPosition.x - startPosition.x) * progress,
                y: startPosition.y + (endPosition.y - startPosition.y) * progress
            )
            ghost.strokeColor = theme.playerAccentColor.withAlphaComponent(0.38)
            ghost.fillColor = theme.playerAccentColor.withAlphaComponent(0.09)
            ghost.lineWidth = 1
            ghost.glowWidth = 1.4
            ghost.zPosition = 18
            ghost.alpha = 0
            addWeaponEffectNode(ghost)
            ghost.run(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.018),
                .fadeAlpha(to: 0.8, duration: 0.035),
                .fadeOut(withDuration: 0.12),
                .removeFromParent()
            ]))
        }

        let endpoint = SKShapeNode(circleOfRadius: movementController.configuration.visualRadius * 1.4)
        endpoint.position = endPosition
        endpoint.strokeColor = theme.pickupViolet.withAlphaComponent(0.62)
        endpoint.fillColor = theme.pickupViolet.withAlphaComponent(0.08)
        endpoint.lineWidth = 1.3
        endpoint.glowWidth = 1.8
        endpoint.zPosition = 18
        endpoint.setScale(0.35)
        addWeaponEffectNode(endpoint)

        let fade = SKAction.group([
            .fadeOut(withDuration: 0.18),
            .scale(to: 0.96, duration: 0.18)
        ])
        streak.run(.sequence([fade, .removeFromParent()]))

        let pulse = SKAction.group([
            .scale(to: 1.0, duration: 0.16),
            .fadeOut(withDuration: 0.16)
        ])
        endpoint.run(.sequence([pulse, .removeFromParent()]))
    }

    func playRazorShieldImpactEffect(
        from origin: CGPoint,
        targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        for target in targets {
            playTravelingBolt(
                from: origin,
                to: target,
                duration: max(0.08, weaponEffectTiming.projectileDuration(from: origin, to: target.position) * 0.55),
                color: theme.pickupBlue,
                coreColor: theme.playerColor,
                impactRadius: 13,
                onImpact: onImpact
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
        let clampedExplosionRadius = max(0, explosionRadius)
        let delay: TimeInterval = 0.1
        let ring = makeEffectRing(
            radius: clampedExplosionRadius,
            strokeColor: theme.pickupBlue.withAlphaComponent(0.95),
            fillColor: theme.pickupBlue.withAlphaComponent(0.18),
            lineWidth: 2.4,
            glowWidth: 3
        )
        ring.position = position
        let scale = clampedExplosionRadius > 0 ? max(0.05, min(1, startRadius / clampedExplosionRadius)) : 1
        ring.setScale(scale)
        addWeaponEffectNode(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 1, duration: delay),
                .fadeAlpha(to: 0.7, duration: delay)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))

        for target in targets {
            playImpactBurst(
                at: target,
                delay: delay,
                color: theme.pickupBlue,
                radius: 12,
                onImpact: onImpact
            )
        }
    }

    func playFlameTrailImpactEffect(
        at targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        for target in targets {
            playImpactBurst(
                at: target,
                delay: 0.06,
                color: theme.pickupAmber,
                radius: 12,
                onImpact: onImpact
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
        wedge.glowWidth = 1.8
        container.addChild(wedge)

        let core = SKShapeNode(circleOfRadius: movementController.configuration.visualRadius * 0.7)
        core.fillColor = theme.pickupAmber.withAlphaComponent(0.18)
        core.strokeColor = theme.playerColor.withAlphaComponent(0.64)
        core.lineWidth = 1.2
        core.glowWidth = 1.4
        container.addChild(core)

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
        duration: TimeInterval
    ) {
        let fanAngleRadians = min(360, max(0, fanAngleDegrees)) * .pi / 180
        let wave = SKShapeNode(path: Self.powerWaveFanPath(range: max(0, range), fanAngleRadians: fanAngleRadians))
        wave.position = position
        wave.zRotation = Self.rotation(for: direction)
        wave.zPosition = 18
        wave.fillColor = theme.pickupAmber.withAlphaComponent(0.14)
        wave.strokeColor = theme.playerAccentColor.withAlphaComponent(0.68)
        wave.lineWidth = 2
        wave.glowWidth = 3.2
        wave.setScale(0.04)
        addWeaponEffectNode(wave)

        let expansionDuration = max(0.01, duration)
        wave.run(.sequence([
            .group([
                .scale(to: 1, duration: expansionDuration),
                .fadeAlpha(to: 0.54, duration: expansionDuration * 0.55)
            ]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    func deactivatePowerWaveChargeEffect() {
        powerWaveChargeNode?.removeFromParent()
        powerWaveChargeNode = nil
    }

    private func playTravelingBolt(
        from origin: CGPoint,
        to target: WeaponImpactTarget,
        delay: TimeInterval = 0,
        duration: TimeInterval,
        color: SKColor,
        coreColor: SKColor,
        impactRadius: CGFloat,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let trail = SKShapeNode(path: Self.linePath(from: origin, to: target.position))
        trail.strokeColor = color.withAlphaComponent(0.22)
        trail.lineWidth = 0.9
        trail.glowWidth = 1.1
        trail.zPosition = 18
        trail.alpha = 0
        addWeaponEffectNode(trail)

        let projectile = SKShapeNode(circleOfRadius: 4)
        projectile.position = origin
        projectile.fillColor = color.withAlphaComponent(0.78)
        projectile.strokeColor = coreColor.withAlphaComponent(0.72)
        projectile.lineWidth = 0.8
        projectile.glowWidth = 1.4
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

        playImpactBurst(
            at: target,
            delay: delay + duration,
            color: color,
            radius: impactRadius,
            onImpact: onImpact
        )
    }

    private func playImpactBurst(
        at target: WeaponImpactTarget,
        delay: TimeInterval,
        color: SKColor,
        radius: CGFloat,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: color.withAlphaComponent(0.95),
            fillColor: color.withAlphaComponent(0.12),
            lineWidth: 1.4,
            glowWidth: 1.8
        )
        ring.position = target.position
        ring.alpha = 0
        ring.setScale(0.35)
        addWeaponEffectNode(ring)

        let spark = SKShapeNode(path: Self.crossPath(radius: radius * 0.7))
        spark.position = target.position
        spark.strokeColor = color.withAlphaComponent(0.7)
        spark.lineWidth = 1
        spark.glowWidth = 1.4
        spark.zPosition = 20
        spark.alpha = 0
        addWeaponEffectNode(spark)

        let impact = SKAction.sequence([
            .wait(forDuration: max(0, delay)),
            .run {
                onImpact([target.id])
            },
            .group([
                .fadeAlpha(to: 1, duration: 0.02),
                .scale(to: 1.15, duration: 0.1)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ])
        ring.run(impact)
        playImpactResidue(at: target.position, color: color, coreColor: theme.playerColor, radius: radius, delay: delay)
        spark.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .rotate(byAngle: .pi / 4, duration: 0.1),
                .scale(to: 1.2, duration: 0.1)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private func runImpactBatch(
        _ targets: [WeaponImpactTarget],
        delay: TimeInterval,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        guard !targets.isEmpty else {
            return
        }

        let node = SKNode()
        node.zPosition = 18
        addWeaponEffectNode(node)
        let targetIDs = Set(targets.map(\.id))
        node.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .run {
                onImpact(targetIDs)
            },
            .removeFromParent()
        ]))
    }

    func makeEffectRing(
        radius: CGFloat,
        strokeColor: SKColor,
        fillColor: SKColor,
        lineWidth: CGFloat,
        glowWidth: CGFloat
    ) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: max(0, radius))
        ring.strokeColor = strokeColor
        ring.fillColor = fillColor
        ring.lineWidth = lineWidth
        ring.glowWidth = glowWidth
        ring.zPosition = 18
        return ring
    }

    private static func linePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private static func radialLinePath(innerRadius: CGFloat, outerRadius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius))
        path.addLine(to: CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius))
        return path
    }

    private static func rotation(for direction: CGVector) -> CGFloat {
        let resolvedDirection = direction.length > 0 ? direction.normalized : CGVector(dx: 0, dy: 1)
        return atan2(resolvedDirection.dy, resolvedDirection.dx)
    }

    private static func powerWaveFanPath(range: CGFloat, fanAngleRadians: CGFloat) -> CGPath {
        let radius = max(0, range)
        let halfAngle = min(.pi, max(0, fanAngleRadians / 2))
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: cos(-halfAngle) * radius, y: sin(-halfAngle) * radius))
        path.addArc(center: .zero, radius: radius, startAngle: -halfAngle, endAngle: halfAngle, clockwise: false)
        path.closeSubpath()
        return path
    }

    private static func crossPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius, y: 0))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.move(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: 0, y: radius))
        return path
    }

    private static func dashGhostPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: -radius * 0.58, y: radius * 0.52))
        path.addLine(to: CGPoint(x: -radius * 0.28, y: 0))
        path.addLine(to: CGPoint(x: -radius * 0.58, y: -radius * 0.52))
        path.closeSubpath()
        return path
    }
}
