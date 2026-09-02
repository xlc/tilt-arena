import XCTest
@testable import TiltArena

final class ArenaDiagnosticAccumulatorTests: XCTestCase {
    func testHeartbeatReturnsAndResetsOneCompleteWindow() {
        var accumulator = ArenaDiagnosticAccumulator()
        accumulator.recordSpawn(count: 3)
        accumulator.recordSpawnCorrections(count: 2)

        let heartbeat = accumulator.recordFrame(duration: 10)

        XCTAssertEqual(heartbeat?.framesPerSecond, 0.1)
        XCTAssertEqual(heartbeat?.longFrameCount, 1)
        XCTAssertEqual(heartbeat?.maximumFrameInterval, 10)
        XCTAssertEqual(heartbeat?.spawnedEnemyCount, 3)
        XCTAssertEqual(heartbeat?.spawnRuntimeCorrectionCount, 2)
        XCTAssertNil(accumulator.recordFrame(duration: 1))
    }

    func testInvalidFrameReportIsDeduplicatedUntilRecovery() {
        var accumulator = ArenaDiagnosticAccumulator()

        XCTAssertTrue(accumulator.markInvalidFrameTimeReported())
        XCTAssertFalse(accumulator.markInvalidFrameTimeReported())
        XCTAssertTrue(accumulator.consumeFrameTimeRecovery())
        XCTAssertFalse(accumulator.consumeFrameTimeRecovery())
        XCTAssertTrue(accumulator.markInvalidFrameTimeReported())
    }
}
