import CoreGraphics
import Foundation

struct DecoyBeaconConfiguration: Equatable {
    var duration: TimeInterval = 2
    var attractionRadius: CGFloat = 176
    var explosionRadius: CGFloat = 64
}

struct DecoyBeaconFrame: Equatable {
    var explosionCenter: CGPoint?
    var destroyedEnemyIDs: Set<Int> = []
}

struct DecoyBeaconState {
    var configuration = DecoyBeaconConfiguration()
    private(set) var center: CGPoint?
    private(set) var timeRemaining: TimeInterval = 0

    init(configuration: DecoyBeaconConfiguration = DecoyBeaconConfiguration()) {
        self.configuration = configuration
    }

    var isActive: Bool {
        center != nil && timeRemaining > 0
    }

    mutating func activate(at position: CGPoint) {
        let duration = max(0, configuration.duration)
        guard duration > 0 else {
            reset()
            return
        }

        center = position
        timeRemaining = duration
    }

    mutating func reset() {
        center = nil
        timeRemaining = 0
    }

    func targetPosition(for enemy: ArenaEnemy, fallback: CGPoint) -> CGPoint {
        guard shouldRedirect(enemy), let center else {
            return fallback
        }

        return center
    }

    private func shouldRedirect(_ enemy: ArenaEnemy) -> Bool {
        guard isActive, let center, !enemy.isFrozen, isTargetSeeking(enemy) else {
            return false
        }

        let attractionCircle = CollisionCircle(
            center: center,
            radius: max(0, configuration.attractionRadius)
        )
        return attractionCircle.intersects(enemy.collisionCircle)
    }

    mutating func update(deltaTime: TimeInterval, enemies: [ArenaEnemy]) -> DecoyBeaconFrame {
        guard let activeCenter = center, timeRemaining > 0 else {
            reset()
            return DecoyBeaconFrame()
        }

        timeRemaining = max(0, timeRemaining - max(0, deltaTime))

        guard timeRemaining == 0 else {
            return DecoyBeaconFrame()
        }

        let destroyedEnemyIDs = explosionTargets(center: activeCenter, enemies: enemies)
        reset()
        return DecoyBeaconFrame(
            explosionCenter: activeCenter,
            destroyedEnemyIDs: destroyedEnemyIDs
        )
    }

    private func explosionTargets(center: CGPoint, enemies: [ArenaEnemy]) -> Set<Int> {
        let explosionCircle = CollisionCircle(
            center: center,
            radius: max(0, configuration.explosionRadius)
        )
        return Set(enemies.filter { explosionCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func isTargetSeeking(_ enemy: ArenaEnemy) -> Bool {
        switch enemy.behavior {
        case .chaser, .hunterDot:
            return true
        case .formationLine, .arrowRush, .mineDot, .paddleTrapBar, .paddleTrapDot:
            return false
        }
    }
}
