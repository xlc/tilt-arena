import CoreGraphics

struct AimDirectionState {
    private static let defaultDirection = CGVector(dx: 0, dy: 1)
    private let minimumDirectionMagnitude: CGFloat = 0.05
    private(set) var lastDirection = Self.defaultDirection

    mutating func reset() {
        lastDirection = Self.defaultDirection
    }

    mutating func record(input: CGVector) {
        let length = hypot(input.dx, input.dy)
        guard input.isFinite,
              length.isFinite,
              length >= minimumDirectionMagnitude else {
            return
        }

        lastDirection = CGVector(dx: input.dx / length, dy: input.dy / length)
    }

    func resolvedDirection() -> CGVector {
        let length = hypot(lastDirection.dx, lastDirection.dy)
        guard lastDirection.isFinite, length.isFinite,
              length > 0 else {
            return Self.defaultDirection
        }

        return lastDirection.normalized(or: Self.defaultDirection)
    }
}
