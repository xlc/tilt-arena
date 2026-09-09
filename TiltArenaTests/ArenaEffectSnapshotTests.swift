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

    func testWhiteEffectMotionContactSheet() throws {
        assertSnapshot(of: try makeEffectMotionImage(themeKind: .whitePrecisionBoard), as: .image(precision: 0.99))
    }

    func testDarkCrowdedGameplay() throws {
        assertSnapshot(of: try makeCrowdedGameplayImage(themeKind: .darkTacticalRadar), as: .image(precision: 0.99))
    }

    func testWhiteCrowdedGameplay() throws {
        assertSnapshot(of: try makeCrowdedGameplayImage(themeKind: .whitePrecisionBoard), as: .image(precision: 0.99))
    }

    private func makeCrowdedGameplayImage(themeKind: ArenaThemeKind) throws -> UIImage {
        let scene = ArenaScene(size: CGSize(width: 720, height: 360))
        let theme = themeKind.theme
        return try SnapshotImageRenderer.render(scene: scene) {
            scene.prepareEffectSnapshotForTesting(themeKind: themeKind)
            for index in 0..<96 {
                let position = CGPoint(x: 42 + (index % 16) * 42, y: 50 + (index / 16) * 49 + (index % 3) * 6)
                guard hypot(position.x - 246, position.y - 164) > 28 else { continue }
                let behavior: EnemyBehavior = index.isMultiple(of: 5)
                    ? .arrowRush(velocity: CGVector(dx: -40, dy: 15)) : .chaser
                let enemy = ArenaEnemy(id: index, position: position, radius: 4, speed: 0, behavior: behavior)
                scene.addChild(EnemyNode(enemy: enemy, theme: theme))
            }
            addTrailExample(to: scene, theme: theme)
            addTelegraphExample(to: scene, theme: theme)
            addPickupExamples(to: scene, theme: theme)
            scene.playShockwaveEffect(at: CGPoint(x: 412, y: 190), radius: 78, duration: 0.28, holdDuration: 0.04)
            scene.playFreezeBurstEffect(at: CGPoint(x: 552, y: 260), radius: 66, duration: 0.28)
            scene.revealWeaponEffectsForSnapshotTesting()
            // Stage the expanding fronts partway through travel for a deterministic crowded frame.
            stageExpandedEffects(in: scene)
        }
    }

    private func stageExpandedEffects(in node: SKNode) {
        if let shape = node as? SKShapeNode,
           let bounds = shape.path?.boundingBox,
           bounds.width > 60, shape.xScale < 0.2 {
            shape.setScale(0.7)
        }
        node.children.forEach { stageExpandedEffects(in: $0) }
    }

    private func makeEffectMotionImage(themeKind: ArenaThemeKind) throws -> UIImage {
        let scene = ArenaScene(size: sceneSize)
        scene.scaleMode = .resizeFill

        return try SnapshotImageRenderer.render(scene: scene) {
            scene.prepareEffectSnapshotForTesting(themeKind: themeKind)
            addTrailExample(to: scene, theme: themeKind.theme)
            addTelegraphExample(to: scene, theme: themeKind.theme)
            addPickupExamples(to: scene, theme: themeKind.theme)
            addWeaponEffectExamples(to: scene)
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
        let basePickup = WeaponPickup(
            id: 1,
            kind: .chainLightning,
            position: CGPoint(x: 326, y: 104),
            radius: 13
        )
        let overchargedPickup = WeaponPickup(
            id: 2,
            kind: .novaBomb,
            position: CGPoint(x: 388, y: 104),
            radius: 13,
            chargeTier: .overcharged
        )

        [basePickup, overchargedPickup].forEach { pickup in
            scene.addChild(WeaponPickupNode(pickup: pickup, theme: theme))
        }
        scene.playPickupCollectionPop(for: basePickup)
    }

    private func addWeaponEffectExamples(to scene: ArenaScene) {
        scene.playChargedWeaponActivationEffect(
            kind: .novaBomb,
            at: CGPoint(x: 92, y: 210),
            chargeTier: .overcharged
        )
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
            ]
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
        scene.playWeaponComboEffect(
            WeaponComboEvent(
                kind: .cascade,
                previousFamily: .force,
                currentFamily: .seek
            ),
            at: [
                CGPoint(x: 520, y: 196),
                CGPoint(x: 558, y: 184),
                CGPoint(x: 596, y: 204)
            ]
        )
    }
}
