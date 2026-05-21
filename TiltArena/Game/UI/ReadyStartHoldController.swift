import CoreGraphics
import Foundation

struct ReadyStartHoldConfiguration: Equatable {
    var requiredDuration: TimeInterval = 3
    var startCircleRadius: CGFloat = 58
}

struct ReadyStartHoldState: Equatable {
    var elapsed: TimeInterval = 0
    var isInsideCircle = false
    var didComplete = false

    func progressFraction(requiredDuration: TimeInterval) -> Double {
        guard requiredDuration > 0 else {
            return 1
        }

        return min(1, max(0, elapsed / requiredDuration))
    }
}

struct ReadyStartHoldController: Equatable {
    var configuration = ReadyStartHoldConfiguration()
    private(set) var state = ReadyStartHoldState()

    mutating func reset() {
        state = ReadyStartHoldState()
    }

    @discardableResult
    mutating func update(
        playerPosition: CGPoint,
        startPoint: CGPoint,
        deltaTime: TimeInterval
    ) -> ReadyStartHoldState {
        let radius = max(0, configuration.startCircleRadius)
        let dx = playerPosition.x - startPoint.x
        let dy = playerPosition.y - startPoint.y
        let isInside = dx * dx + dy * dy <= radius * radius

        guard isInside else {
            state = ReadyStartHoldState(elapsed: 0, isInsideCircle: false, didComplete: false)
            return state
        }

        let elapsed = state.elapsed + max(0, deltaTime)
        state = ReadyStartHoldState(
            elapsed: elapsed,
            isInsideCircle: true,
            didComplete: elapsed >= max(0, configuration.requiredDuration)
        )
        return state
    }
}
