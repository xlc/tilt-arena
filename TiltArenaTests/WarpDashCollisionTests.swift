import CoreGraphics
import XCTest
@testable import TiltArena

final class WarpDashCollisionTests: XCTestCase {
    func testSweptDashPathTargetsEnemiesIntersectingPlayerCapsule() {
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 50, y: 10)),
            enemy(id: 2, position: CGPoint(x: 50, y: 12)),
            enemy(id: 3, position: CGPoint(x: 120, y: 0))
        ]

        let targetIDs = WarpDashCollision.sweptTargets(
            from: .zero,
            to: CGPoint(x: 100, y: 0),
            playerRadius: 5,
            enemies: enemies
        )

        XCTAssertEqual(targetIDs, [1])
    }

    func testContactTargetsUsePlayerHitCircleDuringInvulnerability() {
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0)),
            enemy(id: 2, position: CGPoint(x: 14, y: 0))
        ]

        let targetIDs = WarpDashCollision.contactTargets(
            playerPosition: .zero,
            playerRadius: 4,
            enemies: enemies
        )

        XCTAssertEqual(targetIDs, [1])
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 6, speed: 0)
    }
}
