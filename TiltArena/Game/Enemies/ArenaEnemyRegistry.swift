import SpriteKit

@MainActor
final class ArenaEnemyRegistry {
    enum RemovalPresentation {
        case immediate
        case defeated
    }

    private(set) var enemies: [ArenaEnemy] = []
    private var nodesByID: [Int: EnemyNode] = [:]
    private var telegraphNodesByID: [Int: EnemyTelegraphNode] = [:]
    private let logger = AppDiagnostics.logger(.spawn)

    var count: Int {
        enemies.count
    }

    var nodeCount: Int {
        nodesByID.count
    }

    func add(_ newEnemies: [ArenaEnemy], to parent: SKNode, theme: ArenaTheme) {
        var knownIDs = Set(enemies.map(\.id))
        var duplicateIDs: Set<Int> = []

        for enemy in newEnemies {
            guard knownIDs.insert(enemy.id).inserted else {
                duplicateIDs.insert(enemy.id)
                continue
            }

            enemies.append(enemy)
            let node = EnemyNode(enemy: enemy, theme: theme)
            nodesByID[enemy.id] = node
            parent.addChild(node)
        }

        guard !duplicateIDs.isEmpty else {
            return
        }
        logger.critical("enemy.id_invariant_violated", metadata: [
            "duplicates": "\(duplicateIDs.count)",
            "enemies": "\(enemies.count)"
        ])
    }

    func updateAll(_ update: (inout ArenaEnemy) -> Void) {
        for index in enemies.indices {
            update(&enemies[index])
            nodesByID[enemies[index].id]?.apply(enemies[index])
        }
    }

    func update(ids: Set<Int>, _ update: (inout ArenaEnemy) -> Void) {
        guard !ids.isEmpty else {
            return
        }

        for index in enemies.indices where ids.contains(enemies[index].id) {
            update(&enemies[index])
            nodesByID[enemies[index].id]?.apply(enemies[index])
        }
    }

    @discardableResult
    func remove(
        ids: Set<Int>,
        presentation: RemovalPresentation
    ) -> [ArenaEnemy] {
        guard !ids.isEmpty else {
            return []
        }

        let removedEnemies = enemies.filter { ids.contains($0.id) }
        enemies.removeAll { ids.contains($0.id) }

        for enemyID in ids {
            guard let node = nodesByID.removeValue(forKey: enemyID) else {
                continue
            }

            switch presentation {
            case .immediate:
                node.removeFromParent()
            case .defeated:
                let fade = SKAction.group([
                    .scale(to: 0.35, duration: 0.08),
                    .fadeOut(withDuration: 0.08)
                ])
                node.run(.sequence([fade, .removeFromParent()]))
            }
        }

        return removedEnemies
    }

    func reset() {
        enemies.removeAll()
        nodesByID.values.forEach { $0.removeFromParent() }
        nodesByID.removeAll()
        telegraphNodesByID.values.forEach { $0.removeFromParent() }
        telegraphNodesByID.removeAll()
    }

    func showTelegraphs(_ telegraphs: [EnemyTelegraph], in parent: SKNode, theme: ArenaTheme) {
        for telegraph in telegraphs {
            telegraphNodesByID[telegraph.id]?.removeFromParent()
            let node = EnemyTelegraphNode(telegraph: telegraph, theme: theme)
            telegraphNodesByID[telegraph.id] = node
            parent.addChild(node)
        }
    }

    func removeTelegraphs(ids: Set<Int>) {
        for telegraphID in ids {
            telegraphNodesByID.removeValue(forKey: telegraphID)?.removeFromParent()
        }
    }

    func applyTheme(_ theme: ArenaTheme) {
        for enemy in enemies {
            nodesByID[enemy.id]?.applyTheme(theme, enemy: enemy)
        }
        telegraphNodesByID.values.forEach { $0.applyTheme(theme) }
    }

    func enemy(id: Int) -> ArenaEnemy? {
        enemies.first { $0.id == id }
    }

    func indexedEnemiesByID() -> [Int: ArenaEnemy] {
        Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0) })
    }

    func damageablePositionsByID() -> [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: enemies.lazy.filter(\.canDamagePlayer).map { ($0.id, $0.position) })
    }
}
