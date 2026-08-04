import XCTest
@testable import TiltArena

final class NovaBombTargetSelectorTests: XCTestCase {
    func testNonfiniteFractionAndExtremeEnemyCountStaySafe() {
        let invalidSelector = NovaBombTargetSelector(
            configuration: StartingWeaponConfiguration(novaBombTargetFraction: .nan)
        )
        let fullSelector = NovaBombTargetSelector(
            configuration: StartingWeaponConfiguration(novaBombTargetFraction: 1)
        )

        XCTAssertEqual(invalidSelector.targetCount(enemyCount: 10), 0)
        XCTAssertEqual(fullSelector.targetCount(enemyCount: .max), .max)
    }

    func testTargetCountUsesFractionOnly() {
        let selector = NovaBombTargetSelector(
            configuration: StartingWeaponConfiguration(
                novaBombTargetFraction: 0.5
            )
        )

        XCTAssertEqual(selector.targetCount(enemyCount: 0), 0)
        XCTAssertEqual(selector.targetCount(enemyCount: 1), 1)
        XCTAssertEqual(selector.targetCount(enemyCount: 3), 2)
        XCTAssertEqual(selector.targetCount(enemyCount: 20), 10)
        XCTAssertEqual(selector.targetCount(enemyCount: 100), 50)
    }

    func testSelectionIsDeterministicWithInjectedGenerator() {
        let selector = NovaBombTargetSelector()
        let enemies = (1...12).map { ArenaEnemy(id: $0, position: .zero, radius: 6, speed: 0) }
        var firstGenerator = RunRandomNumberGenerator(seed: 7)
        var secondGenerator = RunRandomNumberGenerator(seed: 7)

        let firstSelection = selector.selectedEnemyIDs(from: enemies, using: &firstGenerator)
        let secondSelection = selector.selectedEnemyIDs(from: enemies, using: &secondGenerator)

        XCTAssertEqual(firstSelection, secondSelection)
        XCTAssertEqual(firstSelection.count, 6)
    }

    func testSelectionReturnsNoDuplicatesAndNeverExceedsEnemyCount() {
        let selector = NovaBombTargetSelector()
        let enemies = (1...4).map { ArenaEnemy(id: $0, position: .zero, radius: 6, speed: 0) }
        var generator = RunRandomNumberGenerator(seed: 11)

        let selection = selector.selectedEnemyIDs(from: enemies, using: &generator)

        XCTAssertEqual(selection.count, 2)
        XCTAssertTrue(selection.isSubset(of: Set(enemies.map(\.id))))
    }

    func testRunGeneratorReplaysEveryNovaChoiceFromTheSameSeed() {
        let selector = NovaBombTargetSelector()
        let enemies = (1...18).map { ArenaEnemy(id: $0, position: .zero, radius: 6, speed: 0) }
        var firstRun = RunRandomNumberGenerator(seed: 20_260_726)
        var replay = RunRandomNumberGenerator(seed: 20_260_726)

        XCTAssertEqual(firstRun.initialSeed, 20_260_726)
        XCTAssertEqual(replay.initialSeed, firstRun.initialSeed)

        let firstChoices = (0..<3).map { _ in
            selector.selectedEnemyIDs(from: enemies, using: &firstRun)
        }
        let replayedChoices = (0..<3).map { _ in
            selector.selectedEnemyIDs(from: enemies, using: &replay)
        }

        XCTAssertEqual(firstChoices, replayedChoices)
    }
}
