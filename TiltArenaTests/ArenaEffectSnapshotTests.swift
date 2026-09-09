import ImageIO
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

    func testEffectsFinishPlaybackWithoutLeavingNodes() async throws {
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        let view = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        view.ignoresSiblingOrder = true
        view.contentScaleFactor = 1
        controller.view = view
        window.rootViewController = controller
        window.isHidden = false
        defer {
            view.presentScene(nil)
            window.isHidden = true
        }

        for themeKind in [ArenaThemeKind.darkTacticalRadar, .whitePrecisionBoard] {
            let scene = try makeScene(size: sceneSize)
            scene.scaleMode = .aspectFit
            view.presentScene(scene)
            scene.prepareEffectSnapshotForTesting(themeKind: themeKind)
            addTrailExample(to: scene, theme: themeKind.theme)
            addTelegraphExample(to: scene, theme: themeKind.theme)
            addPickupExamples(to: scene, theme: themeKind.theme)
            addWeaponEffectExamples(to: scene)
            let completed = expectation(description: "Effects complete in \(themeKind)")
            scene.run(.sequence([.wait(forDuration: 2.2), .run { completed.fulfill() }]), withKey: "preview.completion")
            if ProcessInfo.processInfo.environment["TILT_RECORD_EFFECT_PREVIEWS"] == "1" {
                try await recordPlayback(scene: scene, view: view, name: "effects-\(themeKind)")
            }
            await fulfillment(of: [completed], timeout: 8)
            XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 0)
        }
    }

    private func recordPlayback(scene: ArenaScene, view: SKView, name: String) async throws {
        var frames: [(image: CGImage, time: TimeInterval)] = []
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: sceneSize, format: format)
        // Capture between frames, outside SpriteKit's action evaluation.
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(40))
            let texture = try XCTUnwrap(view.texture(from: scene))
            let image = renderer.image { _ in
                UIImage(cgImage: texture.cgImage()).draw(in: CGRect(origin: .zero, size: sceneSize))
            }
            frames.append((try XCTUnwrap(image.cgImage), CACurrentMediaTime()))
        }
        try attachPlayback(frames, name: name)
    }

    private func attachPlayback(_ frames: [(image: CGImage, time: TimeInterval)], name: String) throws {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, frames.count, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for (index, frame) in frames.enumerated() {
            let delay = index + 1 < frames.count ? frames[index + 1].time - frame.time : 0.12
            CGImageDestinationAddImage(destination, frame.image, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: max(0.02, delay)]
            ] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let attachment = XCTAttachment(data: data as Data, uniformTypeIdentifier: "com.compuserve.gif")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeCrowdedGameplayImage(themeKind: ArenaThemeKind) throws -> UIImage {
        let scene = try makeScene(size: CGSize(width: 720, height: 360))
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
        let scene = try makeScene(size: sceneSize)
        scene.scaleMode = .resizeFill

        return try SnapshotImageRenderer.render(scene: scene) {
            scene.prepareEffectSnapshotForTesting(themeKind: themeKind)
            addTrailExample(to: scene, theme: themeKind.theme)
            addTelegraphExample(to: scene, theme: themeKind.theme)
            addPickupExamples(to: scene, theme: themeKind.theme)
            addWeaponEffectExamples(to: scene)
            scene.revealWeaponEffectsForSnapshotTesting()
            stageExpandedEffects(in: scene)
        }
    }

    private func makeScene(size: CGSize) throws -> ArenaScene {
        let suiteName = "TiltArena.ArenaEffectSnapshotTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let localOptionsStore = ArenaLocalOptionsStore(defaults: defaults)
        localOptionsStore.options = ArenaLocalOptions(audioEnabled: false, hapticsEnabled: false)
        return ArenaScene(
            size: size,
            tiltSettingsStore: TiltSettingsStore(defaults: defaults),
            runProfileStore: RunProfileStore(defaults: defaults),
            localOptionsStore: localOptionsStore,
            gameTuningStore: GameTuningStore(defaults: defaults)
        )
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
            radius: 110,
            duration: 0.28,
            holdDuration: 0.04
        )
        scene.playFreezeBurstEffect(at: CGPoint(x: 344, y: 286), radius: 100, duration: 0.28)
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
