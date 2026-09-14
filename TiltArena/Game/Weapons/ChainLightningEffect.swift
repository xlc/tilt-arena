import SpriteKit

extension ArenaScene {
    @discardableResult
    func playChainLightningEffect(
        from origin: CGPoint,
        through targets: [WeaponImpactTarget],
        configuration: StartingWeaponConfiguration? = nil,
        onImpact: ((Set<Int>) -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) -> TimeInterval {
        let configuration = (configuration ?? weaponResolver.configuration)
        let accentColor = theme.weaponColor(for: .chainLightning)
        let coreColor = theme.playerColor
        let targetPositions = targets.isEmpty
            ? [randomChainFallbackTarget(from: origin, configuration: configuration)]
            : targets.map(\.position)
        let impactDelays = weaponEffectTiming.chainImpactDelays(origin: origin, targets: targetPositions)
        let charge = SKShapeNode(circleOfRadius: 5.5)
        charge.position = origin
        charge.fillColor = accentColor.withAlphaComponent(0.72)
        charge.strokeColor = coreColor.withAlphaComponent(0.72)
        charge.lineWidth = 1
        charge.glowWidth = 1.25
        charge.zPosition = 20
        addWeaponEffectNode(charge)
        playChainChargeRing(at: origin, accentColor: accentColor)

        var previousPoint = origin
        var previousDelay: TimeInterval = 0
        var travelActions: [SKAction] = []

        for (index, targetPosition) in targetPositions.enumerated() {
            let impactDelay = impactDelays[index]
            let travelDuration = max(0.04, impactDelay - previousDelay)
            addChainSegment(
                from: previousPoint,
                to: targetPosition,
                previousDelay: previousDelay,
                travelDuration: travelDuration,
                accentColor: accentColor,
                coreColor: coreColor
            )

            playChainImpact(
                at: targetPosition,
                targetID: targets.isEmpty ? nil : targets[index].id,
                delay: impactDelay,
                onImpact: onImpact,
                onComplete: index == targetPositions.count - 1 ? onComplete : nil
            )

            travelActions.append(Self.chainTravelAction(
                to: targetPosition,
                duration: travelDuration
            ))
            previousPoint = targetPosition
            previousDelay = impactDelay
        }

        travelActions.append(.removeFromParent())
        charge.run(.sequence(travelActions))
        return targets.isEmpty ? 0 : impactDelays.last ?? 0
    }

    private static func chainTravelAction(
        to targetPosition: CGPoint,
        duration: TimeInterval
    ) -> SKAction {
        let clampedDuration = max(0, duration)
        let pulseDuration = min(0.025, clampedDuration / 2)
        return .group([
            .move(to: targetPosition, duration: clampedDuration),
            .sequence([
                .wait(forDuration: max(0, clampedDuration - pulseDuration * 2)),
                .scale(to: 1.25, duration: pulseDuration),
                .scale(to: 1, duration: pulseDuration)
            ])
        ])
    }

    private func randomChainFallbackTarget(
        from origin: CGPoint,
        configuration: StartingWeaponConfiguration
    ) -> CGPoint {
        let range = max(1, configuration.chainLightningInitialRange)
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        let distance = CGFloat.random(in: (range * 0.55)...range)
        let rawPosition = CGPoint(
            x: origin.x + cos(angle) * distance,
            y: origin.y + sin(angle) * distance
        )
        let playableRect = currentPlayableRect.insetBy(dx: 8, dy: 8)

        guard playableRect.width > 0, playableRect.height > 0 else {
            return rawPosition
        }

        return CGPoint(
            x: min(playableRect.maxX, max(playableRect.minX, rawPosition.x)),
            y: min(playableRect.maxY, max(playableRect.minY, rawPosition.y))
        )
    }

    private func addChainSegment(
        from start: CGPoint,
        to end: CGPoint,
        previousDelay: TimeInterval,
        travelDuration: TimeInterval,
        accentColor: SKColor,
        coreColor: SKColor
    ) {
        let path = Self.chainSegmentPath(from: start, to: end)
        let segment = SKShapeNode(path: path)
        segment.strokeColor = accentColor.withAlphaComponent(0.8)
        segment.lineWidth = 2.8
        segment.glowWidth = theme.kind == .darkTacticalRadar ? 1.1 : 0
        segment.zPosition = 18
        segment.alpha = 0
        addWeaponEffectNode(segment)

        let core = SKShapeNode(path: path)
        core.strokeColor = coreColor.withAlphaComponent(0.88)
        core.lineWidth = 0.8
        core.glowWidth = 0
        core.zPosition = 0.1
        segment.addChild(core)

        segment.run(.sequence([
            .wait(forDuration: previousDelay),
            .fadeAlpha(to: 1, duration: min(0.04, travelDuration * 0.4)),
            .wait(forDuration: max(0, travelDuration * 0.35)),
            .fadeOut(withDuration: max(0.06, travelDuration * 0.35)),
            .removeFromParent()
        ]))
    }

    private func playChainChargeRing(at position: CGPoint, accentColor: SKColor) {
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.position = position
        ring.strokeColor = accentColor.withAlphaComponent(0.52)
        ring.fillColor = accentColor.withAlphaComponent(0.05)
        ring.lineWidth = 1.1
        ring.glowWidth = 1
        ring.zPosition = 19
        ring.setScale(0.35)
        addWeaponEffectNode(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 1.3, duration: 0.16),
                .fadeOut(withDuration: 0.16)
            ]),
            .removeFromParent()
        ]))
    }

    private func playChainImpact(
        at position: CGPoint,
        targetID: Int?,
        delay: TimeInterval,
        onImpact: ((Set<Int>) -> Void)?,
        onComplete: (() -> Void)?
    ) {
        let accentColor = theme.weaponColor(for: .chainLightning)
        let coreColor = theme.playerColor
        let ring = SKShapeNode(circleOfRadius: 16)
        ring.position = position
        ring.strokeColor = accentColor.withAlphaComponent(0.7)
        ring.fillColor = accentColor.withAlphaComponent(0.09)
        ring.lineWidth = 1.4
        ring.glowWidth = 1.25
        ring.zPosition = 19
        ring.alpha = 0
        ring.setScale(0.35)
        addWeaponEffectNode(ring)

        let core = SKShapeNode(path: Self.chainSparkPath(radius: 10))
        core.position = position
        core.strokeColor = coreColor.withAlphaComponent(0.72)
        core.lineWidth = 1.1
        core.glowWidth = 0.7
        core.zPosition = 20
        core.alpha = 0
        addWeaponEffectNode(core)

        ring.run(Self.chainImpactAction(
            targetID: targetID,
            delay: delay,
            onImpact: onImpact,
            onComplete: onComplete
        ))
        playImpactResidue(
            at: position,
            color: accentColor,
            coreColor: coreColor,
            radius: 15,
            delay: delay
        )
        core.run(.sequence([
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

    private static func chainImpactAction(
        targetID: Int?,
        delay: TimeInterval,
        onImpact: ((Set<Int>) -> Void)?,
        onComplete: (() -> Void)?
    ) -> SKAction {
        .sequence([
            .wait(forDuration: max(0, delay)),
            .run {
                if let targetID {
                    onImpact?([targetID])
                }
                onComplete?()
            },
            .group([
                .fadeAlpha(to: 1, duration: 0.02),
                .scale(to: 1.2, duration: 0.1)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ])
    }

    private static func chainSegmentPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let offset = min(9, length * 0.12)
        let normal = CGPoint(x: -dy / length * offset, y: dx / length * offset)
        for (index, bend) in [CGFloat(0.65), -0.85, 1, -0.55].enumerated() {
            let progress = CGFloat(index + 1) / 5
            path.addLine(to: CGPoint(
                x: start.x + dx * progress + normal.x * bend,
                y: start.y + dy * progress + normal.y * bend
            ))
        }
        path.addLine(to: end)
        return path
    }

    private static func chainSparkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius, y: 0))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.move(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.move(to: CGPoint(x: -radius * 0.58, y: -radius * 0.58))
        path.addLine(to: CGPoint(x: radius * 0.58, y: radius * 0.58))
        path.move(to: CGPoint(x: -radius * 0.58, y: radius * 0.58))
        path.addLine(to: CGPoint(x: radius * 0.58, y: -radius * 0.58))
        return path
    }
}
