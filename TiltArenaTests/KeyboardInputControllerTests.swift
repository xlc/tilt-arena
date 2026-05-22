import CoreGraphics
import XCTest
@testable import TiltArena

final class KeyboardInputControllerTests: XCTestCase {
    func testNoPressedMovementKeysIsInactiveWithZeroVector() {
        let input = KeyboardMovementInput()

        XCTAssertFalse(input.isActive)
        XCTAssertEqual(input.vector.dx, 0, accuracy: 0.0001)
        XCTAssertEqual(input.vector.dy, 0, accuracy: 0.0001)
    }

    func testCardinalDirectionsMapToMovementVector() {
        XCTAssertEqual(KeyboardMovementInput(left: true).vector, CGVector(dx: -1, dy: 0))
        XCTAssertEqual(KeyboardMovementInput(right: true).vector, CGVector(dx: 1, dy: 0))
        XCTAssertEqual(KeyboardMovementInput(upward: true).vector, CGVector(dx: 0, dy: 1))
        XCTAssertEqual(KeyboardMovementInput(downward: true).vector, CGVector(dx: 0, dy: -1))
    }

    func testDiagonalMovementIsNormalized() {
        let vector = KeyboardMovementInput(right: true, upward: true).vector

        XCTAssertEqual(vector.length, 1, accuracy: 0.0001)
        XCTAssertEqual(vector.dx, 0.7071, accuracy: 0.0001)
        XCTAssertEqual(vector.dy, 0.7071, accuracy: 0.0001)
    }

    func testOpposingDirectionsCancelWhileInputRemainsActive() {
        let input = KeyboardMovementInput(left: true, right: true)

        XCTAssertTrue(input.isActive)
        XCTAssertEqual(input.vector.dx, 0, accuracy: 0.0001)
        XCTAssertEqual(input.vector.dy, 0, accuracy: 0.0001)
    }
}
