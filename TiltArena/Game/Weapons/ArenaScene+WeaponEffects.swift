import SpriteKit

extension ArenaScene {
    func playShockwaveEffect(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: weaponResolver.configuration.shockwaveRadius)
        ring.position = position
        ring.strokeColor = theme.playerAccentColor.withAlphaComponent(0.9)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 5
        ring.zPosition = 18
        ring.setScale(0.2)
        addChild(ring)
        let expand = SKAction.group([
            .scale(to: 1.0, duration: 0.16),
            .fadeOut(withDuration: 0.16)
        ])
        ring.run(.sequence([expand, .removeFromParent()]))
    }

    func playNovaBombEffect() {
        let playableRect = movementController.configuration.playableRect(in: size)

        guard playableRect.width > 0, playableRect.height > 0 else {
            return
        }

        let center = CGPoint(x: playableRect.midX, y: playableRect.midY)
        let radius = hypot(playableRect.width, playableRect.height) / 2
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = center
        ring.strokeColor = theme.pickupAmber.withAlphaComponent(0.85)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 6
        ring.zPosition = 18
        ring.setScale(0.05)
        addChild(ring)

        let clearPulse = SKAction.group([
            .scale(to: 1.0, duration: 0.22),
            .fadeOut(withDuration: 0.22)
        ])
        ring.run(.sequence([clearPulse, .removeFromParent()]))
    }

    func playSeekerSwarmEffect(from origin: CGPoint, to targets: [CGPoint]) {
        for target in targets {
            let path = CGMutablePath()
            path.move(to: origin)
            path.addLine(to: target)

            let streak = SKShapeNode(path: path)
            streak.strokeColor = theme.pickupViolet.withAlphaComponent(0.85)
            streak.lineWidth = 1.5
            streak.glowWidth = 3
            streak.zPosition = 18
            addChild(streak)

            let fade = SKAction.group([
                .fadeOut(withDuration: 0.12),
                .scale(to: 0.9, duration: 0.12)
            ])
            streak.run(.sequence([fade, .removeFromParent()]))
        }
    }

    func playFreezeBurstEffect(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: weaponResolver.configuration.freezeBurstRadius)
        ring.position = position
        ring.strokeColor = theme.pickupBlue.withAlphaComponent(0.85)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.glowWidth = 5
        ring.zPosition = 18
        ring.setScale(0.18)
        addChild(ring)

        let expand = SKAction.group([
            .scale(to: 1.0, duration: 0.18),
            .fadeOut(withDuration: 0.18)
        ])
        ring.run(.sequence([expand, .removeFromParent()]))
    }

    func playGravityWellEffect(at position: CGPoint) {
        gravityWellEffectNode?.removeFromParent()
        let container = SKNode()
        container.position = position
        container.zPosition = 18
        addChild(container)
        gravityWellEffectNode = container
        let ring = SKShapeNode(circleOfRadius: weaponResolver.configuration.gravityWellRadius)
        ring.strokeColor = theme.pickupViolet.withAlphaComponent(0.7)
        ring.fillColor = theme.pickupBlue.withAlphaComponent(0.08)
        ring.lineWidth = 1.8
        ring.glowWidth = 5
        container.addChild(ring)
        let duration = max(0.12, weaponResolver.configuration.gravityWellPullDuration)
        let pulse = SKAction.group([
            .scale(to: 0.25, duration: duration),
            .fadeOut(withDuration: duration)
        ])
        container.run(.sequence([pulse, .removeFromParent()]))
    }

    func playWarpDashEffect(from startPosition: CGPoint, to endPosition: CGPoint) {
        let path = CGMutablePath()
        path.move(to: startPosition)
        path.addLine(to: endPosition)

        let streak = SKShapeNode(path: path)
        streak.strokeColor = theme.playerAccentColor.withAlphaComponent(0.9)
        streak.lineWidth = 2
        streak.glowWidth = 5
        streak.zPosition = 18
        addChild(streak)

        let endpoint = SKShapeNode(circleOfRadius: movementController.configuration.visualRadius * 1.4)
        endpoint.position = endPosition
        endpoint.strokeColor = theme.pickupViolet.withAlphaComponent(0.85)
        endpoint.fillColor = .clear
        endpoint.lineWidth = 1.4
        endpoint.glowWidth = 4
        endpoint.zPosition = 18
        endpoint.setScale(0.35)
        addChild(endpoint)

        let fade = SKAction.group([
            .fadeOut(withDuration: 0.14),
            .scale(to: 0.96, duration: 0.14)
        ])
        streak.run(.sequence([fade, .removeFromParent()]))

        let pulse = SKAction.group([
            .scale(to: 1.0, duration: 0.14),
            .fadeOut(withDuration: 0.14)
        ])
        endpoint.run(.sequence([pulse, .removeFromParent()]))
    }
}
