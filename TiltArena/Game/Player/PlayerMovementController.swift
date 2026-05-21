import CoreGraphics
import Foundation

struct PlayerMovementConfiguration: Equatable {
    var visualRadius: CGFloat = 14
    var borderInset: CGFloat = 18
    var arenaCrossingDuration: TimeInterval = 2.5

    func maximumSpeed(in arenaSize: CGSize) -> CGFloat {
        playableRect(in: arenaSize).width / CGFloat(max(0.001, arenaCrossingDuration))
    }

    func playableRect(in arenaSize: CGSize) -> CGRect {
        let inset = borderInset + visualRadius
        let width = max(0, arenaSize.width - inset * 2)
        let height = max(0, arenaSize.height - inset * 2)

        return CGRect(x: inset, y: inset, width: width, height: height)
    }
}

struct PlayerMovementState: Equatable {
    var position: CGPoint
    var velocity: CGVector
}

struct PlayerMovementController {
    var configuration = PlayerMovementConfiguration()
    private(set) var state = PlayerMovementState(position: .zero, velocity: .zero)

    mutating func reset(in arenaSize: CGSize) -> PlayerMovementState {
        let rect = configuration.playableRect(in: arenaSize)
        state = PlayerMovementState(
            position: CGPoint(x: rect.midX, y: rect.midY),
            velocity: .zero
        )
        return state
    }

    mutating func update(input: CGVector, deltaTime: TimeInterval, arenaSize: CGSize) -> PlayerMovementState {
        let clampedInput = input.clamped(toMaximumLength: 1)
        let maximumSpeed = configuration.maximumSpeed(in: arenaSize)
        let velocity = CGVector(
            dx: clampedInput.dx * maximumSpeed,
            dy: clampedInput.dy * maximumSpeed
        )
        let proposedPosition = CGPoint(
            x: state.position.x + velocity.dx * CGFloat(max(0, deltaTime)),
            y: state.position.y + velocity.dy * CGFloat(max(0, deltaTime))
        )

        state = PlayerMovementState(
            position: clampedPosition(proposedPosition, in: arenaSize),
            velocity: velocity
        )

        return state
    }

    mutating func dash(direction: CGVector, distance: CGFloat, arenaSize: CGSize) -> PlayerMovementState {
        guard direction.length > 0 else {
            return state
        }

        let clampedDistance = max(0, distance)
        guard clampedDistance > 0 else {
            return state
        }

        let dashDirection = direction.normalized
        let proposedPosition = CGPoint(
            x: state.position.x + dashDirection.dx * clampedDistance,
            y: state.position.y + dashDirection.dy * clampedDistance
        )
        let maximumSpeed = configuration.maximumSpeed(in: arenaSize)

        state = PlayerMovementState(
            position: clampedPosition(proposedPosition, in: arenaSize),
            velocity: CGVector(
                dx: dashDirection.dx * maximumSpeed,
                dy: dashDirection.dy * maximumSpeed
            )
        )

        return state
    }

    mutating func clampToArena(_ arenaSize: CGSize) -> PlayerMovementState {
        state = PlayerMovementState(
            position: clampedPosition(state.position, in: arenaSize),
            velocity: state.velocity
        )
        return state
    }

    func clampedPosition(_ position: CGPoint, in arenaSize: CGSize) -> CGPoint {
        let rect = configuration.playableRect(in: arenaSize)

        guard rect.width > 0, rect.height > 0 else {
            return CGPoint(x: arenaSize.width / 2, y: arenaSize.height / 2)
        }

        return CGPoint(
            x: min(rect.maxX, max(rect.minX, position.x)),
            y: min(rect.maxY, max(rect.minY, position.y))
        )
    }
}
