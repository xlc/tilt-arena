import XCTest
@testable import TiltArena

final class NovaBombTargetSelectorTests: XCTestCase {
    func testTargetCountUsesMinimumAndUncappedFraction() {
        let selector = NovaBombTargetSelector(
            configuration: StartingWeaponConfiguration(
                novaBombMinimumTargetCount: 15,
                novaBombTargetFraction: 0.8
            )
        )

        XCTAssertEqual(selector.targetCount(enemyCount: 0), 0)
        XCTAssertEqual(selector.targetCount(enemyCount: 1), 1)
        XCTAssertEqual(selector.targetCount(enemyCount: 3), 3)
        XCTAssertEqual(selector.targetCount(enemyCount: 20), 16)
        XCTAssertEqual(selector.targetCount(enemyCount: 100), 80)
    }

    func testSelectionIsDeterministicWithInjectedGenerator() {
        let selector = NovaBombTargetSelector()
        let enemies = (1...12).map { ArenaEnemy(id: $0, position: .zero, radius: 6, speed: 0) }
        var firstGenerator = SeededGenerator(seed: 7)
        var secondGenerator = SeededGenerator(seed: 7)

        let firstSelection = selector.selectedEnemyIDs(from: enemies, using: &firstGenerator)
        let secondSelection = selector.selectedEnemyIDs(from: enemies, using: &secondGenerator)

        XCTAssertEqual(firstSelection, secondSelection)
        XCTAssertEqual(firstSelection.count, 12)
    }

    func testSelectionReturnsNoDuplicatesAndNeverExceedsEnemyCount() {
        let selector = NovaBombTargetSelector()
        let enemies = (1...4).map { ArenaEnemy(id: $0, position: .zero, radius: 6, speed: 0) }
        var generator = SeededGenerator(seed: 11)

        let selection = selector.selectedEnemyIDs(from: enemies, using: &generator)

        XCTAssertEqual(selection.count, 4)
        XCTAssertTrue(selection.isSubset(of: Set(enemies.map(\.id))))
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
