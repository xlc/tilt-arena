import CoreGraphics
import Foundation

struct ReadyStartHoldConfiguration: Equatable {
    static let defaultRequiredDuration: TimeInterval = 3
    static let defaultStartCircleRadius: CGFloat = 58
    static let maximumRequiredDuration: TimeInterval = 10
    static let maximumStartCircleRadius: CGFloat = 512

    var requiredDuration: TimeInterval = Self.defaultRequiredDuration
    var startCircleRadius: CGFloat = Self.defaultStartCircleRadius

    var effectiveRequiredDuration: TimeInterval {
        Self.resolvedRequiredDuration(requiredDuration)
    }

    var effectiveStartCircleRadius: CGFloat {
        guard startCircleRadius.isFinite else {
            return Self.defaultStartCircleRadius
        }

        return min(Self.maximumStartCircleRadius, max(0, startCircleRadius))
    }

    static func resolvedRequiredDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else {
            return Self.defaultRequiredDuration
        }

        return min(maximumRequiredDuration, max(0, duration))
    }
}

struct ReadyStartHoldState: Equatable {
    var elapsed: TimeInterval = 0
    var isInsideCircle = false
    var didComplete = false

    func progressFraction(requiredDuration: TimeInterval) -> Double {
        let duration = ReadyStartHoldConfiguration.resolvedRequiredDuration(requiredDuration)
        guard duration > 0 else {
            return 1
        }

        let finiteElapsed = elapsed.isFinite ? max(0, elapsed) : 0
        return min(1, finiteElapsed / duration)
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
        guard playerPosition.isFinite, startPoint.isFinite else {
            state = ReadyStartHoldState()
            return state
        }

        let radius = configuration.effectiveStartCircleRadius
        let dx = playerPosition.x - startPoint.x
        let dy = playerPosition.y - startPoint.y
        let squaredDistance = dx * dx + dy * dy
        let isInside = squaredDistance.isFinite && squaredDistance <= radius * radius

        guard isInside else {
            state = ReadyStartHoldState(elapsed: 0, isInsideCircle: false, didComplete: false)
            return state
        }

        let requiredDuration = configuration.effectiveRequiredDuration
        let previousElapsed = state.elapsed.isFinite
            ? min(requiredDuration, max(0, state.elapsed))
            : 0
        let finiteDelta = deltaTime.isFinite ? max(0, deltaTime) : 0
        let elapsed = min(requiredDuration, previousElapsed + min(requiredDuration, finiteDelta))
        state = ReadyStartHoldState(
            elapsed: elapsed,
            isInsideCircle: true,
            didComplete: elapsed >= requiredDuration
        )
        return state
    }
}
