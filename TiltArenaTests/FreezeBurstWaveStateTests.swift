import CoreGraphics
import XCTest
@testable import TiltArena

final class FreezeBurstWaveStateTests: XCTestCase {
    func testWaveExpandsOverTimeAndCatchesLateEnemies() {
        var state = FreezeBurstWaveState(center: .zero, maximumRadius: 100, duration: 0.25)
        let earlyEnemy = enemy(id: 1, position: CGPoint(x: 15, y: 0))
        let lateEnemy = enemy(id: 2, position: CGPoint(x: 75, y: 0))

        var frame = state.update(deltaTime: 0.05, enemies: [earlyEnemy, lateEnemy])

        XCTAssertEqual(frame.radius, 20, accuracy: 0.0001)
        XCTAssertEqual(frame.frozenEnemyIDs, [1])
        XCTAssertFalse(frame.isComplete)

        frame = state.update(deltaTime: 0.15, enemies: [earlyEnemy, lateEnemy])

        XCTAssertEqual(frame.radius, 80, accuracy: 0.0001)
        XCTAssertEqual(frame.frozenEnemyIDs, [2])
        XCTAssertFalse(frame.isComplete)
    }

    func testWaveDoesNotRefreezeTheSameEnemyRepeatedly() {
        var state = FreezeBurstWaveState(center: .zero, maximumRadius: 100, duration: 0.25)
        let enemy = enemy(id: 1, position: CGPoint(x: 15, y: 0))

        var frame = state.update(deltaTime: 0.05, enemies: [enemy])

        XCTAssertEqual(frame.frozenEnemyIDs, [1])

        frame = state.update(deltaTime: 0.05, enemies: [enemy])

        XCTAssertEqual(frame.frozenEnemyIDs, [])
    }

    func testWaveStopsCatchingEnemiesAfterCompletion() {
        var state = FreezeBurstWaveState(center: .zero, maximumRadius: 100, duration: 0.1)
        let firstEnemy = enemy(id: 1, position: CGPoint(x: 90, y: 0))
        let secondEnemy = enemy(id: 2, position: CGPoint(x: 80, y: 0))

        var frame = state.update(deltaTime: 0.1, enemies: [firstEnemy])

        XCTAssertTrue(frame.isComplete)
        XCTAssertEqual(frame.frozenEnemyIDs, [1])

        frame = state.update(deltaTime: 0.1, enemies: [secondEnemy])

        XCTAssertTrue(frame.isComplete)
        XCTAssertEqual(frame.frozenEnemyIDs, [])
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 8, speed: 0)
    }
}
