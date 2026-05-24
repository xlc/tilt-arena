import SpriteKit

extension ArenaScene {
    func playChainLightningEffect(
        from origin: CGPoint,
        through targets: [WeaponImpactTarget],
        accentColor: SKColor,
        coreColor: SKColor,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        guard !targets.isEmpty else {
            return
        }

        let targetPositions = targets.map(\.position)
        let impactDelays = weaponEffectTiming.chainImpactDelays(origin: origin, targets: targetPositions)
        let charge = SKShapeNode(circleOfRadius: 4.5)
        charge.position = origin
        charge.fillColor = accentColor.withAlphaComponent(0.95)
        charge.strokeColor = coreColor.withAlphaComponent(0.95)
        charge.lineWidth = 0.8
        charge.glowWidth = 5
        charge.zPosition = 20
        addChild(charge)

        var previousPoint = origin
        var previousDelay: TimeInterval = 0
        var travelActions: [SKAction] = []

        for (index, target) in targets.enumerated() {
            let impactDelay = impactDelays[index]
            let travelDuration = max(0.04, impactDelay - previousDelay)
            let segment = SKShapeNode(path: Self.chainSegmentPath(from: previousPoint, to: target.position))
            segment.strokeColor = accentColor.withAlphaComponent(0.82)
            segment.lineWidth = 2
            segment.glowWidth = 5
            segment.zPosition = 18
            segment.alpha = 0
            addChild(segment)

            let core = SKShapeNode(path: Self.chainSegmentPath(from: previousPoint, to: target.position))
            core.strokeColor = coreColor.withAlphaComponent(0.9)
            core.lineWidth = 0.8
            core.glowWidth = 1
            segment.addChild(core)

            segment.run(.sequence([
                .wait(forDuration: previousDelay),
                .fadeAlpha(to: 1, duration: min(0.04, travelDuration * 0.4)),
                .wait(forDuration: max(0, travelDuration * 0.35)),
                .fadeOut(withDuration: max(0.06, travelDuration * 0.35)),
                .removeFromParent()
            ]))

            playChainImpact(
                target: target,
                delay: impactDelay,
                accentColor: accentColor,
                coreColor: coreColor,
                onImpact: onImpact
            )

            travelActions.append(.move(to: target.position, duration: travelDuration))
            travelActions.append(.scale(to: 1.25, duration: 0.025))
            travelActions.append(.scale(to: 1, duration: 0.025))
            previousPoint = target.position
            previousDelay = impactDelay
        }

        travelActions.append(.removeFromParent())
        charge.run(.sequence(travelActions))
    }

    private func playChainImpact(
        target: WeaponImpactTarget,
        delay: TimeInterval,
        accentColor: SKColor,
        coreColor: SKColor,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        let ring = SKShapeNode(circleOfRadius: 14)
        ring.position = target.position
        ring.strokeColor = accentColor.withAlphaComponent(0.95)
        ring.fillColor = accentColor.withAlphaComponent(0.1)
        ring.lineWidth = 1.5
        ring.glowWidth = 5
        ring.zPosition = 19
        ring.alpha = 0
        ring.setScale(0.35)
        addChild(ring)

        let core = SKShapeNode(path: Self.chainSparkPath(radius: 9))
        core.position = target.position
        core.strokeColor = coreColor.withAlphaComponent(0.95)
        core.lineWidth = 1.1
        core.glowWidth = 3
        core.zPosition = 20
        core.alpha = 0
        addChild(core)

        ring.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .run {
                onImpact([target.id])
            },
            .group([
                .fadeAlpha(to: 1, duration: 0.02),
                .scale(to: 1.2, duration: 0.1)
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
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

    private static func chainSegmentPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let offset = min(12, length * 0.18)
        let normal = CGPoint(x: -dy / length * offset, y: dx / length * offset)
        path.addLine(to: CGPoint(x: midpoint.x + normal.x, y: midpoint.y + normal.y))
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
