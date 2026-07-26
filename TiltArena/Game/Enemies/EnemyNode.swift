import SpriteKit

@MainActor
final class EnemyNode: SKNode {
    private let dangerHaloNode: SKShapeNode
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let markerNode: SKShapeNode
    private let highlightNode: SKShapeNode
    private var theme: ArenaTheme
    private var visualSignature: VisualSignature?

    init(enemy: ArenaEnemy, theme: ArenaTheme) {
        dangerHaloNode = SKShapeNode()
        bodyNode = SKShapeNode()
        ringNode = SKShapeNode()
        markerNode = SKShapeNode()
        highlightNode = SKShapeNode()
        self.theme = theme
        super.init()

        zPosition = 15

        dangerHaloNode.fillColor = .clear
        addChild(dangerHaloNode)

        ringNode.fillColor = .clear
        addChild(ringNode)

        addChild(bodyNode)
        addChild(highlightNode)
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
        highlightNode.path = EnemyVisualGeometry.circlePath(radius: enemy.radius * 0.22)
        highlightNode.position = CGPoint(x: -enemy.radius * 0.24, y: enemy.radius * 0.28)

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
        highlightNode.strokeColor = .clear
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

        let isNormalChaser = kind == .chaser
            && !enemy.isShatterableFrozen
            && !enemy.isSplitProtected
        dangerHaloNode.isHidden = isNormalChaser
        ringNode.isHidden = isNormalChaser
        highlightNode.isHidden = isNormalChaser

        if isNormalChaser {
            bodyNode.strokeColor = theme.enemyColor.withAlphaComponent(0.52)
            bodyNode.lineWidth = 0.8
            bodyNode.glowWidth = 0
        }
    }

    func applyBaseStyle() {
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.58)
        dangerHaloNode.lineWidth = 2
        dangerHaloNode.glowWidth = 0.6
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        markerNode.lineWidth = 1.8
        markerNode.lineCap = .round
        markerNode.lineJoin = .round
        markerNode.glowWidth = 0.45
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.42)
        ringNode.lineWidth = 1.1
        ringNode.glowWidth = 0.45
        bodyNode.fillColor = theme.enemyColor
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        bodyNode.lineWidth = 1.5
        bodyNode.glowWidth = 0.7
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.24)
        highlightNode.isHidden = false
        highlightNode.alpha = 1
    }

    func applyRoleStyle(_ kind: EnemyKind) {
        switch kind {
        case .chaser:
            break
        case .formation:
            applyFormationStyle()
        case .arrowRush:
            applyArrowRushStyle()
        case .mine:
            applyMineStyle()
        case .hunter:
            applyHunterStyle()
        case .paddleBar:
            applyPaddleBarStyle()
        case .paddlePuck:
            applyPaddlePuckStyle()
        case .splitter:
            applySplitterStyle()
        case .splitterChild:
            applySplitterChildStyle()
        }
    }

    func applyFormationStyle() {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.58)
        ringNode.lineWidth = 1.25
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.82)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.66)
        bodyNode.lineWidth = 1.25
        bodyNode.glowWidth = 0.35
    }
    func applyArrowRushStyle() {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.76)
        ringNode.lineWidth = 1.6
        ringNode.glowWidth = 0.7
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.94)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.9)
        bodyNode.lineWidth = 1.6
        bodyNode.glowWidth = 0.85
    }
    func applyMineStyle() {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.78)
        ringNode.lineWidth = 1.8
        ringNode.glowWidth = 0.55
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.48)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        bodyNode.glowWidth = 0.5
    }
    func applyHunterStyle() {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.76)
        ringNode.lineWidth = 1.7
        ringNode.glowWidth = 0.55
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.84)
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.88)
    }
    func applyPaddleBarStyle() {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.62)
        ringNode.lineWidth = 1.5
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.58)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.76)
        bodyNode.glowWidth = 0.4
    }
    func applyPaddlePuckStyle() {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.72)
        ringNode.lineWidth = 1.6
        ringNode.glowWidth = 0.6
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.9)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.86)
        bodyNode.glowWidth = 0.7
    }
    func applySplitterStyle() {
        ringNode.strokeColor = theme.playerColor.withAlphaComponent(0.78)
        ringNode.lineWidth = 1.8
        ringNode.glowWidth = 0.7
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.86)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.9)
        bodyNode.glowWidth = 0.8
    }
    func applySplitterChildStyle() {
        ringNode.strokeColor = theme.playerColor.withAlphaComponent(0.48)
        ringNode.lineWidth = 1.3
        bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.76)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.72)
        bodyNode.glowWidth = 0.45
    }

    func applyFrozenStyle() {
        dangerHaloNode.strokeColor = theme.playerColor.withAlphaComponent(0.62)
        dangerHaloNode.lineWidth = 1.9
        ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.72)
        ringNode.lineWidth = 1.8
        ringNode.glowWidth = 0.9
        bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.55)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        bodyNode.lineWidth = 1.7
        bodyNode.glowWidth = 1
        markerNode.strokeColor = theme.playerColor.withAlphaComponent(0.82)
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.36)
    }

    func applyThawingStyle() {
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
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.2)
    }

    func applySplitProtectedStyle() {
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
        highlightNode.fillColor = theme.playerColor.withAlphaComponent(0.18)
    }

    func resetStateAnimations() {
        dangerHaloNode.removeAction(forKey: "enemy.thaw.halo")
        bodyNode.removeAction(forKey: "enemy.thaw.body")
        ringNode.removeAction(forKey: "enemy.thaw.ring")
        markerNode.removeAction(forKey: "enemy.thaw.marker")
        highlightNode.removeAction(forKey: "enemy.thaw.highlight")
        dangerHaloNode.removeAction(forKey: "enemy.split.halo")
        bodyNode.removeAction(forKey: "enemy.split.body")
        ringNode.removeAction(forKey: "enemy.split.ring")
        dangerHaloNode.alpha = 1
        bodyNode.alpha = 1
        ringNode.alpha = 1
        markerNode.alpha = 1
        highlightNode.alpha = 1
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
        let highlightPulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.08),
            .fadeAlpha(to: 0.58, duration: 0.08)
        ]))

        dangerHaloNode.run(haloPulse, withKey: "enemy.thaw.halo")
        bodyNode.run(bodyPulse, withKey: "enemy.thaw.body")
        ringNode.run(ringPulse, withKey: "enemy.thaw.ring")
        markerNode.run(markerPulse, withKey: "enemy.thaw.marker")
        highlightNode.run(highlightPulse, withKey: "enemy.thaw.highlight")
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
