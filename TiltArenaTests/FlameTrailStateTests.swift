import XCTest
@testable import TiltArena

final class FlameTrailStateTests: XCTestCase {
    func testActiveEnemiesBurnImmediatelyOnContact() {
        var state = FlameTrailState(configuration: FlameTrailConfiguration(segmentRadius: 12))
        state.activate(at: .zero)

        let frame = state.update(
            deltaTime: 0.1,
            playerPosition: .zero,
            enemies: [
                enemy(id: 1, position: CGPoint(x: 10, y: 0)),
                enemy(id: 2, position: CGPoint(x: 40, y: 0))
            ]
        )

        XCTAssertEqual(frame.burnedEnemyIDs, [1])
    }

    func testFrozenEnemiesBurnAfterContinuousMeltDelay() {
        var state = FlameTrailState(configuration: FlameTrailConfiguration(segmentRadius: 12, frozenMeltDelay: 0.3))
        state.activate(at: .zero)
        let frozen = frozenEnemy(id: 1, position: CGPoint(x: 10, y: 0))

        var frame = state.update(deltaTime: 0.2, playerPosition: .zero, enemies: [frozen])
        XCTAssertEqual(frame.burnedEnemyIDs, [])

        frame = state.update(deltaTime: 0.1, playerPosition: .zero, enemies: [frozen])
        XCTAssertEqual(frame.burnedEnemyIDs, [1])
    }

    func testFrozenMeltCancelsWhenContactEnds() {
        var state = FlameTrailState(configuration: FlameTrailConfiguration(segmentRadius: 12, frozenMeltDelay: 0.3))
        state.activate(at: .zero)
        let frozenInContact = frozenEnemy(id: 1, position: CGPoint(x: 10, y: 0))
        let frozenAway = frozenEnemy(id: 1, position: CGPoint(x: 80, y: 0))

        XCTAssertEqual(
            state.update(deltaTime: 0.2, playerPosition: .zero, enemies: [frozenInContact]).burnedEnemyIDs,
            []
        )
        XCTAssertEqual(
            state.update(deltaTime: 0.1, playerPosition: .zero, enemies: [frozenAway]).burnedEnemyIDs,
            []
        )
        XCTAssertEqual(
            state.update(deltaTime: 0.1, playerPosition: .zero, enemies: [frozenInContact]).burnedEnemyIDs,
            []
        )
        XCTAssertEqual(
            state.update(deltaTime: 0.2, playerPosition: .zero, enemies: [frozenInContact]).burnedEnemyIDs,
            [1]
        )
    }

    func testSegmentsExpireAfterLifetimeWhenTrailStopsGenerating() {
        var state = FlameTrailState(configuration: FlameTrailConfiguration(
            duration: 0.1,
            segmentLifetime: 0.2
        ))
        state.activate(at: .zero)

        XCTAssertEqual(state.update(deltaTime: 0.1, playerPosition: .zero, enemies: []).segments.count, 1)
        XCTAssertEqual(state.update(deltaTime: 0.11, playerPosition: .zero, enemies: []).segments.count, 0)
    }

    func testSegmentSpacingControlsWhenNewSegmentsAreRecorded() {
        var state = FlameTrailState(configuration: FlameTrailConfiguration(segmentSpacing: 14))
        state.activate(at: .zero)

        XCTAssertEqual(
            state.update(deltaTime: 0.1, playerPosition: CGPoint(x: 13, y: 0), enemies: []).segments.count,
            1
        )
        XCTAssertEqual(
            state.update(deltaTime: 0.1, playerPosition: CGPoint(x: 14, y: 0), enemies: []).segments.count,
            2
        )
    }

    func testMaxSegmentsCapsOldestSegments() {
        var state = FlameTrailState(configuration: FlameTrailConfiguration(
            duration: 10,
            segmentLifetime: 10,
            segmentSpacing: 1,
            maxSegments: 3
        ))
        state.activate(at: .zero)

        for x in 1...4 {
            _ = state.update(deltaTime: 0.1, playerPosition: CGPoint(x: x, y: 0), enemies: [])
        }

        XCTAssertEqual(state.segments.count, 3)
        XCTAssertEqual(state.segments.map(\.position.x), [2, 3, 4])
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 8, speed: 0)
    }

    private func frozenEnemy(id: Int, position: CGPoint) -> ArenaEnemy {
        var frozen = enemy(id: id, position: position)
        frozen.freeze(duration: 1)
        return frozen
    }
}
