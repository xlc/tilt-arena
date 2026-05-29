import CoreGraphics
import XCTest
@testable import TiltArena

final class PlayerMovementControllerTests: XCTestCase {
    func testDefaultConfigurationUsesSmallerPlayerVisualRadius() {
        let configuration = PlayerMovementConfiguration()
        let playableRect = configuration.playableRect(in: CGSize(width: 390, height: 844))

        XCTAssertEqual(configuration.visualRadius, 12, accuracy: 0.0001)
        XCTAssertEqual(playableRect, CGRect(x: 30, y: 30, width: 330, height: 784))
    }

    func testResetPlacesPlayerAtPlayableCenter() {
        var controller = PlayerMovementController()
        let state = controller.reset(in: CGSize(width: 390, height: 844))

        XCTAssertEqual(state.position.x, 195, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, 422, accuracy: 0.0001)
    }

    func testResetPlacesPlayerAtSafeGameplayBoundsCenter() {
        let safeBounds = CGRect(x: 83, y: 45, width: 686, height: 324)
        var controller = PlayerMovementController()
        let state = controller.reset(in: safeBounds)
        let playableRect = controller.configuration.playableRect(in: safeBounds)

        XCTAssertEqual(state.position.x, playableRect.midX, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, playableRect.midY, accuracy: 0.0001)
        XCTAssertGreaterThan(state.position.x, safeBounds.minX)
        XCTAssertGreaterThan(state.position.y, safeBounds.minY)
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

    func testMovementCanApplyTemporarySpeedMultiplier() {
        let arenaSize = CGSize(width: 390, height: 844)
        var controller = PlayerMovementController()
        let startState = controller.reset(in: arenaSize)
        let state = controller.update(
            input: CGVector(dx: 1, dy: 0),
            deltaTime: 0.1,
            arenaBounds: CGRect(origin: .zero, size: arenaSize),
            speedMultiplier: 5
        )
        let expectedSpeed = controller.configuration.playableRect(in: arenaSize).width / 2.5 * 5

        XCTAssertEqual(state.velocity.dx, expectedSpeed, accuracy: 0.0001)
        XCTAssertEqual(state.position.x, startState.position.x + expectedSpeed * 0.1, accuracy: 0.0001)
    }

    func testMovementClampsToSafeGameplayBounds() {
        let safeBounds = CGRect(x: 83, y: 45, width: 686, height: 324)
        var controller = PlayerMovementController()
        _ = controller.reset(in: safeBounds)

        let state = controller.update(input: CGVector(dx: 20, dy: 20), deltaTime: 10, arenaBounds: safeBounds)
        let playableRect = controller.configuration.playableRect(in: safeBounds)

        XCTAssertEqual(state.position.x, playableRect.maxX, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, playableRect.maxY, accuracy: 0.0001)
    }

    func testDashMovesAlongDirectionByDistance() {
        let arenaSize = CGSize(width: 390, height: 844)
        var controller = PlayerMovementController()
        let startState = controller.reset(in: arenaSize)
        let distance: CGFloat = 99

        let state = controller.dash(
            direction: CGVector(dx: 3, dy: 4),
            distance: distance,
            arenaSize: arenaSize
        )

        XCTAssertEqual(state.position.x, startState.position.x + distance * 0.6, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, startState.position.y + distance * 0.8, accuracy: 0.0001)
        XCTAssertGreaterThan(state.velocity.length, 2)
    }

    func testDashClampsToPlayableBounds() {
        let arenaSize = CGSize(width: 390, height: 844)
        var controller = PlayerMovementController()
        _ = controller.reset(in: arenaSize)
        let playableRect = controller.configuration.playableRect(in: arenaSize)

        let state = controller.dash(
            direction: CGVector(dx: 1, dy: 1),
            distance: 10_000,
            arenaSize: arenaSize
        )

        XCTAssertEqual(state.position.x, playableRect.maxX, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, playableRect.maxY, accuracy: 0.0001)
    }

    func testDashClampsToSafeGameplayBounds() {
        let safeBounds = CGRect(x: 83, y: 45, width: 686, height: 324)
        var controller = PlayerMovementController()
        _ = controller.reset(in: safeBounds)
        let playableRect = controller.configuration.playableRect(in: safeBounds)

        let state = controller.dash(
            direction: CGVector(dx: 1, dy: 1),
            distance: 10_000,
            arenaBounds: safeBounds
        )

        XCTAssertEqual(state.position.x, playableRect.maxX, accuracy: 0.0001)
        XCTAssertEqual(state.position.y, playableRect.maxY, accuracy: 0.0001)
    }

    func testDashIgnoresZeroDirectionAndInvalidDistance() {
        let arenaSize = CGSize(width: 390, height: 844)
        var controller = PlayerMovementController()
        let startState = controller.reset(in: arenaSize)

        XCTAssertEqual(
            controller.dash(direction: .zero, distance: 100, arenaSize: arenaSize),
            startState
        )
        XCTAssertEqual(
            controller.dash(direction: CGVector(dx: 1, dy: 0), distance: 0, arenaSize: arenaSize),
            startState
        )
    }
}
