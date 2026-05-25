import CoreGraphics
import XCTest
@testable import TiltArena

final class ShockwaveWaveStateTests: XCTestCase {
    func testWaveExpandsAndDestroysEnemiesAsTheyTouchRadius() {
        var state = ShockwaveWaveState(
            center: .zero,
            maximumRadius: 120,
            expansionDuration: 0.3,
            holdDuration: 0.1
        )
        let earlyEnemy = enemy(id: 1, position: CGPoint(x: 32, y: 0))
        let laterEnemy = enemy(id: 2, position: CGPoint(x: 96, y: 0))

        var frame = state.update(deltaTime: 0.1, enemies: [earlyEnemy, laterEnemy])

        XCTAssertEqual(frame.radius, 40, accuracy: 0.0001)
        XCTAssertEqual(frame.destroyedEnemyIDs, [1])
        XCTAssertFalse(frame.isComplete)

        frame = state.update(deltaTime: 0.15, enemies: [earlyEnemy, laterEnemy])

        XCTAssertEqual(frame.radius, 100, accuracy: 0.0001)
        XCTAssertEqual(frame.destroyedEnemyIDs, [2])
        XCTAssertFalse(frame.isComplete)
    }

    func testWaveHoldCanDestroyLateArrivingEnemies() {
        var state = ShockwaveWaveState(
            center: .zero,
            maximumRadius: 120,
            expansionDuration: 0.3,
            holdDuration: 0.1
        )
        let lateEnemy = enemy(id: 1, position: CGPoint(x: 124, y: 0))

        var frame = state.update(deltaTime: 0.3, enemies: [])

        XCTAssertEqual(frame.radius, 120, accuracy: 0.0001)
        XCTAssertEqual(frame.destroyedEnemyIDs, [])
        XCTAssertFalse(frame.isComplete)

        frame = state.update(deltaTime: 0.05, enemies: [lateEnemy])

        XCTAssertEqual(frame.destroyedEnemyIDs, [1])
        XCTAssertFalse(frame.isComplete)

        frame = state.update(deltaTime: 0.05, enemies: [lateEnemy])

        XCTAssertTrue(frame.isComplete)
        XCTAssertEqual(frame.destroyedEnemyIDs, [])
    }

    func testWaveDoesNotDestroyTheSameEnemyTwice() {
        var state = ShockwaveWaveState(center: .zero, maximumRadius: 120, expansionDuration: 0.3, holdDuration: 0.1)
        let enemy = enemy(id: 1, position: CGPoint(x: 20, y: 0))

        var frame = state.update(deltaTime: 0.1, enemies: [enemy])

        XCTAssertEqual(frame.destroyedEnemyIDs, [1])

        frame = state.update(deltaTime: 0.1, enemies: [enemy])

        XCTAssertEqual(frame.destroyedEnemyIDs, [])
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 8, speed: 0)
    }
}
