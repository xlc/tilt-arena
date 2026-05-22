import CoreGraphics
import Foundation

struct DeathReplaySample: Equatable {
    let time: TimeInterval
    let position: CGPoint
}

struct DeathReplayTrace: Equatable {
    var duration: TimeInterval = 2
    private(set) var samples: [DeathReplaySample] = []

    init(duration: TimeInterval = 2) {
        self.duration = duration
    }

    mutating func reset() {
        samples.removeAll()
    }

    mutating func record(time: TimeInterval, position: CGPoint) {
        samples.append(DeathReplaySample(time: time, position: position))
        prune(through: time)
    }

    mutating func prune(through currentTime: TimeInterval) {
        let minimumTime = currentTime - max(0, duration)
        samples.removeAll { $0.time < minimumTime }
    }
}

struct DeathCollisionSnapshot: Equatable {
    let playerPosition: CGPoint
    let enemyPosition: CGPoint
    let enemyRadius: CGFloat
}
