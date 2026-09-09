import CoreGraphics
import Foundation

struct GravityWellState {
    let activation: WeaponActivation
    let center: CGPoint
    let pullRadius: CGFloat
    let pullDuration: TimeInterval
    let clearRadius: CGFloat
    var activationDelayRemaining: TimeInterval
    var timeRemaining: TimeInterval

    init(
        center: CGPoint,
        timeRemaining: TimeInterval,
        activationDelayRemaining: TimeInterval = 0,
        pullRadius: CGFloat = StartingWeaponConfiguration().gravityWellRadius,
        pullDuration: TimeInterval = StartingWeaponConfiguration().gravityWellPullDuration,
        clearRadius: CGFloat = StartingWeaponConfiguration().gravityWellClearRadius,
        activation: WeaponActivation = WeaponActivation(kind: .gravityWell)
    ) {
        self.activation = activation
        self.center = center
        self.pullRadius = WeaponRuntimeSafetyLimits.distance(pullRadius)
        self.pullDuration = WeaponRuntimeSafetyLimits.duration(pullDuration)
        self.clearRadius = WeaponRuntimeSafetyLimits.distance(clearRadius)
        self.activationDelayRemaining = WeaponRuntimeSafetyLimits.duration(activationDelayRemaining)
        self.timeRemaining = WeaponRuntimeSafetyLimits.duration(timeRemaining)
    }

    var totalTimeRemaining: TimeInterval {
        activationDelayRemaining + timeRemaining
    }

    var isComplete: Bool {
        activationDelayRemaining == 0 && timeRemaining == 0
    }

    mutating func consumePullDelta(deltaTime: TimeInterval) -> TimeInterval {
        var remainingDelta = deltaTime.isFinite ? max(0, deltaTime) : 0

        if activationDelayRemaining > 0 {
            let delayDelta = min(activationDelayRemaining, remainingDelta)
            activationDelayRemaining -= delayDelta
            remainingDelta -= delayDelta
        }

        let pullDelta = min(timeRemaining, remainingDelta)
        timeRemaining -= pullDelta
        return pullDelta
    }

    func pullTargets(enemies: [ArenaEnemy]) -> Set<Int> {
        let field = CollisionCircle(center: center, radius: pullRadius)
        return Set(enemies.filter { field.intersects($0.collisionCircle) }.map(\.id))
    }

    func collapseTargets(enemies: [ArenaEnemy], previousPositions: [Int: CGPoint] = [:]) -> Set<Int> {
        let core = CollisionCircle(center: center, radius: clearRadius)
        return Set(enemies.filter { enemy in
            core.intersects(enemy.collisionCircle)
                || enemy.collisionCircle.firstIntersectionTimeDuringMovement(
                    from: previousPositions[enemy.id] ?? enemy.position,
                    with: core,
                    movingFrom: center
                ) != nil
        }.map(\.id))
    }
}
