import SpriteKit

extension ArenaScene {
    func playRicochetLanceEffect(
        segments: [RicochetLanceSegment],
        targets: [WeaponImpactTarget],
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        guard !segments.isEmpty else {
            runRicochetImpactBatch(targets, delay: 0, onImpact: onImpact)
            return
        }

        var elapsed: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let travelDuration = ricochetSegmentDuration(segment)
            addRicochetBeam(segment, delay: elapsed, duration: travelDuration)

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
        duration: TimeInterval
    ) {
        let beam = ricochetBeamNode(
            segment,
            color: theme.pickupBlue.withAlphaComponent(0.95),
            lineWidth: max(2.6, weaponResolver.configuration.ricochetLanceBeamWidth * 0.48),
            glowWidth: 9,
            zPosition: 18
        )
        let core = ricochetBeamNode(
            segment,
            color: theme.playerColor.withAlphaComponent(0.95),
            lineWidth: 1.3,
            glowWidth: 3,
            zPosition: 19
        )

        addWeaponEffectNode(beam)
        addWeaponEffectNode(core)
        beam.run(ricochetRevealAction(delay: delay, duration: duration))
        core.run(ricochetRevealAction(delay: delay, duration: duration))
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
            strokeColor: theme.pickupBlue.withAlphaComponent(0.9),
            fillColor: theme.pickupBlue.withAlphaComponent(0.16),
            lineWidth: 1.5,
            glowWidth: 5
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
        let distance = hypot(segment.end.x - segment.start.x, segment.end.y - segment.start.y)
        return min(
            0.18,
            max(0.045, TimeInterval(distance / max(1, weaponEffectTiming.waveSpeed)))
        )
    }

    private func ricochetRevealAction(delay: TimeInterval, duration: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 1, duration: 0.025),
            .wait(forDuration: duration),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ])
    }

    private func runRicochetImpactBatch(
        _ targets: [WeaponImpactTarget],
        delay: TimeInterval,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        guard !targets.isEmpty else {
            return
        }

        for target in targets {
            playRicochetImpactFlash(at: target.position, delay: delay)
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

    private func playRicochetImpactFlash(at position: CGPoint, delay: TimeInterval) {
        let flash = makeEffectRing(
            radius: 13,
            strokeColor: theme.playerColor.withAlphaComponent(0.95),
            fillColor: theme.pickupBlue.withAlphaComponent(0.14),
            lineWidth: 1.4,
            glowWidth: 5
        )
        flash.position = position
        flash.alpha = 0
        flash.setScale(0.4)
        addWeaponEffectNode(flash)
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
