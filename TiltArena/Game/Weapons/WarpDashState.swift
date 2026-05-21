import CoreGraphics

struct WarpDashState {
    private let minimumDirectionMagnitude: CGFloat = 0.05
    private(set) var lastDirection = CGVector(dx: 0, dy: 1)

    mutating func reset() {
        lastDirection = CGVector(dx: 0, dy: 1)
    }

    mutating func record(input: CGVector) {
        guard input.length >= minimumDirectionMagnitude else {
            return
        }

        lastDirection = input.normalized
    }

    func resolvedDirection() -> CGVector {
        guard lastDirection.length > 0 else {
            return CGVector(dx: 0, dy: 1)
        }

        return lastDirection.normalized
    }
}
