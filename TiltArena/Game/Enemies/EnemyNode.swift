import SpriteKit

@MainActor
final class EnemyNode: SKNode {
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let theme: ArenaTheme

    init(enemy: ArenaEnemy, theme: ArenaTheme) {
        bodyNode = SKShapeNode(circleOfRadius: enemy.radius)
        ringNode = SKShapeNode(circleOfRadius: enemy.radius * 1.45)
        self.theme = theme
        super.init()

        zPosition = 15

        ringNode.fillColor = .clear
        addChild(ringNode)

        addChild(bodyNode)

        apply(enemy)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyNode does not support storyboard initialization.")
    }

    func apply(_ enemy: ArenaEnemy) {
        position = enemy.position
        applyAppearance(enemy)
    }

    private func applyAppearance(_ enemy: ArenaEnemy) {
        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.55)
        ringNode.lineWidth = 1.1
        ringNode.glowWidth = 1
        bodyNode.fillColor = theme.enemyColor
        bodyNode.strokeColor = theme.enemyColor.withAlphaComponent(0.85)
        bodyNode.lineWidth = 1
        bodyNode.glowWidth = 3

        if enemy.isMineDot {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.8)
            ringNode.lineWidth = 2
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.82)
            bodyNode.glowWidth = 1.5
        } else if enemy.isHunterDot {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.9)
            ringNode.lineWidth = 1.8
            ringNode.glowWidth = 2
            bodyNode.strokeColor = theme.enemyColor
        } else if enemy.isPaddleTrap {
            ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.7)
            ringNode.lineWidth = 1.5
            bodyNode.fillColor = theme.enemyColor.withAlphaComponent(0.9)
            bodyNode.glowWidth = 2
        }

        if enemy.isFrozen {
            ringNode.strokeColor = theme.pickupBlue.withAlphaComponent(0.9)
            ringNode.lineWidth = 2
            ringNode.glowWidth = 3
            bodyNode.fillColor = theme.pickupBlue.withAlphaComponent(0.55)
            bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.95)
            bodyNode.glowWidth = 4
        }
    }
}
