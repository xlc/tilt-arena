import CoreGraphics
import Foundation

enum PaddleTrapOrientation: Equatable {
    case horizontal
    case vertical
}

enum EnemyKind: Equatable {
    case chaser
    case formation
    case arrowRush
    case mine
    case hunter
    case paddleBar
    case paddlePuck
    case splitter
    case splitterChild
}

enum EnemyBehavior: Equatable {
    case chaser
    case formationLine(velocity: CGVector, formationID: Int)
    case arrowRush(velocity: CGVector)
    case mineDot
    case hunterDot(predictionLead: CGFloat, previousTarget: CGPoint?)
    case paddleTrapBar(
        trapID: Int,
        orientation: PaddleTrapOrientation,
        remainingLifetime: TimeInterval
    )
    case paddleTrapDot(trapID: Int, velocity: CGVector, bounds: CGRect, remainingLifetime: TimeInterval)
    case splitter
    case splitterChild
}

extension EnemyBehavior {
    var kind: EnemyKind {
        switch self {
        case .chaser:
            return .chaser
        case .formationLine:
            return .formation
        case .arrowRush:
            return .arrowRush
        case .mineDot:
            return .mine
        case .hunterDot:
            return .hunter
        case .paddleTrapBar:
            return .paddleBar
        case .paddleTrapDot:
            return .paddlePuck
        case .splitter:
            return .splitter
        case .splitterChild:
            return .splitterChild
        }
    }
}

struct ArenaEnemy: Equatable, Identifiable {
    let id: Int
    var position: CGPoint
    var radius: CGFloat
    var speed: CGFloat
    var speedRampPerSecond: CGFloat = 0
    var maximumSpeedMultiplier: CGFloat = 1
    private(set) var movementTime: TimeInterval = 0
    var behavior: EnemyBehavior = .chaser
    var frozenTimeRemaining: TimeInterval = 0
    var thawGraceTimeRemaining: TimeInterval = 0
    var thawGraceDuration: TimeInterval = 0
    var splitSpawnGraceTimeRemaining: TimeInterval = 0
    var playerCollisionGraceTimeRemaining: TimeInterval = 0

    var formationID: Int? {
        switch behavior {
        case .chaser, .arrowRush, .mineDot, .hunterDot, .paddleTrapBar, .paddleTrapDot, .splitter, .splitterChild:
            return nil
        case let .formationLine(_, formationID):
            return formationID
        }
    }

    var isLinearPatternEnemy: Bool {
        switch behavior {
        case .chaser, .mineDot, .hunterDot, .paddleTrapBar, .paddleTrapDot, .splitter, .splitterChild:
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

    var isSplitter: Bool {
        behavior == .splitter
    }

    var isSplitterChild: Bool {
        behavior == .splitterChild
    }

    var isSplitProtected: Bool {
        splitSpawnGraceTimeRemaining > 0
    }

    var isPlayerCollisionGraceActive: Bool {
        playerCollisionGraceTimeRemaining > 0
    }

    var paddleTrapID: Int? {
        switch behavior {
        case let .paddleTrapBar(trapID, _, _), let .paddleTrapDot(trapID, _, _, _):
            return trapID
        case .chaser, .formationLine, .arrowRush, .mineDot, .hunterDot, .splitter, .splitterChild:
            return nil
        }
    }

    var isExpired: Bool {
        switch behavior {
        case let .paddleTrapBar(_, _, remainingLifetime), let .paddleTrapDot(_, _, _, remainingLifetime):
            return remainingLifetime <= 0
        case .chaser, .formationLine, .arrowRush, .mineDot, .hunterDot, .splitter, .splitterChild:
            return false
        }
    }

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }

    var isFrozen: Bool {
        frozenTimeRemaining > 0
    }

    var isThawing: Bool {
        frozenTimeRemaining == 0 && thawGraceTimeRemaining > 0
    }

    var isShatterableFrozen: Bool {
        isFrozen || isThawing
    }

    var canDamagePlayer: Bool {
        !isShatterableFrozen && !isSplitProtected && !isPlayerCollisionGraceActive
    }

    mutating func freeze(duration: TimeInterval, thawGraceDuration: TimeInterval = 0) {
        let clampedDuration = max(0, duration)
        guard clampedDuration > 0 else {
            return
        }

        frozenTimeRemaining = max(frozenTimeRemaining, clampedDuration)
        self.thawGraceDuration = max(self.thawGraceDuration, max(0, thawGraceDuration))
        thawGraceTimeRemaining = 0
    }

    mutating func startPlayerCollisionGrace(duration: TimeInterval) {
        playerCollisionGraceTimeRemaining = max(playerCollisionGraceTimeRemaining, max(0, duration))
    }

    mutating func pullToward(_ target: CGPoint, distance: CGFloat) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let targetDistance = hypot(dx, dy)
        let clampedDistance = min(max(0, distance), targetDistance)

        guard targetDistance > 0, clampedDistance > 0 else {
            return
        }

        position = CGPoint(
            x: position.x + dx / targetDistance * clampedDistance,
            y: position.y + dy / targetDistance * clampedDistance
        )
    }

    mutating func pushAway(from source: CGPoint, distance: CGFloat) {
        var dx = position.x - source.x
        var dy = position.y - source.y
        var sourceDistance = hypot(dx, dy)

        if sourceDistance == 0 {
            dx = 1
            dy = 0
            sourceDistance = 1
        }

        let clampedDistance = max(0, distance)
        guard clampedDistance > 0 else {
            return
        }

        position = CGPoint(
            x: position.x + dx / sourceDistance * clampedDistance,
            y: position.y + dy / sourceDistance * clampedDistance
        )
    }

    mutating func advance(
        toward target: CGPoint,
        deltaTime: TimeInterval,
        externalSpeedMultiplier: CGFloat = 1,
        maximumSpeed: CGFloat? = nil
    ) {
        let clampedTime = max(0, deltaTime)
        let clampedDelta = CGFloat(clampedTime)

        consumePlayerCollisionGrace(deltaTime: clampedTime)
        advancePaddleTrapLifetime(deltaTime: clampedTime)

        if consumeMovementPause(deltaTime: clampedTime) {
            if case let .hunterDot(predictionLead, _) = behavior {
                behavior = .hunterDot(predictionLead: predictionLead, previousTarget: target)
            }
            return
        }

        let effectiveSpeedMultiplier = movementSpeedMultiplier * max(0, externalSpeedMultiplier)
        let movementMultiplier = cappedSpeedMultiplier(
            for: behavior,
            speedMultiplier: effectiveSpeedMultiplier,
            maximumSpeed: maximumSpeed
        )

        switch behavior {
        case .chaser, .splitter, .splitterChild:
            advanceChaser(toward: target, deltaTime: clampedDelta, speedMultiplier: movementMultiplier)
            recordMovementTime(clampedTime)
        case let .arrowRush(velocity):
            advanceLinearly(velocity: velocity, deltaTime: clampedDelta, speedMultiplier: movementMultiplier)
            recordMovementTime(clampedTime)
        case let .formationLine(velocity, _):
            advanceLinearly(velocity: velocity, deltaTime: clampedDelta, speedMultiplier: movementMultiplier)
            recordMovementTime(clampedTime)
        case .mineDot:
            return
        case let .hunterDot(predictionLead, previousTarget):
            advanceHunter(
                toward: target,
                predictionLead: predictionLead,
                previousTarget: previousTarget,
                deltaTime: clampedDelta,
                speedMultiplier: movementMultiplier
            )
            recordMovementTime(clampedTime)
        case .paddleTrapBar:
            return
        case let .paddleTrapDot(trapID, velocity, bounds, remainingLifetime):
            advancePaddleTrapDot(
                trapID: trapID,
                velocity: velocity,
                bounds: bounds,
                remainingLifetime: remainingLifetime,
                deltaTime: clampedDelta,
                speedMultiplier: movementMultiplier
            )
            recordMovementTime(clampedTime)
        }
    }

    private mutating func consumePlayerCollisionGrace(deltaTime: TimeInterval) {
        guard isPlayerCollisionGraceActive else {
            return
        }

        playerCollisionGraceTimeRemaining = max(0, playerCollisionGraceTimeRemaining - deltaTime)
    }

    private mutating func advancePaddleTrapLifetime(deltaTime: TimeInterval) {
        switch behavior {
        case let .paddleTrapBar(trapID, orientation, remainingLifetime):
            behavior = .paddleTrapBar(
                trapID: trapID,
                orientation: orientation,
                remainingLifetime: remainingLifetime - deltaTime
            )
        case let .paddleTrapDot(trapID, velocity, bounds, remainingLifetime):
            behavior = .paddleTrapDot(
                trapID: trapID,
                velocity: velocity,
                bounds: bounds,
                remainingLifetime: remainingLifetime - deltaTime
            )
        case .chaser, .formationLine, .arrowRush, .mineDot, .hunterDot, .splitter, .splitterChild:
            return
        }
    }

    private mutating func consumeMovementPause(deltaTime: TimeInterval) -> Bool {
        if isFrozen {
            frozenTimeRemaining = max(0, frozenTimeRemaining - deltaTime)
            if frozenTimeRemaining == 0 {
                thawGraceTimeRemaining = max(thawGraceTimeRemaining, thawGraceDuration)
            }
            return true
        }

        if isThawing {
            thawGraceTimeRemaining = max(0, thawGraceTimeRemaining - deltaTime)
            return true
        }

        if isSplitProtected {
            splitSpawnGraceTimeRemaining = max(0, splitSpawnGraceTimeRemaining - deltaTime)
            return true
        }

        return false
    }

    private var movementSpeedMultiplier: CGFloat {
        let ramp = max(0, speedRampPerSecond)
        let maximum = max(1, maximumSpeedMultiplier)
        return min(maximum, 1 + CGFloat(movementTime) * ramp)
    }

    private mutating func recordMovementTime(_ deltaTime: TimeInterval) {
        movementTime += max(0, deltaTime)
    }

    private func cappedSpeedMultiplier(
        for behavior: EnemyBehavior,
        speedMultiplier: CGFloat,
        maximumSpeed: CGFloat?
    ) -> CGFloat {
        switch behavior {
        case let .arrowRush(velocity),
             let .formationLine(velocity, _),
             let .paddleTrapDot(_, velocity, _, _):
            return cappedSpeedMultiplier(
                baseSpeed: velocity.length,
                speedMultiplier: speedMultiplier,
                maximumSpeed: maximumSpeed
            )
        case .chaser, .hunterDot, .splitter, .splitterChild:
            return cappedSpeedMultiplier(
                baseSpeed: speed,
                speedMultiplier: speedMultiplier,
                maximumSpeed: maximumSpeed
            )
        case .mineDot, .paddleTrapBar:
            return max(0, speedMultiplier)
        }
    }

    private func cappedSpeedMultiplier(
        baseSpeed: CGFloat,
        speedMultiplier: CGFloat,
        maximumSpeed: CGFloat?
    ) -> CGFloat {
        let clampedMultiplier = max(0, speedMultiplier)

        guard let maximumSpeed else {
            return clampedMultiplier
        }

        let baseSpeed = max(0, baseSpeed)
        guard baseSpeed > 0 else {
            return clampedMultiplier
        }

        return min(clampedMultiplier, max(0, maximumSpeed) / baseSpeed)
    }

    private mutating func advanceLinearly(velocity: CGVector, deltaTime: CGFloat, speedMultiplier: CGFloat) {
        position = CGPoint(
            x: position.x + velocity.dx * speedMultiplier * deltaTime,
            y: position.y + velocity.dy * speedMultiplier * deltaTime
        )
    }

    private mutating func advanceChaser(toward target: CGPoint, deltaTime: CGFloat, speedMultiplier: CGFloat) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = hypot(dx, dy)

        guard distance > 0 else {
            return
        }

        let movementDistance = max(0, speed) * speedMultiplier * deltaTime
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
        deltaTime: CGFloat,
        speedMultiplier: CGFloat
    ) {
        let predictedTarget: CGPoint

        if let previousTarget, deltaTime > 0 {
            let velocityProjectionScale = max(0, predictionLead) / deltaTime
            predictedTarget = CGPoint(
                x: target.x + (target.x - previousTarget.x) * velocityProjectionScale,
                y: target.y + (target.y - previousTarget.y) * velocityProjectionScale
            )
        } else {
            predictedTarget = target
        }

        advanceChaser(toward: predictedTarget, deltaTime: deltaTime, speedMultiplier: speedMultiplier)
        behavior = .hunterDot(predictionLead: predictionLead, previousTarget: target)
    }

    private mutating func advancePaddleTrapDot(
        trapID: Int,
        velocity: CGVector,
        bounds: CGRect,
        remainingLifetime: TimeInterval,
        deltaTime: CGFloat,
        speedMultiplier: CGFloat
    ) {
        var nextVelocity = velocity
        var nextPosition = CGPoint(
            x: position.x + velocity.dx * speedMultiplier * deltaTime,
            y: position.y + velocity.dy * speedMultiplier * deltaTime
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
            remainingLifetime: remainingLifetime
        )
    }
}
