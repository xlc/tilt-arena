import CoreGraphics
import Foundation

struct DeathReplaySample: Equatable {
    let time: TimeInterval
    let position: CGPoint
}

struct DeathReplayTrace: Equatable {
    private static let maximumDuration: TimeInterval = 10
    private static let maximumSampleCount = 1_200

    var duration: TimeInterval = 2
    private(set) var samples: [DeathReplaySample] = []

    init(duration: TimeInterval = 2) {
        self.duration = duration
    }

    mutating func reset() {
        samples.removeAll()
    }

    mutating func record(time: TimeInterval, position: CGPoint) {
        guard time.isFinite, position.x.isFinite, position.y.isFinite else {
            return
        }
        if let latestTime = samples.last?.time, time < latestTime {
            samples.removeAll(keepingCapacity: true)
        }

        samples.append(DeathReplaySample(time: time, position: position))
        prune(through: time)
        if samples.count > Self.maximumSampleCount {
            samples.removeFirst(samples.count - Self.maximumSampleCount)
        }
    }

    mutating func prune(through currentTime: TimeInterval) {
        guard currentTime.isFinite else {
            return
        }

        let effectiveDuration = duration.isFinite
            ? min(Self.maximumDuration, max(0, duration))
            : 0
        let minimumTime = currentTime - effectiveDuration
        samples.removeAll { $0.time < minimumTime }
    }
}

struct DeathCollisionSnapshot: Equatable {
    let playerPosition: CGPoint
    let enemyPosition: CGPoint
    let enemyRadius: CGFloat
}
