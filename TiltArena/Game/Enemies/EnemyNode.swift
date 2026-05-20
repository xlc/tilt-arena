import SpriteKit

@MainActor
final class EnemyNode: SKNode {
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode

    init(enemy: ArenaEnemy, theme: ArenaTheme) {
        bodyNode = SKShapeNode(circleOfRadius: enemy.radius)
        ringNode = SKShapeNode(circleOfRadius: enemy.radius * 1.45)
        super.init()

        zPosition = 15

        ringNode.strokeColor = theme.enemyColor.withAlphaComponent(0.55)
        ringNode.lineWidth = 1.1
        ringNode.fillColor = .clear
        ringNode.glowWidth = 1
        addChild(ringNode)

        bodyNode.fillColor = theme.enemyColor
        bodyNode.strokeColor = theme.enemyColor.withAlphaComponent(0.85)
        bodyNode.lineWidth = 1
        bodyNode.glowWidth = 3
        addChild(bodyNode)

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
        }

        apply(enemy)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("EnemyNode does not support storyboard initialization.")
    }

    func apply(_ enemy: ArenaEnemy) {
        position = enemy.position
    }
}
