import CoreGraphics
import Foundation

struct GravityWellState {
    let activation: WeaponActivation
    let center: CGPoint
    let enemyIDs: Set<Int>
    let pullRadius: CGFloat
    let pullDuration: TimeInterval
    let clearRadius: CGFloat
    var activationDelayRemaining: TimeInterval
    var timeRemaining: TimeInterval

    init(
        center: CGPoint,
        enemyIDs: Set<Int>,
        timeRemaining: TimeInterval,
        activationDelayRemaining: TimeInterval = 0,
        pullRadius: CGFloat = StartingWeaponConfiguration().gravityWellRadius,
        pullDuration: TimeInterval = StartingWeaponConfiguration().gravityWellPullDuration,
        clearRadius: CGFloat = StartingWeaponConfiguration().gravityWellClearRadius,
        activation: WeaponActivation = WeaponActivation(kind: .gravityWell)
    ) {
        self.activation = activation
        self.center = center
        self.enemyIDs = enemyIDs
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

    func collapseTargets(enemies: [ArenaEnemy]) -> Set<Int> {
        let clearCircle = CollisionCircle(center: center, radius: max(0, clearRadius))
        return Set(
            enemies
                .filter { enemyIDs.contains($0.id) && clearCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )
    }
}
