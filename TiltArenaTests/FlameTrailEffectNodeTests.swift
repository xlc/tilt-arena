import SpriteKit
import XCTest
@testable import TiltArena

@MainActor
final class FlameTrailEffectNodeTests: XCTestCase {
    func testSegmentsRenderAsOneContinuousTrailInsteadOfPerSegmentNodes() {
        let node = FlameTrailEffectNode(theme: .darkTacticalRadar)
        let segments = [
            FlameTrailSegment(
                id: 1,
                position: CGPoint(x: 0, y: 0),
                radius: 16,
                timeRemaining: 0.2,
                lifetime: 1.2
            ),
            FlameTrailSegment(
                id: 2,
                position: CGPoint(x: 18, y: 8),
                radius: 16,
                timeRemaining: 0.7,
                lifetime: 1.2
            ),
            FlameTrailSegment(
                id: 3,
                position: CGPoint(x: 36, y: 14),
                radius: 16,
                timeRemaining: 1.2,
                lifetime: 1.2
            )
        ]

        node.apply(segments: segments)

        let shapeNodes = node.children.compactMap { $0 as? SKShapeNode }
        XCTAssertEqual(node.children.count, 4)
        XCTAssertEqual(shapeNodes.count, 3)
        XCTAssertTrue(shapeNodes.allSatisfy { $0.path != nil })
    }

    func testResetClearsContinuousTrailPaths() {
        let node = FlameTrailEffectNode(theme: .darkTacticalRadar)
        node.apply(segments: [
            FlameTrailSegment(
                id: 1,
                position: .zero,
                radius: 16,
                timeRemaining: 1,
                lifetime: 1
            )
        ])

        node.reset()

        let shapeNodes = node.children.compactMap { $0 as? SKShapeNode }
        XCTAssertEqual(shapeNodes.count, 3)
        XCTAssertTrue(shapeNodes.allSatisfy { $0.path == nil })
    }
}
