import XCTest
@testable import TiltArena

final class GravityWellStateTests: XCTestCase {
    func testActivationDelayPreventsPullUntilDelayElapses() {
        var state = GravityWellState(
            center: .zero,
            enemyIDs: [1],
            timeRemaining: 0.85,
            activationDelayRemaining: 0.5
        )

        XCTAssertEqual(state.consumePullDelta(deltaTime: 0.25), 0, accuracy: 0.0001)
        XCTAssertEqual(state.activationDelayRemaining, 0.25, accuracy: 0.0001)
        XCTAssertEqual(state.timeRemaining, 0.85, accuracy: 0.0001)
        XCTAssertFalse(state.isComplete)
    }

    func testDeltaCrossingActivationDelayStartsPullWithRemainingTime() {
        var state = GravityWellState(
            center: .zero,
            enemyIDs: [1],
            timeRemaining: 0.85,
            activationDelayRemaining: 0.5
        )

        XCTAssertEqual(state.consumePullDelta(deltaTime: 0.6), 0.1, accuracy: 0.0001)
        XCTAssertEqual(state.activationDelayRemaining, 0, accuracy: 0.0001)
        XCTAssertEqual(state.timeRemaining, 0.75, accuracy: 0.0001)
        XCTAssertFalse(state.isComplete)
    }

    func testStateCompletesAfterDelayAndFullPullDuration() {
        var state = GravityWellState(
            center: .zero,
            enemyIDs: [1],
            timeRemaining: 0.85,
            activationDelayRemaining: 0.5
        )

        XCTAssertEqual(state.consumePullDelta(deltaTime: 2), 0.85, accuracy: 0.0001)
        XCTAssertEqual(state.activationDelayRemaining, 0, accuracy: 0.0001)
        XCTAssertEqual(state.timeRemaining, 0, accuracy: 0.0001)
        XCTAssertTrue(state.isComplete)
    }
}
