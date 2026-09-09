import SpriteKit

extension ArenaScene {
    func waveExpansionAction(duration: TimeInterval, exponent: Double) -> SKAction {
        return .customAction(withDuration: duration) { node, elapsed in
            node.setScale(WeaponWaveExpansion.progress(elapsed: TimeInterval(elapsed), duration: duration, exponent: exponent))
        }
    }
    func playTravelingBolt(
        from origin: CGPoint,
        to target: WeaponImpactTarget,
        delay: TimeInterval = 0,
        duration: TimeInterval,
        color: SKColor,
        coreColor: SKColor,
        impactRadius: CGFloat
    ) {
        let delay = WeaponRuntimeSafetyLimits.duration(delay)
        let duration = WeaponRuntimeSafetyLimits.duration(duration)
        let trail = SKShapeNode(path: Self.linePath(from: origin, to: target.position))
        trail.strokeColor = color.withAlphaComponent(0.22)
        trail.lineWidth = 0.9
        trail.glowWidth = 0.65
        trail.zPosition = 18
        trail.alpha = 0
        addWeaponEffectNode(trail)

        let projectile = SKShapeNode(circleOfRadius: 4)
        projectile.position = origin
        projectile.fillColor = color.withAlphaComponent(0.78)
        projectile.strokeColor = coreColor.withAlphaComponent(0.72)
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

        playImpactBurst(
            at: target,
            delay: delay + duration,
            color: color,
            radius: impactRadius
        )
    }

    func playImpactBurst(
        at target: WeaponImpactTarget,
        delay: TimeInterval,
        color: SKColor,
        radius: CGFloat
    ) {
        let delay = WeaponRuntimeSafetyLimits.duration(delay)
        let radius = WeaponRuntimeSafetyLimits.distance(radius)
        let ring = makeEffectRing(
            radius: radius,
            strokeColor: color.withAlphaComponent(0.95),
            fillColor: color.withAlphaComponent(0.12),
            lineWidth: 1.4,
            glowWidth: 1
        )
        ring.position = target.position
        ring.alpha = 0
        ring.setScale(0.35)
        addWeaponEffectNode(ring)

        let spark = SKShapeNode(path: Self.crossPath(radius: radius * 0.7))
        spark.position = target.position
        spark.strokeColor = color.withAlphaComponent(0.7)
        spark.lineWidth = 1
        spark.glowWidth = 0.8
        spark.zPosition = 20
        spark.alpha = 0
        addWeaponEffectNode(spark)

        let impact = SKAction.sequence([
            .wait(forDuration: max(0, delay)),
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

    func runImpactBatch(
        _ targetIDs: Set<Int>,
        delay: TimeInterval,
        onImpact: @escaping (Set<Int>) -> Void
    ) {
        guard !targetIDs.isEmpty else {
            return
        }

        let node = SKNode()
        node.zPosition = 18
        addWeaponEffectNode(node)
        node.run(.sequence([
            .wait(forDuration: WeaponRuntimeSafetyLimits.duration(delay)),
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
        let ring = SKShapeNode(circleOfRadius: WeaponRuntimeSafetyLimits.distance(radius))
        ring.strokeColor = strokeColor
        ring.fillColor = fillColor
        ring.lineWidth = lineWidth
        ring.glowWidth = glowWidth
        ring.zPosition = 18
        return ring
    }

    func makeWeaponEffectSprite(kind: WeaponKind, size: CGFloat, zPosition: CGFloat = 17) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: WeaponSpriteSheet.texture(for: kind))
        // The traveling geometry shows coverage; the glyph only marks the activation.
        let clampedSize = min(64, max(1, WeaponRuntimeSafetyLimits.distance(size)))
        sprite.size = CGSize(width: clampedSize, height: clampedSize)
        sprite.color = theme.weaponColor(for: kind)
        sprite.colorBlendFactor = 1
        sprite.blendMode = .alpha
        sprite.zPosition = zPosition
        return sprite
    }

    func playWeaponEffectSprite(
        _ kind: WeaponKind,
        at position: CGPoint,
        size: CGFloat,
        delay: TimeInterval = 0,
        alpha: CGFloat = 0.62
    ) {
        let delay = WeaponRuntimeSafetyLimits.duration(delay)
        let sprite = makeWeaponEffectSprite(kind: kind, size: size)
        sprite.position = position
        sprite.alpha = 0
        sprite.setScale(0.62)
        addWeaponEffectNode(sprite)
        sprite.run(.sequence([
            .wait(forDuration: max(0, delay)),
            .group([
                .fadeAlpha(to: min(1, max(0, alpha)), duration: 0.04),
                .scale(to: 1.05, duration: 0.12)
            ]),
            .wait(forDuration: 0.06),
            .group([
                .fadeOut(withDuration: 0.16),
                .scale(to: 1.18, duration: 0.16)
            ]),
            .removeFromParent()
        ]))
    }

    static func linePath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    static func radialLinePath(innerRadius: CGFloat, outerRadius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cos(angle) * innerRadius, y: sin(angle) * innerRadius))
        path.addLine(to: CGPoint(x: cos(angle) * outerRadius, y: sin(angle) * outerRadius))
        return path
    }

    static func rotation(for direction: CGVector) -> CGFloat {
        let resolvedDirection = direction.normalized(or: CGVector(dx: 0, dy: 1))
        return atan2(resolvedDirection.dy, resolvedDirection.dx)
    }

    static func powerWaveFanPath(range: CGFloat, fanAngleRadians: CGFloat) -> CGPath {
        let radius = WeaponRuntimeSafetyLimits.distance(range)
        let halfAngle = fanAngleRadians.isFinite ? min(.pi, max(0, fanAngleRadians / 2)) : 0
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: cos(-halfAngle) * radius, y: sin(-halfAngle) * radius))
        path.addArc(center: .zero, radius: radius, startAngle: -halfAngle, endAngle: halfAngle, clockwise: false)
        path.closeSubpath()
        return path
    }

    static func powerWaveTravel(
        from position: CGPoint,
        direction: CGVector,
        range: CGFloat,
        distance: CGFloat,
        expansionDuration: TimeInterval
    ) -> (endPosition: CGPoint, duration: TimeInterval) {
        let duration = WeaponRuntimeSafetyLimits.duration(expansionDuration)
        let distance = WeaponRuntimeSafetyLimits.distance(distance)
        let travelSpeed = range / CGFloat(max(0.001, duration))
        let travelDuration = WeaponRuntimeSafetyLimits.duration(
            TimeInterval(distance / max(1, travelSpeed))
        )
        let direction = direction.normalized(or: CGVector(dx: 0, dy: 1))
        return (
            endPosition: CGPoint(
                x: position.x + direction.dx * distance,
                y: position.y + direction.dy * distance
            ),
            duration: travelDuration
        )
    }

    static func crossPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius, y: 0))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.move(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: 0, y: radius))
        return path
    }
}
