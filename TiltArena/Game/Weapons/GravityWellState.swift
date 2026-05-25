import CoreGraphics
import Foundation

struct GravityWellState {
    let center: CGPoint
    let enemyIDs: Set<Int>
    var activationDelayRemaining: TimeInterval
    var timeRemaining: TimeInterval

    init(
        center: CGPoint,
        enemyIDs: Set<Int>,
        timeRemaining: TimeInterval,
        activationDelayRemaining: TimeInterval = 0
    ) {
        self.center = center
        self.enemyIDs = enemyIDs
        self.activationDelayRemaining = max(0, activationDelayRemaining)
        self.timeRemaining = max(0, timeRemaining)
    }

    var totalTimeRemaining: TimeInterval {
        activationDelayRemaining + timeRemaining
    }

    var isComplete: Bool {
        activationDelayRemaining == 0 && timeRemaining == 0
    }

    mutating func consumePullDelta(deltaTime: TimeInterval) -> TimeInterval {
        var remainingDelta = max(0, deltaTime)

        if activationDelayRemaining > 0 {
            let delayDelta = min(activationDelayRemaining, remainingDelta)
            activationDelayRemaining -= delayDelta
            remainingDelta -= delayDelta
        }

        let pullDelta = min(timeRemaining, remainingDelta)
        timeRemaining -= pullDelta
        return pullDelta
    }

    func collapseTargets(enemies: [ArenaEnemy], clearRadius: CGFloat) -> Set<Int> {
        let clearCircle = CollisionCircle(center: center, radius: max(0, clearRadius))
        return Set(
            enemies
                .filter { enemyIDs.contains($0.id) && clearCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )
    }
}
