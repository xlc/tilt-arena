import CoreGraphics
import SpriteKit
import XCTest
@testable import TiltArena

@MainActor
final class PlayerCraftNodeTests: XCTestCase {
    func testMotionAccentUsesProvidedSpeedFractionInsteadOfRawVelocity() throws {
        let node = PlayerCraftNode(theme: .darkTacticalRadar, visualRadius: 12)
        let fastState = PlayerMovementState(position: .zero, velocity: CGVector(dx: 1_000, dy: 0))

        node.apply(state: fastState, speedFraction: 0)
        let engineNode = try XCTUnwrap(node.children.min { $0.position.y < $1.position.y })
        XCTAssertEqual(engineNode.alpha, 0.42, accuracy: 0.0001)
        XCTAssertEqual(engineNode.xScale, 0.82, accuracy: 0.0001)

        node.apply(state: fastState, speedFraction: 1)
        XCTAssertEqual(engineNode.alpha, 0.90, accuracy: 0.0001)
        XCTAssertEqual(engineNode.xScale, 1.24, accuracy: 0.0001)
    }
}
