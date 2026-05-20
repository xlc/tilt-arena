import CoreGraphics
import Foundation

enum EnemyBehavior: Equatable {
    case chaser
    case formationLine(velocity: CGVector, formationID: Int)
    case arrowRush(velocity: CGVector)
}

struct ArenaEnemy: Equatable, Identifiable {
    let id: Int
    var position: CGPoint
    var radius: CGFloat
    var speed: CGFloat
    var behavior: EnemyBehavior = .chaser

    var formationID: Int? {
        switch behavior {
        case .chaser, .arrowRush:
            return nil
        case let .formationLine(_, formationID):
            return formationID
        }
    }

    var isLinearPatternEnemy: Bool {
        switch behavior {
        case .chaser:
            return false
        case .formationLine, .arrowRush:
            return true
        }
    }

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }

    mutating func advance(toward target: CGPoint, deltaTime: TimeInterval) {
        let clampedDelta = CGFloat(max(0, deltaTime))

        switch behavior {
        case .chaser:
            advanceChaser(toward: target, deltaTime: clampedDelta)
        case let .arrowRush(velocity):
            advanceLinearly(velocity: velocity, deltaTime: clampedDelta)
        case let .formationLine(velocity, _):
            advanceLinearly(velocity: velocity, deltaTime: clampedDelta)
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
}
