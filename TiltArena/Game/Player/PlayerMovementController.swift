import CoreGraphics
import Foundation

struct PlayerMovementConfiguration: Equatable {
    private static let defaultArenaCrossingDuration: TimeInterval = 2.5

    var visualRadius: CGFloat = 12
    var borderInset: CGFloat = 18
    var arenaCrossingDuration: TimeInterval = Self.defaultArenaCrossingDuration

    func maximumSpeed(in arenaBounds: CGRect) -> CGFloat {
        let width = playableRect(in: arenaBounds).width
        let crossingDuration = arenaCrossingDuration.isFinite
            ? max(0.001, arenaCrossingDuration)
            : Self.defaultArenaCrossingDuration
        let speed = width / CGFloat(crossingDuration)
        return speed.isFinite ? max(0, speed) : 0
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
    static let maximumSafeSpeed: CGFloat = 10_000

    var configuration = PlayerMovementConfiguration()
    private(set) var state = PlayerMovementState(position: .zero, velocity: .zero)

    mutating func reset(in arenaSize: CGSize) -> PlayerMovementState {
        reset(in: CGRect(origin: .zero, size: arenaSize))
    }

    mutating func reset(in arenaBounds: CGRect) -> PlayerMovementState {
        let rect = configuration.playableRect(in: arenaBounds)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        state = PlayerMovementState(
            position: center.isFinite ? center : .zero,
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
        advance(
            input: input,
            deltaTime: deltaTime,
            arenaBounds: arenaBounds,
            speedMultiplier: speedMultiplier,
            usesFixedSpeed: false
        )
    }

    mutating func updateWithFixedSpeed(
        input: CGVector,
        deltaTime: TimeInterval,
        arenaBounds: CGRect,
        speedMultiplier: CGFloat
    ) -> PlayerMovementState {
        advance(
            input: input,
            deltaTime: deltaTime,
            arenaBounds: arenaBounds,
            speedMultiplier: speedMultiplier,
            usesFixedSpeed: true
        )
    }

    private mutating func advance(
        input: CGVector,
        deltaTime: TimeInterval,
        arenaBounds: CGRect,
        speedMultiplier: CGFloat,
        usesFixedSpeed: Bool
    ) -> PlayerMovementState {
        let clampedInput = (input.isFinite ? input : .zero).clamped(toMaximumLength: 1)
        let direction = usesFixedSpeed ? clampedInput.normalized : clampedInput
        let maximumSpeed = resolvedMaximumSpeed(in: arenaBounds, speedMultiplier: speedMultiplier)
        let elapsedTime = deltaTime.isFinite ? max(0, deltaTime) : 0
        let velocity = safeVelocity(direction: direction, speed: maximumSpeed)
        let proposedPosition = CGPoint(
            x: state.position.x + velocity.dx * CGFloat(elapsedTime),
            y: state.position.y + velocity.dy * CGFloat(elapsedTime)
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
        guard direction.isFinite, direction.length > 0 else {
            return state
        }

        let clampedDistance = distance.isFinite ? max(0, distance) : 0
        guard clampedDistance > 0 else {
            return state
        }

        let dashDirection = direction.normalized
        let proposedPosition = CGPoint(
            x: state.position.x + dashDirection.dx * clampedDistance,
            y: state.position.y + dashDirection.dy * clampedDistance
        )
        let maximumSpeed = resolvedMaximumSpeed(in: arenaBounds, speedMultiplier: 1)

        state = PlayerMovementState(
            position: clampedPosition(proposedPosition, in: arenaBounds),
            velocity: safeVelocity(direction: dashDirection, speed: maximumSpeed)
        )

        return state
    }

    mutating func clampToArena(_ arenaBounds: CGRect) -> PlayerMovementState {
        state = PlayerMovementState(
            position: clampedPosition(state.position, in: arenaBounds),
            velocity: state.velocity.isFinite
                ? state.velocity.clamped(toMaximumLength: Self.maximumSafeSpeed)
                : .zero
        )
        return state
    }

    func clampedPosition(_ position: CGPoint, in arenaBounds: CGRect) -> CGPoint {
        let rect = configuration.playableRect(in: arenaBounds)
        let arenaCenter = CGPoint(
            x: arenaBounds.midX.isFinite ? arenaBounds.midX : 0,
            y: arenaBounds.midY.isFinite ? arenaBounds.midY : 0
        )

        guard
            rect.isFinite,
            rect.width > 0,
            rect.height > 0
        else {
            return arenaCenter
        }

        guard position.isFinite else {
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        return CGPoint(
            x: min(rect.maxX, max(rect.minX, position.x)),
            y: min(rect.maxY, max(rect.minY, position.y))
        )
    }

    private func resolvedMaximumSpeed(in arenaBounds: CGRect, speedMultiplier: CGFloat) -> CGFloat {
        let baseSpeed = configuration.maximumSpeed(in: arenaBounds)
        let multiplier = speedMultiplier.isFinite ? max(0, speedMultiplier) : 1
        guard baseSpeed > 0, multiplier > 0 else {
            return 0
        }

        guard baseSpeed <= Self.maximumSafeSpeed / multiplier else {
            return Self.maximumSafeSpeed
        }

        return min(Self.maximumSafeSpeed, baseSpeed * multiplier)
    }

    private func safeVelocity(direction: CGVector, speed: CGFloat) -> CGVector {
        guard direction.isFinite, speed.isFinite, speed >= 0 else {
            return .zero
        }

        let velocity = CGVector(
            dx: direction.dx * speed,
            dy: direction.dy * speed
        )
        return velocity.isFinite
            ? velocity.clamped(toMaximumLength: Self.maximumSafeSpeed)
            : .zero
    }
}
