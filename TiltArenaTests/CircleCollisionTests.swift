import CoreGraphics
import XCTest
@testable import TiltArena

final class CircleCollisionTests: XCTestCase {
    func testContinuousCollisionDetectsCrossingPathsWhenEndpointsMiss() {
        let first = CollisionCircle(center: CGPoint(x: 10, y: 0), radius: 1)
        let second = CollisionCircle(center: CGPoint(x: 0, y: -10), radius: 1)
        let firstStart = CGPoint(x: -10, y: 0)
        let secondStart = CGPoint(x: 0, y: 10)

        XCTAssertFalse(CollisionCircle(center: firstStart, radius: first.radius).intersects(
            CollisionCircle(center: secondStart, radius: second.radius)
        ))
        XCTAssertFalse(first.intersects(second))
        XCTAssertNotNil(first.firstIntersectionTimeDuringMovement(
            from: firstStart,
            with: second,
            movingFrom: secondStart
        ))
    }

    func testContinuousCollisionReturnsFirstContactTime() throws {
        let moving = CollisionCircle(center: CGPoint(x: 10, y: 0), radius: 1)
        let stationary = CollisionCircle(center: .zero, radius: 1)

        let impactTime = try XCTUnwrap(moving.firstIntersectionTimeDuringMovement(
            from: CGPoint(x: -10, y: 0),
            with: stationary,
            movingFrom: .zero
        ))

        XCTAssertEqual(impactTime, 0.4, accuracy: 0.0001)
    }

    func testContinuousCollisionUsesBothMovementsAndCombinedRadii() {
        let first = CollisionCircle(center: CGPoint(x: 10, y: 0), radius: 2)
        let second = CollisionCircle(center: CGPoint(x: 0, y: 4.5), radius: 3)

        XCTAssertNotNil(first.firstIntersectionTimeDuringMovement(
            from: CGPoint(x: 0, y: 0),
            with: second,
            movingFrom: CGPoint(x: 10, y: 4.5)
        ))
    }

    func testContinuousCollisionHandlesZeroRelativeMovementAndExistingOverlap() {
        let first = CollisionCircle(center: CGPoint(x: 10, y: 0), radius: 1)
        let overlapping = CollisionCircle(center: CGPoint(x: 11.5, y: 0), radius: 1)
        let separated = CollisionCircle(center: CGPoint(x: 15, y: 0), radius: 1)

        XCTAssertNotNil(first.firstIntersectionTimeDuringMovement(
            from: CGPoint(x: 0, y: 0),
            with: overlapping,
            movingFrom: CGPoint(x: 1.5, y: 0)
        ))
        XCTAssertNil(first.firstIntersectionTimeDuringMovement(
            from: CGPoint(x: 0, y: 0),
            with: separated,
            movingFrom: CGPoint(x: 5, y: 0)
        ))
    }

    func testContinuousCollisionIgnoresContactsOutsideMovementSegment() {
        let stationary = CollisionCircle(center: .zero, radius: 1)
        let movingAway = CollisionCircle(center: CGPoint(x: 4, y: 0), radius: 1)
        let approaching = CollisionCircle(center: CGPoint(x: 3, y: 0), radius: 1)

        XCTAssertNil(stationary.firstIntersectionTimeDuringMovement(
            from: .zero,
            with: movingAway,
            movingFrom: CGPoint(x: 3, y: 0)
        ))
        XCTAssertNil(stationary.firstIntersectionTimeDuringMovement(
            from: .zero,
            with: approaching,
            movingFrom: CGPoint(x: 4, y: 0)
        ))
    }
}
