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

        for (index, position) in positions.prefix(32).enumerated() {
            playEnemyClearBurst(
                at: position,
                color: color,
                coreColor: coreColor,
                radius: 9 * comboBoost,
                delay: min(0.06, TimeInterval(index) * 0.006)
            )
        }
    }

    func playImpactResidue(
        at position: CGPoint,
        color: SKColor,
        coreColor: SKColor,
        radius: CGFloat,
        delay: TimeInterval
    ) {
        playImpactResidueSplash(at: position, color: color, coreColor: coreColor, radius: radius, delay: delay)

        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 9
            let shard = SKShapeNode(path: Self.motionPolishRadialLinePath(
                innerRadius: radius * 0.32,
                outerRadius: radius * 1.05,
                angle: angle
            ))
            shard.position = position
            shard.strokeColor = color.withAlphaComponent(0.46)
            shard.lineWidth = 0.85
            shard.lineCap = .round
            shard.glowWidth = 0.5
            shard.zPosition = 20
            shard.alpha = 0
            addWeaponEffectNode(shard)
            shard.run(Self.motionPolishShardAction(delay: delay + TimeInterval(index) * 0.004))
        }
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
}
