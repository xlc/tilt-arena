import CoreGraphics
import Foundation

struct GravityWellState {
    let center: CGPoint
    let enemyIDs: Set<Int>
    var timeRemaining: TimeInterval

    func collapseTargets(enemies: [ArenaEnemy], clearRadius: CGFloat) -> Set<Int> {
        let clearCircle = CollisionCircle(center: center, radius: max(0, clearRadius))
        return Set(
            enemies
                .filter { enemyIDs.contains($0.id) && clearCircle.intersects($0.collisionCircle) }
                .map(\.id)
        )
    }
}
