import CoreGraphics
import XCTest
@testable import TiltArena

final class PlayerMovementControllerTests: XCTestCase {
    func testResetPlacesPlayerAtPlayableCenter() {
        var controller = PlayerMovementController()
        let state = controller.reset(in: CGSize(width: 390, height: 844))

        XCTAssertEqual(state.position.x, 195, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, 422, accuracy: 0.0001)
    }

    func testFullTiltCrossesPlayableWidthAtConfiguredSpeed() {
        let arenaSize = CGSize(width: 390, height: 844)
        var controller = PlayerMovementController()
        _ = controller.reset(in: arenaSize)

        let state = controller.update(input: CGVector(dx: 1, dy: 0), deltaTime: 1, arenaSize: arenaSize)
        let expectedSpeed = controller.configuration.playableRect(in: arenaSize).width / 2.5

        XCTAssertEqual(state.velocity.dx, expectedSpeed, accuracy: 0.0001)
        XCTAssertEqual(state.velocity.dy, 0, accuracy: 0.0001)
    }

    func testMovementClampsToPlayableBounds() {
        let arenaSize = CGSize(width: 390, height: 844)
        var controller = PlayerMovementController()
        _ = controller.reset(in: arenaSize)

        let state = controller.update(input: CGVector(dx: 20, dy: 20), deltaTime: 10, arenaSize: arenaSize)
        let playableRect = controller.configuration.playableRect(in: arenaSize)

        XCTAssertEqual(state.position.x, playableRect.maxX, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, playableRect.maxY, accuracy: 0.0001)
    }
}
