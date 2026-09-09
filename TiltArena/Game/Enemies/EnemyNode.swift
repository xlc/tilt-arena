import SpriteKit

@MainActor
final class EnemyNode: SKNode {
    private let dangerHaloNode: SKShapeNode
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let markerNode: SKShapeNode
    private var theme: ArenaTheme
    private var visualSignature: VisualSignature?

    init(enemy: ArenaEnemy, theme: ArenaTheme) {
        dangerHaloNode = SKShapeNode()
        bodyNode = SKShapeNode()
        ringNode = SKShapeNode()
        markerNode = SKShapeNode()
        self.theme = theme
        super.init()

        zPosition = 15
        ringNode.zPosition = 0.1
        bodyNode.zPosition = 0.2
        markerNode.zPosition = 0.3

        dangerHaloNode.fillColor = .clear
        addChild(dangerHaloNode)

        ringNode.fillColor = .clear
        addChild(ringNode)

        addChild(bodyNode)
        addChild(markerNode)

        apply(enemy)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyNode does not support storyboard initialization.")
    }

    func apply(_ enemy: ArenaEnemy) {
        position = enemy.position
        zRotation = EnemyVisualGeometry.travelRotation(for: enemy.behavior)
        let signature = VisualSignature(enemy: enemy)
        guard signature != visualSignature else {
            return
        }

        visualSignature = signature
        applyAppearance(enemy)
    }

    func applyTheme(_ theme: ArenaTheme, enemy: ArenaEnemy) {
        self.theme = theme
        visualSignature = nil
        apply(enemy)
    }
}

private extension EnemyNode {
    struct VisualSignature: Equatable {
        let kind: EnemyKind
        let isFrozen: Bool
        let isThawing: Bool
        let isSplitProtected: Bool
        let radius: CGFloat

        init(enemy: ArenaEnemy) {
            kind = enemy.behavior.kind
            isFrozen = enemy.isFrozen
            isThawing = enemy.isThawing
            isSplitProtected = enemy.isSplitProtected
            radius = enemy.radius
        }
    }
}

private extension EnemyNode {
    func applyAppearance(_ enemy: ArenaEnemy) {
        let kind = enemy.behavior.kind
        dangerHaloNode.path = EnemyVisualGeometry.circlePath(radius: enemy.radius * 1.24)
        bodyNode.path = EnemyVisualGeometry.bodyPath(for: kind, radius: enemy.radius)
        ringNode.path = EnemyVisualGeometry.circlePath(radius: enemy.radius * 1.45)

        if let markerPath = EnemyVisualGeometry.markerPath(
            for: kind,
            radius: enemy.radius,
            isShatterableFrozen: enemy.isShatterableFrozen
        ) {
            markerNode.path = markerPath
            markerNode.isHidden = false
        } else {
            markerNode.path = nil
            markerNode.isHidden = true
        }
        markerNode.fillColor = .clear
        resetStateAnimations()
        applyBaseStyle()
        applyRoleStyle(kind)

        if enemy.isFrozen {
            applyFrozenStyle()
        } else if enemy.isThawing {
            applyThawingStyle()
            startThawAnimation()
        } else if enemy.isSplitProtected {
            applySplitProtectedStyle()
            startSplitProtectedAnimation()
        }
    }

    func applyBaseStyle() {
        // Solid silhouettes carry enemy identity; reserve halos for temporary states.
        dangerHaloNode.isHidden = true
        ringNode.isHidden = true
        dangerHaloNode.glowWidth = 0
        ringNode.glowWidth = 0
        ringNode.strokeColor = theme.enemyColor
        ringNode.lineWidth = 0.8
        bodyNode.fillColor = theme.enemyColor
        bodyNode.strokeColor = theme.enemyColor
        bodyNode.lineWidth = 0.65
        bodyNode.glowWidth = theme.kind == .darkTacticalRadar ? 0.3 : 0
        markerNode.strokeColor = theme.backgroundColor.withAlphaComponent(0.85)
        markerNode.lineWidth = 0.85
        markerNode.lineCap = .round
        markerNode.lineJoin = .round
        markerNode.glowWidth = 0
    }

    func applyRoleStyle(_ kind: EnemyKind) {
        switch kind {
        case .mine:
            ringNode.isHidden = false
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.7)
        case .splitter:
            ringNode.isHidden = false
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.6)
        case .chaser, .formation, .arrowRush, .hunter, .paddleBar, .paddlePuck, .splitterChild:
            break
        }
    }

    func applyFrozenStyle() {
        ringNode.isHidden = false
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.72)
        ringNode.lineWidth = 1.8
        ringNode.glowWidth = 0.9
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.55)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        bodyNode.lineWidth = 1.7
        bodyNode.glowWidth = 1
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
    }

    func applyThawingStyle() {
        dangerHaloNode.isHidden = false
        ringNode.isHidden = false
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.42)
        dangerHaloNode.lineWidth = 1.7
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.44)
        ringNode.lineWidth = 1.4
        ringNode.glowWidth = 0.65
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.28)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.58)
        bodyNode.lineWidth = 1.5
        bodyNode.glowWidth = 0.7
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.62)
    }

    func applySplitProtectedStyle() {
        dangerHaloNode.isHidden = false
        ringNode.isHidden = false
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.36)
        dangerHaloNode.lineWidth = 1.4
        ringNode.strokeColor = theme.playerColor.withAlphaComponent(0.54)
        ringNode.lineWidth = 1.5
        ringNode.glowWidth = 0.6
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.34)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.54)
        bodyNode.lineWidth = 1.3
        bodyNode.glowWidth = 0.5
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.58)
    }

    func resetStateAnimations() {
        dangerHaloNode.removeAction(forKey: "enemy.thaw.halo")
        bodyNode.removeAction(forKey: "enemy.thaw.body")
        ringNode.removeAction(forKey: "enemy.thaw.ring")
        markerNode.removeAction(forKey: "enemy.thaw.marker")
        dangerHaloNode.removeAction(forKey: "enemy.split.halo")
        bodyNode.removeAction(forKey: "enemy.split.body")
        ringNode.removeAction(forKey: "enemy.split.ring")
        dangerHaloNode.alpha = 1
        bodyNode.alpha = 1
        ringNode.alpha = 1
        markerNode.alpha = 1
        dangerHaloNode.setScale(1)
        ringNode.setScale(1)
    }

    func startThawAnimation() {
        let bodyPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.42, duration: 0.09),
            .fadeAlpha(to: 0.88, duration: 0.09)
        ]))
        let ringPulse = SKAction.repeatForever(.sequence([
            .group([
                .scale(to: 1.18, duration: 0.11),
                .fadeAlpha(to: 0.45, duration: 0.11)
            ]),
            .group([
                .scale(to: 1, duration: 0.11),
                .fadeAlpha(to: 0.9, duration: 0.11)
            ])
        ]))
        let markerPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.08),
            .fadeAlpha(to: 0.85, duration: 0.08)
        ]))
        let haloPulse = SKAction.repeatForever(.sequence([
            .group([
                .scale(to: 1.12, duration: 0.11),
                .fadeAlpha(to: 0.42, duration: 0.11)
            ]),
            .group([
                .scale(to: 1, duration: 0.11),
                .fadeAlpha(to: 0.86, duration: 0.11)
            ])
        ]))

        dangerHaloNode.run(haloPulse, withKey: "enemy.thaw.halo")
        bodyNode.run(bodyPulse, withKey: "enemy.thaw.body")
        ringNode.run(ringPulse, withKey: "enemy.thaw.ring")
        markerNode.run(markerPulse, withKey: "enemy.thaw.marker")
    }

    func startSplitProtectedAnimation() {
        let ringPulse = SKAction.repeatForever(.sequence([
            .group([
                .scale(to: 1.14, duration: 0.1),
                .fadeAlpha(to: 0.38, duration: 0.1)
            ]),
            .group([
                .scale(to: 1, duration: 0.1),
                .fadeAlpha(to: 0.85, duration: 0.1)
            ])
        ]))
        let bodyPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.09),
            .fadeAlpha(to: 0.88, duration: 0.09)
        ]))

        dangerHaloNode.run(ringPulse, withKey: "enemy.split.halo")
        ringNode.run(ringPulse, withKey: "enemy.split.ring")
        bodyNode.run(bodyPulse, withKey: "enemy.split.body")
    }
}
