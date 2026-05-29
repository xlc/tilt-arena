import SnapshotTesting
import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaEffectSnapshotTests: XCTestCase {
    private let sceneSize = CGSize(width: 720, height: 420)

    func testDarkEffectMotionContactSheet() throws {
        assertSnapshot(
            of: try makeEffectMotionImage(themeKind: .darkTacticalRadar),
            as: .image(precision: 0.99)
        )
    }

    private func makeEffectMotionImage(themeKind: ArenaThemeKind) throws -> UIImage {
        let scene = ArenaScene(size: sceneSize)
        scene.scaleMode = .resizeFill

        return try SnapshotImageRenderer.render(scene: scene) {
            scene.prepareEffectSnapshotForTesting(themeKind: themeKind)
            addTrailExample(to: scene, theme: themeKind.theme)
            addTelegraphExample(to: scene, theme: themeKind.theme)
            addPickupExamples(to: scene, theme: themeKind.theme)
            addWeaponEffectExamples(to: scene, theme: themeKind.theme)
            scene.revealWeaponEffectsForSnapshotTesting()
        }
    }

    private func addTrailExample(to scene: SKScene, theme: ArenaTheme) {
        let trail = PlayerTrailNode(theme: theme)
        trail.reset(to: CGPoint(x: 64, y: 104))
        [
            CGPoint(x: 94, y: 120),
            CGPoint(x: 126, y: 142),
            CGPoint(x: 160, y: 138),
            CGPoint(x: 196, y: 166),
            CGPoint(x: 236, y: 158)
        ].forEach { trail.record(position: $0, speedFraction: 0.88) }
        scene.addChild(trail)

        let player = PlayerCraftNode(theme: theme, visualRadius: 15)
        player.apply(
            state: PlayerMovementState(
                position: CGPoint(x: 246, y: 164),
                velocity: CGVector(dx: 140, dy: 42)
            ),
            speedFraction: 0.88
        )
        scene.addChild(player)
    }

    private func addTelegraphExample(to scene: SKScene, theme: ArenaTheme) {
        let telegraph = EnemyTelegraph(
            id: 1,
            segments: [
                EnemyTelegraphSegment(start: CGPoint(x: 470, y: 84), end: CGPoint(x: 640, y: 142)),
                EnemyTelegraphSegment(start: CGPoint(x: 478, y: 150), end: CGPoint(x: 642, y: 90))
            ]
        )
        scene.addChild(EnemyTelegraphNode(telegraph: telegraph, theme: theme))
    }

    private func addPickupExamples(to scene: ArenaScene, theme: ArenaTheme) {
        let pickup = WeaponPickup(
            id: 1,
            kind: .chainLightning,
            position: CGPoint(x: 350, y: 104),
            radius: 13
        )
        scene.addChild(WeaponPickupNode(pickup: pickup, theme: theme))
        scene.playPickupCollectionPop(for: pickup)
    }

    private func addWeaponEffectExamples(to scene: ArenaScene, theme: ArenaTheme) {
        scene.playShockwaveEffect(
            at: CGPoint(x: 150, y: 286),
            duration: 0.28,
            holdDuration: 0.04
        )
        scene.playFreezeBurstEffect(at: CGPoint(x: 344, y: 286), duration: 0.28)
        _ = scene.playTimeDilationAuraEffect(
            at: CGPoint(x: 552, y: 300),
            radius: 72,
            duration: 1
        )
        scene.playChainLightningEffect(
            from: CGPoint(x: 470, y: 250),
            through: [
                WeaponImpactTarget(id: 1, position: CGPoint(x: 530, y: 278)),
                WeaponImpactTarget(id: 2, position: CGPoint(x: 584, y: 242)),
                WeaponImpactTarget(id: 3, position: CGPoint(x: 642, y: 280))
            ],
            accentColor: theme.playerAccentColor,
            coreColor: theme.playerColor,
            onImpact: { _ in }
        )
        scene.playEnemyClearBursts(
            at: [
                CGPoint(x: 520, y: 196),
                CGPoint(x: 558, y: 184),
                CGPoint(x: 596, y: 204)
            ],
            weaponKind: .chainLightning,
            comboMultiplier: 4
        )
    }
}
