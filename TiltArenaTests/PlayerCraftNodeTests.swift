import CoreGraphics
import SpriteKit
import XCTest
@testable import TiltArena

@MainActor
final class PlayerCraftNodeTests: XCTestCase {
    func testProtectionChangesFillWithoutAddingNodesAndSurvivesThemeChanges() throws {
        let node = PlayerCraftNode(theme: .darkTacticalRadar, visualRadius: 12)
        let childCount = node.children.count
        let body = try XCTUnwrap(node.children.first { abs($0.zPosition - 0.1) < 0.001 } as? SKShapeNode)
        for theme in [ArenaTheme.darkTacticalRadar, .whitePrecisionBoard] {
            node.applyCollisionProtection(true, theme: theme)
            node.applyTheme(theme)
            XCTAssertTrue(node.showsCollisionProtection)
            try assertColor(body.fillColor, matches: theme.backgroundColor)
            XCTAssertEqual(node.children.count, childCount)
            node.applyCollisionProtection(false, theme: theme)
            XCTAssertFalse(node.showsCollisionProtection)
            try assertColor(body.fillColor, matches: theme.playerColor)
        }
    }

    func testSceneProtectionCueTracksActualImmunityPauseDeathAndRestart() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        let scene = harness.scene
        scene.prepareBalanceRunForTesting(tuning: ArenaBalanceVariant.baseline.tuning, seed: 91)
        scene.collectWeaponForTesting(.warpDash)
        XCTAssertTrue(scene.showsCollisionProtectionForTesting)
        scene.updateActiveRunForTesting(deltaTime: 0.19)
        scene.pauseRunForTesting()
        scene.updateActiveRunForTesting(deltaTime: 5)
        XCTAssertTrue(scene.showsCollisionProtectionForTesting)
        scene.resumeRunForTesting()
        scene.updateActiveRunForTesting(deltaTime: 0.02)
        XCTAssertFalse(scene.showsCollisionProtectionForTesting, "A slow aura is not collision immunity")
        XCTAssertTrue(scene.isTimeDilationAuraActiveForTesting)

        scene.collectWeaponForTesting(.flameTrail, id: 2)
        scene.updateActiveRunForTesting(deltaTime: 0.3)
        XCTAssertTrue(scene.showsCollisionProtectionForTesting, "Flame protection outlives collection grace")
        scene.updateActiveRunForTesting(deltaTime: 2)
        XCTAssertFalse(scene.showsCollisionProtectionForTesting)
        scene.grantPostWeaponSafetyForTesting()
        XCTAssertTrue(scene.showsCollisionProtectionForTesting)
        scene.finishRunForTesting()
        XCTAssertFalse(scene.showsCollisionProtectionForTesting)
        scene.prepareActiveRunForTesting()
        XCTAssertFalse(scene.showsCollisionProtectionForTesting)
        scene.activateRazorShieldForTesting(configuration: StartingWeaponConfiguration())
        scene.updateActiveRunForTesting(deltaTime: 0.01)
        XCTAssertFalse(scene.showsCollisionProtectionForTesting, "Contact-clearing shield has its own visual state")
        scene.grantPostWeaponSafetyForTesting()
        scene.finishRunWithFeedbackForTesting()
        XCTAssertFalse(scene.showsCollisionProtectionForTesting, "The death animation must clear immunity immediately")
    }

    func testProtectionPresentationInBothThemes() throws {
        for theme in [ArenaTheme.darkTacticalRadar, .whitePrecisionBoard] {
            let image = try SnapshotImageRenderer.render(
                size: CGSize(width: 560, height: 190), backgroundColor: theme.backgroundColor
            ) { scene in
                for (column, protected) in [false, true].enumerated() {
                    let x = CGFloat(140 + column * 280)
                    let label = SKLabelNode(fontNamed: "Menlo-Bold")
                    label.text = protected ? "COLLISION IMMUNITY" : "VULNERABLE"
                    label.fontSize = 12
                    label.fontColor = theme.playerColor
                    label.position = CGPoint(x: x, y: 148)
                    scene.addChild(label)
                    for (row, scale) in [CGFloat(1), 0.85].enumerated() {
                        let craft = PlayerCraftNode(theme: theme, visualRadius: 12)
                        craft.applyCollisionProtection(protected, theme: theme)
                        craft.position = CGPoint(x: x, y: CGFloat(100 - row * 50))
                        craft.setScale(scale)
                        scene.addChild(craft)
                    }
                }
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "protection-\(theme.kind.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testMotionAccentUsesProvidedSpeedFractionInsteadOfRawVelocity() throws {
        let node = PlayerCraftNode(theme: .darkTacticalRadar, visualRadius: 12)
        let fastState = PlayerMovementState(position: .zero, velocity: CGVector(dx: 1_000, dy: 0))

        node.apply(state: fastState, speedFraction: 0)
        let engineNode = try XCTUnwrap(node.children.min { $0.position.y < $1.position.y })
        XCTAssertEqual(engineNode.alpha, 0.36, accuracy: 0.0001)
        XCTAssertEqual(engineNode.xScale, 0.82, accuracy: 0.0001)

        node.apply(state: fastState, speedFraction: 1)
        XCTAssertEqual(engineNode.alpha, 0.76, accuracy: 0.0001)
        XCTAssertEqual(engineNode.xScale, 1.24, accuracy: 0.0001)
    }

    private func assertColor(_ actual: SKColor, matches expected: SKColor) throws {
        let actualComponents = try XCTUnwrap(actual.cgColor.components)
        let expectedComponents = try XCTUnwrap(expected.cgColor.components)
        XCTAssertEqual(actualComponents.count, expectedComponents.count)
        for (actual, expected) in zip(actualComponents, expectedComponents) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
    }
}
