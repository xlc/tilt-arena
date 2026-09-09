import SpriteKit
import XCTest
@testable import TiltArena

final class WeaponWaveExpansionTests: XCTestCase {
    @MainActor
    func testWaveAndRunExcludePausedTime() async throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 718, height: 377))
        let controller = UIViewController()
        controller.view = view
        let window = UIWindow(frame: view.frame)
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; view.presentScene(nil) }
        view.presentScene(harness.scene)
        harness.scene.prepareBalanceRunForTesting(tuning: ArenaBalanceVariant.baseline.tuning, seed: 91)
        let boundary = SKNode()
        boundary.setScale(0)
        harness.scene.addWeaponEffectNodeForTesting(boundary)
        boundary.run(harness.scene.waveExpansionAction(duration: 2, exponent: 1), withKey: "wave")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(boundary.xScale, 0)
        harness.scene.pauseRunForTesting()
        let scale = boundary.xScale
        let survival = harness.scene.runSurvivalTimeForTesting
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(harness.scene.runSurvivalTimeForTesting, survival, accuracy: 0.001)
        XCTAssertEqual(boundary.xScale, scale, accuracy: 0.01)
        harness.scene.resumeRunForTesting()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(boundary.xScale, scale)
        XCTAssertEqual(boundary.xScale, WeaponWaveExpansion.progress(
            elapsed: harness.scene.runSurvivalTimeForTesting, duration: 2, exponent: 1
        ), accuracy: 0.025)
    }

    @MainActor
    func testVisibleWaveStaysWithGameplayAcrossDroppedFrames() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        harness.scene.prepareBalanceRunForTesting(tuning: ArenaBalanceVariant.baseline.tuning, seed: 91)
        let boundary = SKNode()
        boundary.setScale(0)
        harness.scene.addWeaponEffectNodeForTesting(boundary)
        boundary.run(harness.scene.waveExpansionAction(duration: 0.6, exponent: 3))
        harness.step(at: 0)
        for time in [1.0 / 60, 0.3, 0.35, 0.6] {
            harness.step(at: time)
            XCTAssertEqual(harness.scene.runSurvivalTimeForTesting, time, accuracy: 0.001)
            XCTAssertEqual(boundary.xScale, WeaponWaveExpansion.progress(
                elapsed: time, duration: 0.6, exponent: 3
            ), accuracy: 0.001)
        }
    }

    func testResponsiveFrontNeverLosesLinearCoverageOrChangesLifetime() {
        for framesPerSecond in [30, 60, 120] {
            var linear = ShockwaveWaveState(center: .zero, maximumRadius: 90, expansionDuration: 0.6, holdDuration: 0.2)
            var responsive = ShockwaveWaveState(center: .zero, maximumRadius: 90, expansionDuration: 0.6,
                                               holdDuration: 0.2, expansionExponent: 3)
            for _ in 1...framesPerSecond {
                let previous = linear.update(deltaTime: 1 / Double(framesPerSecond), enemies: [])
                let changed = responsive.update(deltaTime: 1 / Double(framesPerSecond), enemies: [])
                XCTAssertGreaterThanOrEqual(changed.radius + 0.000_001, previous.radius)
                XCTAssertLessThanOrEqual(changed.radius, 90)
                XCTAssertEqual(changed.isComplete, previous.isComplete)
            }
        }
    }

    func testLateEntrantsStillMeetTheOriginalWaveWindow() {
        var shockwave = ShockwaveWaveState(center: .zero, maximumRadius: 90, expansionDuration: 0.6,
                                          holdDuration: 0.2, expansionExponent: 3)
        var freeze = FreezeBurstWaveState(center: .zero, maximumRadius: 140, duration: 0.8, expansionExponent: 3)
        _ = shockwave.update(deltaTime: 0.7, enemies: [])
        _ = freeze.update(deltaTime: 0.7, enemies: [])
        let enemy = ArenaEnemy(id: 1, position: CGPoint(x: 80, y: 0), radius: 5, speed: 0)
        XCTAssertEqual(shockwave.update(deltaTime: 0.05, enemies: [enemy]).destroyedEnemyIDs, [1])
        XCTAssertEqual(freeze.update(deltaTime: 0.05, enemies: [enemy]).frozenEnemyIDs, [1])
        XCTAssertFalse(shockwave.isComplete)
        XCTAssertFalse(freeze.isComplete)
    }

    @MainActor
    func testVisibleBoundaryUsesTheCollisionResponseCurve() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        harness.scene.prepareBalanceRunForTesting(tuning: ArenaBalanceVariant.baseline.tuning, seed: 91)
        let boundary = SKNode()
        boundary.setScale(0)
        harness.scene.addWeaponEffectNodeForTesting(boundary)
        boundary.run(harness.scene.waveExpansionAction(duration: 0.6, exponent: 3))
        harness.step(at: 0)
        for frame in 1...12 { harness.step(at: Double(frame) / 60) }
        XCTAssertEqual(boundary.xScale, WeaponWaveExpansion.progress(elapsed: 0.2, duration: 0.6, exponent: 3), accuracy: 0.001)
    }

    @MainActor
    func testWaveFrontPresentationInBothThemes() throws {
        for theme in [ArenaThemeKind.darkTacticalRadar, .whitePrecisionBoard] {
            let harness = try ArenaBalanceHarness()
            defer { harness.close() }
            let image = try SnapshotImageRenderer.render(scene: harness.scene) {
                harness.scene.prepareEffectSnapshotForTesting(themeKind: theme)
                harness.scene.playShockwaveEffect(at: CGPoint(x: 190, y: 188), radius: 90, duration: 0.6,
                                                  holdDuration: 0.2, expansionExponent: 3)
                harness.scene.playFreezeBurstEffect(at: CGPoint(x: 520, y: 188), radius: 140, duration: 0.8,
                                                    expansionExponent: 3)
                harness.step(at: 0)
                for frame in 1...12 { harness.step(at: Double(frame) / 60) }
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "wave-fronts-\(theme.rawValue)-0.2s"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
