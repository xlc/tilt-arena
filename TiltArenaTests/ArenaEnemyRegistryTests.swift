import SpriteKit
import XCTest
@testable import TiltArena

final class ArenaEnemyRegistryTests: XCTestCase {
    @MainActor
    func testDuplicateEnemyIDIsRejectedWithoutOrphaningNode() {
        let registry = ArenaEnemyRegistry()
        let parent = SKNode()
        let enemy = makeEnemy(id: 1)

        registry.add([enemy, enemy], to: parent, theme: ArenaThemeKind.darkTacticalRadar.theme)

        XCTAssertEqual(registry.enemies, [enemy])
        XCTAssertEqual(registry.nodeCount, 1)
        XCTAssertEqual(parent.children.count, 1)
    }

    @MainActor
    func testRemovalKeepsEnemyAndNodeOwnershipInSync() {
        let registry = ArenaEnemyRegistry()
        let parent = SKNode()
        let first = makeEnemy(id: 1, formationID: 10)
        let second = makeEnemy(id: 2, formationID: 10)
        registry.add([first, second], to: parent, theme: ArenaThemeKind.darkTacticalRadar.theme)

        let removed = registry.remove(ids: [first.id], presentation: .immediate)

        XCTAssertEqual(removed, [first])
        XCTAssertEqual(registry.enemies, [second])
        XCTAssertEqual(registry.nodeCount, 1)
        XCTAssertEqual(parent.children.count, 1)

        registry.remove(ids: [second.id], presentation: .immediate)

        XCTAssertTrue(registry.enemies.isEmpty)
        XCTAssertEqual(registry.nodeCount, 0)
        XCTAssertTrue(parent.children.isEmpty)
    }

    @MainActor
    func testUpdatesMutateModelsAndApplyToNodesTogether() {
        let registry = ArenaEnemyRegistry()
        let parent = SKNode()
        registry.add([makeEnemy(id: 1)], to: parent, theme: ArenaThemeKind.darkTacticalRadar.theme)

        registry.update(ids: [1]) { enemy in
            enemy.position = CGPoint(x: 120, y: 80)
        }

        XCTAssertEqual(registry.enemy(id: 1)?.position, CGPoint(x: 120, y: 80))
        XCTAssertEqual(parent.children.first?.position, CGPoint(x: 120, y: 80))
    }

    private func makeEnemy(id: Int, formationID: Int? = nil) -> ArenaEnemy {
        ArenaEnemy(
            id: id,
            position: CGPoint(x: 20, y: 30),
            radius: 8,
            speed: 0,
            behavior: formationID.map {
                .formationLine(velocity: .zero, formationID: $0)
            } ?? .chaser
        )
    }
}
