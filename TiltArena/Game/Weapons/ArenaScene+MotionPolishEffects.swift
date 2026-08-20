import SpriteKit

extension ArenaScene {
    func playPickupCollectionPop(for pickup: WeaponPickup) {
        let color = weaponEffectColor(for: pickup.kind)
        let ring = makeEffectRing(
            radius: pickup.radius * 1.45,
            strokeColor: color.withAlphaComponent(0.72),
            fillColor: color.withAlphaComponent(0.1),
            lineWidth: 1.4,
            glowWidth: 1.25
        )
        ring.position = pickup.position
        ring.setScale(0.58)
        addWeaponEffectNode(ring)

        let core = pickupPopCoreNode(for: pickup, color: color)
        addWeaponEffectNode(core)

        ring.run(.sequence([
            .group([.scale(to: 1.72, duration: 0.2), .fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
        core.run(.sequence([
            .group([.scale(to: 1.18, duration: 0.08), .rotate(byAngle: .pi / 10, duration: 0.08)]),
            .fadeOut(withDuration: 0.09),
            .removeFromParent()
        ]))

        playImpactResidue(
            at: pickup.position,
            color: color,
            coreColor: theme.playerColor,
            radius: pickup.radius * 1.18,
            delay: 0.02
        )
    }

    func playEnemyClearBursts(
        at positions: [CGPoint],
        weaponKind: WeaponKind?,
        comboMultiplier: Int
    ) {
        let color = weaponEffectColor(for: weaponKind)
        let coreColor = theme.playerColor
        let comboBoost = min(1.25, 1 + CGFloat(max(0, comboMultiplier - 1)) * 0.05)

        for (index, position) in WeaponImpactPlan.evenlySampled(positions).enumerated() {
            playEnemyClearBurst(
                at: position,
                color: color,
                coreColor: coreColor,
                radius: 9 * comboBoost,
                delay: min(0.06, TimeInterval(index) * 0.006)
            )
        }
    }

    func playChargedWeaponActivationEffect(
        kind: WeaponKind,
        at position: CGPoint,
        chargeTier: WeaponPickupChargeTier
    ) {
        guard chargeTier > .base else {
            return
        }

        let color = weaponEffectColor(for: kind)
        let level = CGFloat(chargeTier.rawValue)
        let baseRadius = max(22, movementController.configuration.visualRadius * (2.2 + level * 0.55))
        let ring = makeEffectRing(
            radius: baseRadius,
            strokeColor: color.withAlphaComponent(0.86),
            fillColor: color.withAlphaComponent(0.1 + level * 0.02),
            lineWidth: 1.4 + level * 0.35,
            glowWidth: 1.1 + level * 0.35
        )
        ring.position = position
        ring.zPosition = 21
        ring.alpha = 0
        ring.setScale(0.34)
        addWeaponEffectNode(ring)
        ring.run(Self.chargedActivationRingAction(scale: chargeTier == .overcharged ? 1.38 : 1.22))

        let sprite = makeWeaponEffectSprite(kind: kind, size: baseRadius * 1.18, zPosition: 22)
        sprite.position = position
        sprite.alpha = 0
        sprite.setScale(0.58)
        addWeaponEffectNode(sprite)
        sprite.run(Self.chargedActivationSpriteAction)

        playChargedActivationTicks(
            at: position,
            radius: baseRadius,
            color: color,
            chargeTier: chargeTier
        )

        guard chargeTier == .overcharged else {
            return
        }

        let overchargeRing = makeEffectRing(
            radius: baseRadius * 1.34,
            strokeColor: theme.playerColor.withAlphaComponent(0.66),
            fillColor: .clear,
            lineWidth: 1,
            glowWidth: 1.25
        )
        overchargeRing.position = position
        overchargeRing.zPosition = 20
        overchargeRing.alpha = 0
        overchargeRing.setScale(0.28)
        addWeaponEffectNode(overchargeRing)
        overchargeRing.run(Self.chargedActivationRingAction(scale: 1.48))
    }

    func playWeaponComboEffect(_ event: WeaponComboEvent, at positions: [CGPoint]) {
        let isCascade = event.kind == .cascade
        let cappedPositions = Array(positions.prefix(isCascade ? 12 : 8))
        let center = weaponComboEffectCenter(for: positions)
        let color = theme.weaponComboColor(for: event.currentFamily)
        let secondaryColor = isCascade
            ? theme.playerColor
            : theme.weaponComboColor(for: event.previousFamily)
        let radius: CGFloat = isCascade ? 31 : 24

        playWeaponComboConnectors(
            from: cappedPositions,
            to: center,
            color: secondaryColor,
            isCascade: isCascade
        )
        playWeaponComboCenterBurst(
            at: center,
            radius: radius,
            color: color,
            secondaryColor: secondaryColor,
            isCascade: isCascade
        )
        playWeaponComboPositionPulses(
            at: cappedPositions,
            color: color,
            secondaryColor: secondaryColor,
            isCascade: isCascade
        )
    }

    func playImpactResidue(
        at position: CGPoint,
        color: SKColor,
        coreColor: SKColor,
        radius: CGFloat,
        delay: TimeInterval
    ) {
        playImpactResidueSplash(at: position, color: color, coreColor: coreColor, radius: radius, delay: delay)

        let shards = SKShapeNode(path: Self.motionPolishShardBurstPath(
            innerRadius: radius * 0.32,
            outerRadius: radius * 1.05
        ))
        shards.position = position
        shards.strokeColor = color.withAlphaComponent(0.46)
        shards.lineWidth = 0.85
        shards.lineCap = .round
        shards.glowWidth = 0.5
        shards.zPosition = 20
        shards.alpha = 0
        addWeaponEffectNode(shards)
        shards.run(Self.motionPolishShardAction(delay: delay + 0.01))
    }
}

private extension ArenaScene {
    func pickupPopCoreNode(for pickup: WeaponPickup, color: SKColor) -> SKShapeNode {
        let core = SKShapeNode(path: Self.pickupPopStarPath(radius: pickup.radius * 0.86))
        core.position = pickup.position
        core.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        core.fillColor = color.withAlphaComponent(0.2)
        core.lineWidth = 1.2
        core.lineJoin = .round
        core.glowWidth = 0.8
        core.zPosition = 20
        return core
    }

    func playEnemyClearBurst(
        at position: CGPoint,
        color: SKColor,
        coreColor: SKColor,
        radius: CGFloat,
        delay: TimeInterval
    ) {
        let flash = makeEffectRing(
            radius: radius,
            strokeColor: coreColor.withAlphaComponent(0.66),
            fillColor: color.withAlphaComponent(0.09),
            lineWidth: 1.2,
            glowWidth: 0.8
        )
        flash.position = position
        flash.alpha = 0
        flash.setScale(0.32)
        addWeaponEffectNode(flash)

        let dot = enemyClearDot(at: position, color: color, coreColor: coreColor, radius: radius)
        addWeaponEffectNode(dot)
        flash.run(Self.enemyClearFlashAction(delay: delay))
        dot.run(Self.enemyClearDotAction(delay: delay))
        playImpactResidue(at: position, color: color, coreColor: coreColor, radius: radius * 0.95, delay: delay + 0.01)
    }

    func playChargedActivationTicks(
        at position: CGPoint,
        radius: CGFloat,
        color: SKColor,
        chargeTier: WeaponPickupChargeTier
    ) {
        let tickCount = chargeTier == .overcharged ? 12 : 8
        for index in 0..<tickCount {
            let angle = CGFloat(index) * (2 * .pi / CGFloat(tickCount))
            let tick = SKShapeNode(path: Self.motionPolishRadialLinePath(
                innerRadius: radius * 0.74,
                outerRadius: radius * (chargeTier == .overcharged ? 1.34 : 1.14),
                angle: angle
            ))
            tick.position = position
            tick.strokeColor = chargeTier == .overcharged && index.isMultiple(of: 2)
                ? theme.playerColor.withAlphaComponent(0.74)
                : color.withAlphaComponent(chargeTier == .overcharged ? 0.78 : 0.58)
            tick.lineWidth = chargeTier == .overcharged ? 1.2 : 0.9
            tick.lineCap = .round
            tick.glowWidth = chargeTier == .overcharged ? 0.85 : 0.55
            tick.zPosition = 22
            tick.alpha = 0
            addWeaponEffectNode(tick)
            tick.run(Self.chargedActivationTickAction(delay: TimeInterval(index) * 0.004))
        }
    }

    func weaponComboEffectCenter(for positions: [CGPoint]) -> CGPoint {
        guard !positions.isEmpty else {
            return movementController.state.position
        }

        let total = positions.reduce(CGPoint.zero) { partialResult, position in
            CGPoint(x: partialResult.x + position.x, y: partialResult.y + position.y)
        }
        let count = CGFloat(positions.count)
        return CGPoint(x: total.x / count, y: total.y / count)
    }

    func playWeaponComboConnectors(
        from positions: [CGPoint],
        to center: CGPoint,
        color: SKColor,
        isCascade: Bool
    ) {
        for (index, position) in positions.prefix(isCascade ? 10 : 6).enumerated() {
            guard hypot(position.x - center.x, position.y - center.y) > 2 else {
                continue
            }

            let connector = SKShapeNode(path: Self.motionPolishLinePath(from: position, to: center))
            connector.strokeColor = color.withAlphaComponent(isCascade ? 0.56 : 0.38)
            connector.lineWidth = isCascade ? 1.2 : 0.9
            connector.lineCap = .round
            connector.glowWidth = isCascade ? 0.85 : 0.5
            connector.zPosition = 20
            connector.alpha = 0
            addWeaponEffectNode(connector)
            connector.run(Self.weaponComboConnectorAction(delay: TimeInterval(index) * 0.005))
        }
    }

    func playWeaponComboCenterBurst(
        at position: CGPoint,
        radius: CGFloat,
        color: SKColor,
        secondaryColor: SKColor,
        isCascade: Bool
    ) {
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: color.withAlphaComponent(isCascade ? 0.95 : 0.8),
            fillColor: color.withAlphaComponent(isCascade ? 0.16 : 0.1),
            lineWidth: isCascade ? 2.1 : 1.5,
            glowWidth: isCascade ? 1.8 : 1.2
        )
        ring.position = position
        ring.zPosition = 23
        ring.alpha = 0
        ring.setScale(0.3)
        addWeaponEffectNode(ring)
        ring.run(Self.weaponComboRingAction(scale: isCascade ? 1.34 : 1.2))

        let burst = SKShapeNode(path: Self.weaponComboBurstPath(radius: radius * 0.68, spokes: isCascade ? 10 : 8))
        burst.position = position
        burst.strokeColor = secondaryColor.withAlphaComponent(isCascade ? 0.82 : 0.66)
        burst.lineWidth = isCascade ? 1.4 : 1.1
        burst.lineCap = .round
        burst.glowWidth = isCascade ? 1 : 0.65
        burst.zPosition = 24
        burst.alpha = 0
        addWeaponEffectNode(burst)
        burst.run(Self.weaponComboBurstAction)

        guard isCascade else {
            return
        }

        let outerRing = makeEffectRing(
            radius: radius * 1.36,
            strokeColor: secondaryColor.withAlphaComponent(0.56),
            fillColor: .clear,
            lineWidth: 1,
            glowWidth: 1.2
        )
        outerRing.position = position
        outerRing.zPosition = 22
        outerRing.alpha = 0
        outerRing.setScale(0.25)
        addWeaponEffectNode(outerRing)
        outerRing.run(Self.weaponComboRingAction(scale: 1.46))
    }

    func playWeaponComboPositionPulses(
        at positions: [CGPoint],
        color: SKColor,
        secondaryColor: SKColor,
        isCascade: Bool
    ) {
        for (index, position) in positions.prefix(isCascade ? 8 : 5).enumerated() {
            let pulse = makeEffectRing(
                radius: isCascade ? 12 : 9,
                strokeColor: color.withAlphaComponent(isCascade ? 0.7 : 0.54),
                fillColor: secondaryColor.withAlphaComponent(isCascade ? 0.09 : 0.05),
                lineWidth: isCascade ? 1.1 : 0.85,
                glowWidth: isCascade ? 0.8 : 0.5
            )
            pulse.position = position
            pulse.zPosition = 21
            pulse.alpha = 0
            pulse.setScale(0.35)
            addWeaponEffectNode(pulse)
            pulse.run(Self.weaponComboPulseAction(delay: TimeInterval(index) * 0.006))
        }
    }

    func enemyClearDot(at position: CGPoint, color: SKColor, coreColor: SKColor, radius: CGFloat) -> SKShapeNode {
        let dot = SKShapeNode(circleOfRadius: max(2.2, radius * 0.22))
        dot.position = position
        dot.fillColor = coreColor.withAlphaComponent(0.72)
        dot.strokeColor = color.withAlphaComponent(0.64)
        dot.lineWidth = 0.8
        dot.glowWidth = 0.55
        dot.zPosition = 20
        dot.alpha = 0
        return dot
    }

    func playImpactResidueSplash(
        at position: CGPoint,
        color: SKColor,
        coreColor: SKColor,
        radius: CGFloat,
        delay: TimeInterval
    ) {
        let splash = makeEffectRing(
            radius: radius * 1.42,
            strokeColor: coreColor.withAlphaComponent(0.34),
            fillColor: color.withAlphaComponent(0.05),
            lineWidth: 0.9,
            glowWidth: 0.65
        )
        splash.position = position
        splash.alpha = 0
        splash.setScale(0.5)
        addWeaponEffectNode(splash)
        splash.run(Self.impactResidueSplashAction(delay: delay))
    }

    func weaponEffectColor(for kind: WeaponKind?) -> SKColor {
        switch kind {
        case .some(.shockwave), .some(.flameTrail), .some(.powerWave), .some(.novaBomb):
            return theme.pickupAmber
        case .some(.seekerSwarm), .some(.gravityWell), .some(.warpDash):
            return theme.pickupViolet
        case .some(.razorShield), .some(.freezeBurst), .some(.chainLightning), .some(.ricochetLance):
            return theme.pickupBlue
        case .none:
            return theme.enemyColor
        }
    }

    static func enemyClearFlashAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: delay),
            .group([.fadeAlpha(to: 1, duration: 0.02), .scale(to: 1.26, duration: 0.11)]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ])
    }

    static func enemyClearDotAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: delay),
            .fadeAlpha(to: 1, duration: 0.02),
            .group([.scale(to: 0.55, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ])
    }

    static func impactResidueSplashAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: max(0, delay)),
            .group([.fadeAlpha(to: 0.72, duration: 0.025), .scale(to: 1.22, duration: 0.16)]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ])
    }

    static func motionPolishShardAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: max(0, delay)),
            .fadeAlpha(to: 0.86, duration: 0.02),
            .group([.scale(to: 1.18, duration: 0.1), .fadeOut(withDuration: 0.1)]),
            .removeFromParent()
        ])
    }

    static func motionPolishRadialLinePath(innerRadius: CGFloat, outerRadius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius))
        path.addLine(to: CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius))
        return path
    }

    static func motionPolishShardBurstPath(innerRadius: CGFloat, outerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 9
            path.move(to: CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius))
            path.addLine(to: CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius))
        }
        return path
    }

    static func motionPolishLinePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    static func pickupPopStarPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 + .pi / 8
            let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.48
            let point = CGPoint(x: cos(angle) * pointRadius, y: sin(angle) * pointRadius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    static var chargedActivationSpriteAction: SKAction {
        .sequence([
            .group([
                .fadeAlpha(to: 0.58, duration: 0.04),
                .scale(to: 1.02, duration: 0.1)
            ]),
            .group([
                .fadeOut(withDuration: 0.12),
                .scale(to: 1.16, duration: 0.12)
            ]),
            .removeFromParent()
        ])
    }

    static func chargedActivationRingAction(scale: CGFloat) -> SKAction {
        .sequence([
            .group([
                .fadeAlpha(to: 1, duration: 0.025),
                .scale(to: scale, duration: 0.16)
            ]),
            .fadeOut(withDuration: 0.11),
            .removeFromParent()
        ])
    }

    static func chargedActivationTickAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: max(0, delay)),
            .fadeAlpha(to: 0.9, duration: 0.02),
            .group([
                .scale(to: 1.2, duration: 0.1),
                .fadeOut(withDuration: 0.11)
            ]),
            .removeFromParent()
        ])
    }

    static func weaponComboConnectorAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: max(0, delay)),
            .fadeAlpha(to: 1, duration: 0.02),
            .fadeOut(withDuration: 0.16),
            .removeFromParent()
        ])
    }

    static func weaponComboRingAction(scale: CGFloat) -> SKAction {
        .sequence([
            .group([
                .fadeAlpha(to: 1, duration: 0.02),
                .scale(to: scale, duration: 0.18)
            ]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ])
    }

    static var weaponComboBurstAction: SKAction {
        .sequence([
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .rotate(byAngle: .pi / 5, duration: 0.13),
                .scale(to: 1.18, duration: 0.13)
            ]),
            .fadeOut(withDuration: 0.1),
            .removeFromParent()
        ])
    }

    static func weaponComboPulseAction(delay: TimeInterval) -> SKAction {
        .sequence([
            .wait(forDuration: max(0, delay)),
            .fadeAlpha(to: 1, duration: 0.02),
            .group([
                .scale(to: 1.22, duration: 0.11),
                .fadeOut(withDuration: 0.12)
            ]),
            .removeFromParent()
        ])
    }

    static func weaponComboBurstPath(radius: CGFloat, spokes: Int) -> CGPath {
        let path = CGMutablePath()
        let spokeCount = max(4, spokes)
        for index in 0..<spokeCount {
            let angle = CGFloat(index) * (2 * .pi / CGFloat(spokeCount))
            path.move(to: CGPoint(x: cos(angle) * radius * 0.24, y: sin(angle) * radius * 0.24))
            path.addLine(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
        }
        return path
    }
}
