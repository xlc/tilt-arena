import SnapshotTesting
import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaVisualRoleSnapshotTests: XCTestCase {
    private static let weaponLabels: [WeaponKind: String] = [
        .shockwave: "SHOCK",
        .seekerSwarm: "SEEKER",
        .razorShield: "SHIELD",
        .freezeBurst: "FREEZE",
        .gravityWell: "GRAV",
        .chainLightning: "CHAIN",
        .flameTrail: "FLAME",
        .warpDash: "TIME",
        .powerWave: "WAVE",
        .ricochetLance: "LANCE",
        .novaBomb: "NOVA"
    ]

    private let sceneSize = CGSize(width: 720, height: 420)
    private let arenaRect = CGRect(x: 24, y: 32, width: 672, height: 364)

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
        player.position = CGPoint(x: 76, y: 326)
        player.zRotation = .pi / 8
        scene.addChild(player)
        addContactLabel("PLAYER", at: CGPoint(x: 76, y: 292), to: scene, theme: theme)

        let enemies = [
            ArenaEnemy(id: 1, position: CGPoint(x: 190, y: 326), radius: 12, speed: 0),
            ArenaEnemy(
                id: 2,
                position: CGPoint(x: 300, y: 326),
                radius: 12,
                speed: 0,
                behavior: .hunterDot(predictionLead: 1.2, previousTarget: nil)
            ),
            ArenaEnemy(
                id: 3,
                position: CGPoint(x: 410, y: 326),
                radius: 12,
                speed: 0,
                behavior: .mineDot
            ),
            ArenaEnemy(
                id: 4,
                position: CGPoint(x: 520, y: 326),
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
                position: CGPoint(x: 630, y: 326),
                radius: 12,
                speed: 0,
                frozenTimeRemaining: 1
            )
        ]

        enemies.forEach { scene.addChild(EnemyNode(enemy: $0, theme: theme)) }
        addContactLabel("CHASER", at: CGPoint(x: 190, y: 292), to: scene, theme: theme)
        addContactLabel("HUNTER", at: CGPoint(x: 300, y: 292), to: scene, theme: theme)
        addContactLabel("MINE", at: CGPoint(x: 410, y: 292), to: scene, theme: theme)
        addContactLabel("PADDLE", at: CGPoint(x: 520, y: 292), to: scene, theme: theme)
        addContactLabel("FROZEN", at: CGPoint(x: 630, y: 292), to: scene, theme: theme)
    }

    private func addEffectAndPickupRow(to scene: SKScene, theme: ArenaTheme) {
        let telegraph = EnemyTelegraph(
            id: 1,
            segments: [
                EnemyTelegraphSegment(start: CGPoint(x: 58, y: 206), end: CGPoint(x: 142, y: 246)),
                EnemyTelegraphSegment(start: CGPoint(x: 58, y: 246), end: CGPoint(x: 142, y: 206))
            ]
        )
        scene.addChild(EnemyTelegraphNode(telegraph: telegraph, theme: theme))
        addContactLabel("TELEGRAPH", at: CGPoint(x: 100, y: 178), to: scene, theme: theme)

        let flameTrail = FlameTrailEffectNode(theme: theme)
        flameTrail.apply(segments: [
            FlameTrailSegment(id: 1, position: CGPoint(x: 190, y: 212), radius: 16, timeRemaining: 1.0, lifetime: 1.2),
            FlameTrailSegment(id: 2, position: CGPoint(x: 216, y: 226), radius: 16, timeRemaining: 0.7, lifetime: 1.2),
            FlameTrailSegment(id: 3, position: CGPoint(x: 242, y: 240), radius: 16, timeRemaining: 0.4, lifetime: 1.2)
        ])
        scene.addChild(flameTrail)
        addContactLabel("FLAME TRAIL", at: CGPoint(x: 216, y: 178), to: scene, theme: theme)

        let pickupKinds: [WeaponKind] = [
            .shockwave,
            .seekerSwarm,
            .razorShield,
            .freezeBurst,
            .gravityWell,
            .chainLightning,
            .flameTrail,
            .warpDash,
            .powerWave,
            .ricochetLance,
            .novaBomb
        ]
        for (index, kind) in pickupKinds.enumerated() {
            let pickupX = 58 + CGFloat(index) * 58
            let pickup = WeaponPickup(
                id: index + 1,
                kind: kind,
                position: CGPoint(x: pickupX, y: 100),
                radius: 12
            )
            scene.addChild(WeaponPickupNode(pickup: pickup, theme: theme))
            addContactLabel(
                label(for: kind),
                at: CGPoint(x: pickup.position.x, y: 66),
                to: scene,
                theme: theme
            )
        }
    }

    private func label(for kind: WeaponKind) -> String {
        Self.weaponLabels[kind] ?? kind.displayName.uppercased()
    }

    private func addContactLabel(_ text: String, at position: CGPoint, to scene: SKScene, theme: ArenaTheme) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 10
        label.fontColor = theme.playerColor.withAlphaComponent(0.82)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 80
        scene.addChild(label)
    }
}
