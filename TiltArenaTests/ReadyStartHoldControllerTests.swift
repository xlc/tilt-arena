import XCTest
@testable import TiltArena

final class ReadyStartHoldControllerTests: XCTestCase {
    func testHoldCompletesOnlyAfterRequiredTimeInsideCircle() {
        var controller = ReadyStartHoldController(
            configuration: ReadyStartHoldConfiguration(requiredDuration: 3, startCircleRadius: 10)
        )
        let startPoint = CGPoint(x: 100, y: 100)

        var state = controller.update(
            playerPosition: CGPoint(x: 105, y: 100),
            startPoint: startPoint,
            deltaTime: 1.5
        )
        XCTAssertTrue(state.isInsideCircle)
        XCTAssertFalse(state.didComplete)
        XCTAssertEqual(state.progressFraction(requiredDuration: 3), 0.5, accuracy: 0.0001)

        state = controller.update(
            playerPosition: CGPoint(x: 100, y: 100),
            startPoint: startPoint,
            deltaTime: 1.5
        )
        XCTAssertTrue(state.didComplete)
        XCTAssertEqual(state.progressFraction(requiredDuration: 3), 1, accuracy: 0.0001)
    }

    func testLeavingCircleResetsCountdown() {
        var controller = ReadyStartHoldController(
            configuration: ReadyStartHoldConfiguration(requiredDuration: 3, startCircleRadius: 10)
        )
        let startPoint = CGPoint(x: 100, y: 100)

        controller.update(playerPosition: startPoint, startPoint: startPoint, deltaTime: 2)
        let state = controller.update(
            playerPosition: CGPoint(x: 111, y: 100),
            startPoint: startPoint,
            deltaTime: 1
        )

        XCTAssertFalse(state.isInsideCircle)
        XCTAssertFalse(state.didComplete)
        XCTAssertEqual(state.elapsed, 0)
    }
}
