import Foundation

struct ArenaDiagnosticHeartbeat: Equatable {
    let framesPerSecond: Double
    let longFrameCount: Int
    let maximumFrameInterval: TimeInterval
    let spawnedEnemyCount: Int
    let spawnRuntimeCorrectionCount: Int
}

struct ArenaDiagnosticAccumulator {
    private static let heartbeatInterval: TimeInterval = 10
    private static let longFrameThreshold: TimeInterval = 0.1

    private var elapsed: TimeInterval = 0
    private var frameCount = 0
    private var longFrameCount = 0
    private var maximumFrameInterval: TimeInterval = 0
    private var spawnedEnemyCount = 0
    private var spawnRuntimeCorrectionCount = 0
    private var hasReportedInvalidFrameTime = false

    mutating func recordFrame(duration: TimeInterval) -> ArenaDiagnosticHeartbeat? {
        elapsed += duration
        frameCount += 1
        maximumFrameInterval = max(maximumFrameInterval, duration)
        if duration >= Self.longFrameThreshold {
            longFrameCount += 1
        }

        guard elapsed >= Self.heartbeatInterval else {
            return nil
        }

        let heartbeat = ArenaDiagnosticHeartbeat(
            framesPerSecond: elapsed > 0 ? Double(frameCount) / elapsed : 0,
            longFrameCount: longFrameCount,
            maximumFrameInterval: maximumFrameInterval,
            spawnedEnemyCount: spawnedEnemyCount,
            spawnRuntimeCorrectionCount: spawnRuntimeCorrectionCount
        )
        resetHeartbeatWindow()
        return heartbeat
    }

    mutating func recordSpawn(count: Int) {
        spawnedEnemyCount = saturatedSum(spawnedEnemyCount, max(0, count))
    }

    mutating func recordSpawnCorrections(count: Int) {
        spawnRuntimeCorrectionCount = saturatedSum(spawnRuntimeCorrectionCount, max(0, count))
    }

    mutating func markInvalidFrameTimeReported() -> Bool {
        guard !hasReportedInvalidFrameTime else {
            return false
        }
        hasReportedInvalidFrameTime = true
        return true
    }

    mutating func consumeFrameTimeRecovery() -> Bool {
        guard hasReportedInvalidFrameTime else {
            return false
        }
        hasReportedInvalidFrameTime = false
        return true
    }

    private mutating func resetHeartbeatWindow() {
        elapsed = 0
        frameCount = 0
        longFrameCount = 0
        maximumFrameInterval = 0
        spawnedEnemyCount = 0
        spawnRuntimeCorrectionCount = 0
    }

    private func saturatedSum(_ value: Int, _ increment: Int) -> Int {
        let (result, overflow) = value.addingReportingOverflow(increment)
        return overflow ? Int.max : result
    }
}
