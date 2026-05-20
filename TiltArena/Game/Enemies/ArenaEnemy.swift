import CoreGraphics
import Foundation

enum EnemyBehavior: Equatable {
    case chaser
    case formationLine(velocity: CGVector, formationID: Int)
    case arrowRush(velocity: CGVector)
    case mineDot
    case hunterDot(predictionLead: CGFloat, previousTarget: CGPoint?)
    case paddleTrapBar(trapID: Int, remainingLifetime: TimeInterval)
    case paddleTrapDot(trapID: Int, velocity: CGVector, bounds: CGRect, remainingLifetime: TimeInterval)
}

struct ArenaEnemy: Equatable, Identifiable {
    let id: Int
    var position: CGPoint
    var radius: CGFloat
    var speed: CGFloat
    var behavior: EnemyBehavior = .chaser

    var formationID: Int? {
        switch behavior {
        case .chaser, .arrowRush, .mineDot, .hunterDot, .paddleTrapBar, .paddleTrapDot:
            return nil
        case let .formationLine(_, formationID):
            return formationID
        }
    }

    var isLinearPatternEnemy: Bool {
        switch behavior {
        case .chaser, .mineDot, .hunterDot, .paddleTrapBar, .paddleTrapDot:
            return false
        case .formationLine, .arrowRush:
            return true
        }
    }

    var isMineDot: Bool {
        behavior == .mineDot
    }

    var isHunterDot: Bool {
        guard case .hunterDot = behavior else {
            return false
        }

        return true
    }

    var isPaddleTrap: Bool {
        paddleTrapID != nil
    }

    var paddleTrapID: Int? {
        switch behavior {
        case let .paddleTrapBar(trapID, _), let .paddleTrapDot(trapID, _, _, _):
            return trapID
        case .chaser, .formationLine, .arrowRush, .mineDot, .hunterDot:
            return nil
        }
    }

    var isExpired: Bool {
        switch behavior {
        case let .paddleTrapBar(_, remainingLifetime), let .paddleTrapDot(_, _, _, remainingLifetime):
            return remainingLifetime <= 0
        case .chaser, .formationLine, .arrowRush, .mineDot, .hunterDot:
            return false
        }
    }

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }

    mutating func advance(toward target: CGPoint, deltaTime: TimeInterval) {
        let clampedTime = max(0, deltaTime)
        let clampedDelta = CGFloat(clampedTime)

        switch behavior {
        case .chaser:
            advanceChaser(toward: target, deltaTime: clampedDelta)
        case let .arrowRush(velocity):
            advanceLinearly(velocity: velocity, deltaTime: clampedDelta)
        case let .formationLine(velocity, _):
            advanceLinearly(velocity: velocity, deltaTime: clampedDelta)
        case .mineDot:
            return
        case let .hunterDot(predictionLead, previousTarget):
            advanceHunter(toward: target, predictionLead: predictionLead, previousTarget: previousTarget, deltaTime: clampedDelta)
        case let .paddleTrapBar(trapID, remainingLifetime):
            behavior = .paddleTrapBar(trapID: trapID, remainingLifetime: remainingLifetime - clampedTime)
        case let .paddleTrapDot(trapID, velocity, bounds, remainingLifetime):
            advancePaddleTrapDot(
                trapID: trapID,
                velocity: velocity,
                bounds: bounds,
                remainingLifetime: remainingLifetime,
                deltaTime: clampedDelta
            )
        }
    }

    private mutating func advanceLinearly(velocity: CGVector, deltaTime: CGFloat) {
        position = CGPoint(
            x: position.x + velocity.dx * deltaTime,
            y: position.y + velocity.dy * deltaTime
        )
    }

    private mutating func advanceChaser(toward target: CGPoint, deltaTime: CGFloat) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = hypot(dx, dy)

        guard distance > 0 else {
            return
        }

        let movementDistance = max(0, speed) * deltaTime
        guard movementDistance > 0 else {
            return
        }

        let step = min(distance, movementDistance)
        position = CGPoint(
            x: position.x + (dx / distance) * step,
            y: position.y + (dy / distance) * step
        )
    }

    private mutating func advanceHunter(
        toward target: CGPoint,
        predictionLead: CGFloat,
        previousTarget: CGPoint?,
        deltaTime: CGFloat
    ) {
        let predictedTarget: CGPoint

        if let previousTarget {
            predictedTarget = CGPoint(
                x: target.x + (target.x - previousTarget.x) * max(0, predictionLead),
                y: target.y + (target.y - previousTarget.y) * max(0, predictionLead)
            )
        } else {
            predictedTarget = target
        }

        advanceChaser(toward: predictedTarget, deltaTime: deltaTime)
        behavior = .hunterDot(predictionLead: predictionLead, previousTarget: target)
    }

    private mutating func advancePaddleTrapDot(
        trapID: Int,
        velocity: CGVector,
        bounds: CGRect,
        remainingLifetime: TimeInterval,
        deltaTime: CGFloat
    ) {
        var nextVelocity = velocity
        var nextPosition = CGPoint(
            x: position.x + velocity.dx * deltaTime,
            y: position.y + velocity.dy * deltaTime
        )

        if nextPosition.x < bounds.minX {
            nextPosition.x = bounds.minX
            nextVelocity.dx = abs(nextVelocity.dx)
        } else if nextPosition.x > bounds.maxX {
            nextPosition.x = bounds.maxX
            nextVelocity.dx = -abs(nextVelocity.dx)
        }

        if nextPosition.y < bounds.minY {
            nextPosition.y = bounds.minY
            nextVelocity.dy = abs(nextVelocity.dy)
        } else if nextPosition.y > bounds.maxY {
            nextPosition.y = bounds.maxY
            nextVelocity.dy = -abs(nextVelocity.dy)
        }

        position = nextPosition
        behavior = .paddleTrapDot(
            trapID: trapID,
            velocity: nextVelocity,
            bounds: bounds,
            remainingLifetime: remainingLifetime - TimeInterval(deltaTime)
        )
    }
}
