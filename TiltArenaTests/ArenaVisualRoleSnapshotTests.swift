import SnapshotTesting
import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaVisualRoleSnapshotTests: XCTestCase {
    private let sceneSize = CGSize(width: 560, height: 280)
    private let arenaRect = CGRect(x: 24, y: 24, width: 512, height: 232)

    func testDarkVisualRolesContactSheet() throws {
        assertSnapshot(
            of: try makeVisualRolesImage(theme: .darkTacticalRadar),
            as: .image(precision: 0.99)
        )
    }

    func testWhiteVisualRolesContactSheet() throws {
        assertSnapshot(
            of: try makeVisualRolesImage(theme: .whitePrecisionBoard),
            as: .image(precision: 0.99)
        )
    }

    private func makeVisualRolesImage(theme: ArenaTheme) throws -> UIImage {
        try SnapshotImageRenderer.render(size: sceneSize, backgroundColor: theme.backgroundColor) { scene in
            scene.addChild(
                ArenaThemeRenderer(theme: theme).makeArenaBackground(
                    size: sceneSize,
                    arenaRect: arenaRect
                )
            )

            addActorRow(to: scene, theme: theme)
            addEffectAndPickupRow(to: scene, theme: theme)
        }
    }

    private func addActorRow(to scene: SKScene, theme: ArenaTheme) {
        let player = PlayerCraftNode(theme: theme, visualRadius: 15)
        player.position = CGPoint(x: 78, y: 190)
        player.zRotation = .pi / 8
        scene.addChild(player)

        let enemies = [
            ArenaEnemy(id: 1, position: CGPoint(x: 170, y: 190), radius: 12, speed: 0),
            ArenaEnemy(
                id: 2,
                position: CGPoint(x: 260, y: 190),
                radius: 12,
                speed: 0,
                behavior: .hunterDot(predictionLead: 1.2, previousTarget: nil)
            ),
            ArenaEnemy(
                id: 3,
                position: CGPoint(x: 350, y: 190),
                radius: 12,
                speed: 0,
                behavior: .mineDot
            ),
            ArenaEnemy(
                id: 4,
                position: CGPoint(x: 440, y: 190),
                radius: 12,
                speed: 0,
                behavior: .paddleTrapDot(
                    trapID: 1,
                    velocity: .zero,
                    bounds: arenaRect,
                    remainingLifetime: 2
                )
            ),
            ArenaEnemy(
                id: 5,
                position: CGPoint(x: 492, y: 190),
                radius: 12,
                speed: 0,
                frozenTimeRemaining: 1
            )
        ]

        enemies.forEach { scene.addChild(EnemyNode(enemy: $0, theme: theme)) }
    }

    private func addEffectAndPickupRow(to scene: SKScene, theme: ArenaTheme) {
        let telegraph = EnemyTelegraph(
            id: 1,
            segments: [
                EnemyTelegraphSegment(start: CGPoint(x: 52, y: 86), end: CGPoint(x: 128, y: 126)),
                EnemyTelegraphSegment(start: CGPoint(x: 52, y: 126), end: CGPoint(x: 128, y: 86))
            ]
        )
        scene.addChild(EnemyTelegraphNode(telegraph: telegraph, theme: theme))

        let flameTrail = FlameTrailEffectNode(theme: theme)
        flameTrail.apply(segments: [
            FlameTrailSegment(id: 1, position: CGPoint(x: 172, y: 95), radius: 16, timeRemaining: 1.0, lifetime: 1.2),
            FlameTrailSegment(id: 2, position: CGPoint(x: 198, y: 109), radius: 16, timeRemaining: 0.7, lifetime: 1.2),
            FlameTrailSegment(id: 3, position: CGPoint(x: 224, y: 123), radius: 16, timeRemaining: 0.4, lifetime: 1.2)
        ])
        scene.addChild(flameTrail)

        let pickupKinds: [WeaponKind] = [
            .shockwave,
            .seekerSwarm,
            .razorShield,
            .freezeBurst,
            .gravityWell,
            .novaBomb
        ]
        for (index, kind) in pickupKinds.enumerated() {
            let pickup = WeaponPickup(
                id: index + 1,
                kind: kind,
                position: CGPoint(x: 300 + CGFloat(index) * 38, y: 108),
                radius: 12
            )
            scene.addChild(WeaponPickupNode(pickup: pickup, theme: theme))
        }
    }
}
