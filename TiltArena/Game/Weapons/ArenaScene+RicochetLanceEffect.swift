import SpriteKit

extension ArenaScene {
    func playRicochetLanceEffect(
        segments: [RicochetLanceSegment],
        targets: [WeaponImpactTarget],
        configuration: StartingWeaponConfiguration? = nil,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let configuration = (configuration ?? weaponResolver.configuration).sanitizedForRuntime()
        guard !segments.isEmpty else {
            runRicochetImpactBatch(targets, delay: 0, onImpact: onImpact)
            return
        }

        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let travelDuration = ricochetSegmentDuration(segment)
            addRicochetBeam(segment, delay: elapsed, duration: travelDuration, configuration: configuration)

            if index < segments.count - 1 {
                playRicochetBouncePulse(at: segment.end, delay: elapsed + travelDuration)
            }

            elapsed += travelDuration * 0.72
        }

        runRicochetImpactBatch(targets, delay: elapsed + 0.04, onImpact: onImpact)
    }

    private func addRicochetBeam(
        _ segment: RicochetLanceSegment,
        delay: TimeInterval,
        duration: TimeInterval,
        configuration: StartingWeaponConfiguration
    ) {
        let beam = ricochetBeamNode(
            segment,
            color: theme.pickupBlue.withAlphaComponent(0.7),
            lineWidth: max(2.2, configuration.ricochetLanceBeamWidth * 0.4),
            glowWidth: 1.8,
            zPosition: 18
        )
        let core = ricochetBeamNode(
            segment,
            color: theme.playerColor.withAlphaComponent(0.72),
            lineWidth: 1.1,
            glowWidth: 0.65,
            zPosition: 19
        )

        addWeaponEffectNode(beam)
        addWeaponEffectNode(core)
        beam.run(ricochetRevealAction(delay: delay, duration: duration, configuration: configuration))
        core.run(ricochetRevealAction(delay: delay, duration: duration, configuration: configuration))
    }

    private func ricochetBeamNode(
        _ segment: RicochetLanceSegment,
        color: SKColor,
        lineWidth: CGFloat,
        glowWidth: CGFloat,
        zPosition: CGFloat
    ) -> SKShapeNode {
        let node = SKShapeNode(path: Self.ricochetLinePath(from: segment.start, to: segment.end))
        node.strokeColor = color
        node.lineWidth = lineWidth
        node.lineCap = .round
        node.glowWidth = glowWidth
        node.zPosition = zPosition
        node.alpha = 0
        return node
    }

    private func playRicochetBouncePulse(at position: CGPoint, delay: TimeInterval) {
        let pulse = makeEffectRing(
            radius: 11,
            strokeColor: theme.pickupBlue.withAlphaComponent(0.64),
            fillColor: theme.pickupBlue.withAlphaComponent(0.1),
            lineWidth: 1.2,
            glowWidth: 1
        )
        pulse.position = position
        pulse.alpha = 0
        pulse.setScale(0.35)
        addWeaponEffectNode(pulse)

        pulse.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .group([
                .fadeAlpha(to: 1, duration: 0.02),
                .scale(to: 1.45, duration: 0.09)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private func ricochetSegmentDuration(_ segment: RicochetLanceSegment) -> TimeInterval {
        let timing = weaponEffectTiming
        let distance = hypot(segment.end.x - segment.start.x, segment.end.y - segment.start.y)
        guard distance.isFinite else {
            return max(0.045, timing.minimumTravelDuration)
        }
        return min(
            0.18,
            max(0.045, TimeInterval(distance / max(1, timing.waveSpeed)))
        )
    }

    private func ricochetRevealAction(
        delay: TimeInterval,
        duration: TimeInterval,
        configuration: StartingWeaponConfiguration
    ) -> SKAction {
        let delay = WeaponRuntimeSafetyLimits.duration(delay)
        let duration = WeaponRuntimeSafetyLimits.duration(duration)
        let holdDuration = configuration.ricochetLanceHoldDuration
        return .sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 1, duration: 0.025),
            .wait(forDuration: duration),
            .wait(forDuration: holdDuration),
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ])
    }

    private func runRicochetImpactBatch(
        _ targets: [WeaponImpactTarget],
        delay: TimeInterval,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let plan = WeaponImpactPlan(targets: targets)
        guard !plan.impactEnemyIDs.isEmpty else {
            return
        }

        for target in plan.visualTargets {
            playRicochetImpactFlash(at: target.position, delay: delay)
        }

        let node = SKNode()
        node.zPosition = 18
        addWeaponEffectNode(node)
        node.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .run {
                onImpact(plan.impactEnemyIDs)
            },
            .removeFromParent()
        ]))
    }

    private func playRicochetImpactFlash(at position: CGPoint, delay: TimeInterval) {
        let flash = makeEffectRing(
            radius: 13,
            strokeColor: theme.playerColor.withAlphaComponent(0.7),
            fillColor: theme.pickupBlue.withAlphaComponent(0.09),
            lineWidth: 1.1,
            glowWidth: 1
        )
        flash.position = position
        flash.alpha = 0
        flash.setScale(0.4)
        addWeaponEffectNode(flash)
        playWeaponEffectSprite(.ricochetLance, at: position, size: 38, delay: delay, alpha: 0.6)
        flash.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .group([.fadeAlpha(to: 1, duration: 0.02), .scale(to: 1.2, duration: 0.1)]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private static func ricochetLinePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}
