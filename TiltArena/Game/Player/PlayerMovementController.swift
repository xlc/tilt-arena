import CoreGraphics
import Foundation

struct PlayerMovementConfiguration: Equatable {
    var visualRadius: CGFloat = 12
    var borderInset: CGFloat = 18
    var arenaCrossingDuration: TimeInterval = 2.5

    func maximumSpeed(in arenaSize: CGSize) -> CGFloat {
        maximumSpeed(in: CGRect(origin: .zero, size: arenaSize))
    }

    func maximumSpeed(in arenaBounds: CGRect) -> CGFloat {
        playableRect(in: arenaBounds).width / CGFloat(max(0.001, arenaCrossingDuration))
    }

    func playableRect(in arenaSize: CGSize) -> CGRect {
        playableRect(in: CGRect(origin: .zero, size: arenaSize))
    }

    func playableRect(in arenaBounds: CGRect) -> CGRect {
        let inset = borderInset + visualRadius
        let width = max(0, arenaBounds.width - inset * 2)
        let height = max(0, arenaBounds.height - inset * 2)

        return CGRect(
            x: arenaBounds.minX + inset,
            y: arenaBounds.minY + inset,
            width: width,
            height: height
        )
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
        reset(in: CGRect(origin: .zero, size: arenaSize))
    }

    mutating func reset(in arenaBounds: CGRect) -> PlayerMovementState {
        let rect = configuration.playableRect(in: arenaBounds)
        state = PlayerMovementState(
            position: CGPoint(x: rect.midX, y: rect.midY),
            velocity: .zero
        )
        return state
    }

    mutating func update(input: CGVector, deltaTime: TimeInterval, arenaSize: CGSize) -> PlayerMovementState {
        update(input: input, deltaTime: deltaTime, arenaBounds: CGRect(origin: .zero, size: arenaSize))
    }

    mutating func update(input: CGVector, deltaTime: TimeInterval, arenaBounds: CGRect) -> PlayerMovementState {
        update(input: input, deltaTime: deltaTime, arenaBounds: arenaBounds, speedMultiplier: 1)
    }

    mutating func update(
        input: CGVector,
        deltaTime: TimeInterval,
        arenaBounds: CGRect,
        speedMultiplier: CGFloat
    ) -> PlayerMovementState {
        let clampedInput = input.clamped(toMaximumLength: 1)
        let maximumSpeed = configuration.maximumSpeed(in: arenaBounds) * max(0, speedMultiplier)
        let velocity = CGVector(
            dx: clampedInput.dx * maximumSpeed,
            dy: clampedInput.dy * maximumSpeed
        )
        let proposedPosition = CGPoint(
            x: state.position.x + velocity.dx * CGFloat(max(0, deltaTime)),
            y: state.position.y + velocity.dy * CGFloat(max(0, deltaTime))
        )

        state = PlayerMovementState(
            position: clampedPosition(proposedPosition, in: arenaBounds),
            velocity: velocity
        )

        return state
    }

    mutating func dash(direction: CGVector, distance: CGFloat, arenaSize: CGSize) -> PlayerMovementState {
        dash(direction: direction, distance: distance, arenaBounds: CGRect(origin: .zero, size: arenaSize))
    }

    mutating func dash(direction: CGVector, distance: CGFloat, arenaBounds: CGRect) -> PlayerMovementState {
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
        let maximumSpeed = configuration.maximumSpeed(in: arenaBounds)

        state = PlayerMovementState(
            position: clampedPosition(proposedPosition, in: arenaBounds),
            velocity: CGVector(
                dx: dashDirection.dx * maximumSpeed,
                dy: dashDirection.dy * maximumSpeed
            )
        )

        return state
    }

    mutating func clampToArena(_ arenaSize: CGSize) -> PlayerMovementState {
        clampToArena(CGRect(origin: .zero, size: arenaSize))
    }

    mutating func clampToArena(_ arenaBounds: CGRect) -> PlayerMovementState {
        state = PlayerMovementState(
            position: clampedPosition(state.position, in: arenaBounds),
            velocity: state.velocity
        )
        return state
    }

    func clampedPosition(_ position: CGPoint, in arenaSize: CGSize) -> CGPoint {
        clampedPosition(position, in: CGRect(origin: .zero, size: arenaSize))
    }

    func clampedPosition(_ position: CGPoint, in arenaBounds: CGRect) -> CGPoint {
        let rect = configuration.playableRect(in: arenaBounds)

        guard rect.width > 0, rect.height > 0 else {
            return CGPoint(x: arenaBounds.midX, y: arenaBounds.midY)
        }

        return CGPoint(
            x: min(rect.maxX, max(rect.minX, position.x)),
            y: min(rect.maxY, max(rect.minY, position.y))
        )
    }
}
