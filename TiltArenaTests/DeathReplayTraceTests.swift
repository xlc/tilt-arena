import CoreGraphics
import XCTest
@testable import TiltArena

final class DeathReplayTraceTests: XCTestCase {
    func testTracePrunesSamplesOutsideReplayWindow() {
        var trace = DeathReplayTrace(duration: 2)

        trace.record(time: 0.0, position: CGPoint(x: 0, y: 0))
        trace.record(time: 1.0, position: CGPoint(x: 1, y: 1))
        trace.record(time: 2.1, position: CGPoint(x: 2, y: 2))

        XCTAssertEqual(
            trace.samples,
            [
                DeathReplaySample(time: 1.0, position: CGPoint(x: 1, y: 1)),
                DeathReplaySample(time: 2.1, position: CGPoint(x: 2, y: 2))
            ]
        )
    }

    func testTracePreservesSampleOrder() {
        var trace = DeathReplayTrace(duration: 2)

        trace.record(time: 3.0, position: CGPoint(x: 3, y: 3))
        trace.record(time: 3.5, position: CGPoint(x: 4, y: 4))
        trace.record(time: 4.0, position: CGPoint(x: 5, y: 5))

        XCTAssertEqual(
            trace.samples.map(\.position),
            [
                CGPoint(x: 3, y: 3),
                CGPoint(x: 4, y: 4),
                CGPoint(x: 5, y: 5)
            ]
        )
    }
}
