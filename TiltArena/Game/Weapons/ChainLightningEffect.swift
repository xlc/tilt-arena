import SpriteKit

extension ArenaScene {
    func playChainLightningEffect(
        from origin: CGPoint,
        through targets: [CGPoint],
        accentColor: SKColor,
        coreColor: SKColor
    ) {
        guard !targets.isEmpty else {
            return
        }

        let path = CGMutablePath()
        path.move(to: origin)
        targets.forEach { path.addLine(to: $0) }

        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = accentColor.withAlphaComponent(0.95)
        bolt.lineWidth = 2
        bolt.glowWidth = 5
        bolt.zPosition = 18
        addChild(bolt)

        let core = SKShapeNode(path: path)
        core.strokeColor = coreColor.withAlphaComponent(0.95)
        core.lineWidth = 0.8
        core.glowWidth = 1
        bolt.addChild(core)

        let fade = SKAction.group([
            .fadeOut(withDuration: 0.14),
            .scale(to: 0.98, duration: 0.14)
        ])
        bolt.run(.sequence([fade, .removeFromParent()]))
    }
}
