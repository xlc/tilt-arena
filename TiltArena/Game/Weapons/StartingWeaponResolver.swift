import CoreGraphics
import Foundation

struct StartingWeaponConfiguration: Equatable {
    var shockwaveRadius: CGFloat = 96
    var seekerTargetLimit: Int = 4
    var razorShieldRadius: CGFloat = 32
    var razorShieldDuration: TimeInterval = 4
}

struct WeaponResolution: Equatable {
    var destroyedEnemyIDs: Set<Int> = []
}

struct StartingWeaponResolver {
    var configuration = StartingWeaponConfiguration()

    func resolve(kind: WeaponKind, playerPosition: CGPoint, enemies: [ChaserEnemy]) -> WeaponResolution {
        switch kind {
        case .shockwave:
            return WeaponResolution(destroyedEnemyIDs: shockwaveTargets(playerPosition: playerPosition, enemies: enemies))
        case .seekerSwarm:
            return WeaponResolution(destroyedEnemyIDs: seekerTargets(playerPosition: playerPosition, enemies: enemies))
        case .razorShield:
            return WeaponResolution()
        }
    }

    func shieldTargets(playerPosition: CGPoint, enemies: [ChaserEnemy]) -> Set<Int> {
        let shieldCircle = CollisionCircle(center: playerPosition, radius: configuration.razorShieldRadius)
        return Set(enemies.filter { shieldCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func shockwaveTargets(playerPosition: CGPoint, enemies: [ChaserEnemy]) -> Set<Int> {
        let shockwaveCircle = CollisionCircle(center: playerPosition, radius: configuration.shockwaveRadius)
        return Set(enemies.filter { shockwaveCircle.intersects($0.collisionCircle) }.map(\.id))
    }

    private func seekerTargets(playerPosition: CGPoint, enemies: [ChaserEnemy]) -> Set<Int> {
        let targetLimit = max(0, configuration.seekerTargetLimit)

        guard targetLimit > 0 else {
            return []
        }

        return Set(
            enemies
                .sorted {
                    squaredDistance(from: $0.position, to: playerPosition)
                        < squaredDistance(from: $1.position, to: playerPosition)
                }
                .prefix(targetLimit)
                .map(\.id)
        )
    }

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}
