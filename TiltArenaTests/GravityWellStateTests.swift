import XCTest
@testable import TiltArena

final class GravityWellStateTests: XCTestCase {
    func testCoreDetectsCrossingPathsAtEveryFrameRate() {
        for rate in [30, 60, 120] {
            let state = GravityWellState(center: .zero, timeRemaining: 1, clearRadius: 32)
            var previous = CGPoint(x: -101, y: 33.99)
            var cleared = false
            for index in 1...rate {
                let position = CGPoint(x: -101 + CGFloat(index) * 200 / CGFloat(rate), y: 33.99)
                let enemy = ArenaEnemy(id: 1, position: position, radius: 2, speed: 0)
                cleared = cleared || state.collapseTargets(enemies: [enemy], previousPositions: [1: previous]).contains(1)
                previous = position
            }
            XCTAssertTrue(cleared, "\(rate) Hz")
        }
    }

    func testCoreDoesNotClearAPathThatMissesItsHitRadius() {
        let state = GravityWellState(center: .zero, timeRemaining: 1, clearRadius: 32)
        let enemy = ArenaEnemy(id: 1, position: CGPoint(x: 50, y: 34.01), radius: 2, speed: 0)
        XCTAssertTrue(state.collapseTargets(
            enemies: [enemy], previousPositions: [1: CGPoint(x: -50, y: 34.01)]
        ).isEmpty)
    }

    func testMembershipTracksCurrentPositionsRatherThanInitialTargets() {
        let state = GravityWellState(center: .zero, timeRemaining: 1, pullRadius: 100)
        var enemy = ArenaEnemy(id: 1, position: CGPoint(x: 150, y: 0), radius: 2, speed: 0)
        XCTAssertTrue(state.pullTargets(enemies: [enemy]).isEmpty)
        enemy.position.x = 80
        XCTAssertEqual(state.pullTargets(enemies: [enemy]), [1])
        enemy.position.x = 150
        XCTAssertTrue(state.pullTargets(enemies: [enemy]).isEmpty)
    }

    func testActivationDelayPreventsPullUntilDelayElapses() {
        var state = GravityWellState(
            center: .zero,
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
            timeRemaining: 0.85,
            activationDelayRemaining: 0.5
        )

        XCTAssertEqual(state.consumePullDelta(deltaTime: 2), 0.85, accuracy: 0.0001)
        XCTAssertEqual(state.activationDelayRemaining, 0, accuracy: 0.0001)
        XCTAssertEqual(state.timeRemaining, 0, accuracy: 0.0001)
        XCTAssertTrue(state.isComplete)
    }
}
