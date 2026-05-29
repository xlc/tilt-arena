import CoreGraphics
import XCTest
@testable import TiltArena

final class AimDirectionStateTests: XCTestCase {
    func testDefaultsToUpwardDirectionBeforeMovement() {
        let state = AimDirectionState()

        XCTAssertEqual(state.resolvedDirection().dx, 0, accuracy: 0.0001)
        XCTAssertEqual(state.resolvedDirection().dy, 1, accuracy: 0.0001)
    }

    func testRecordsNormalizedMovementDirection() {
        var state = AimDirectionState()

        state.record(input: CGVector(dx: 3, dy: 4))

        XCTAssertEqual(state.resolvedDirection().dx, 0.6, accuracy: 0.0001)
        XCTAssertEqual(state.resolvedDirection().dy, 0.8, accuracy: 0.0001)
    }

    func testNeutralInputKeepsLastMovementDirection() {
        var state = AimDirectionState()
        state.record(input: CGVector(dx: -1, dy: 0))
        state.record(input: CGVector(dx: 0.01, dy: 0))

        XCTAssertEqual(state.resolvedDirection().dx, -1, accuracy: 0.0001)
        XCTAssertEqual(state.resolvedDirection().dy, 0, accuracy: 0.0001)
    }

    func testResetRestoresUpwardFallback() {
        var state = AimDirectionState()
        state.record(input: CGVector(dx: 1, dy: 0))
        state.reset()

        XCTAssertEqual(state.resolvedDirection().dx, 0, accuracy: 0.0001)
        XCTAssertEqual(state.resolvedDirection().dy, 1, accuracy: 0.0001)
    }
}
