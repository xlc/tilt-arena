import SnapshotTesting
import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaScreenSnapshotTests: XCTestCase {
    private let sceneSize = CGSize(width: 560, height: 280)

    func testDarkHomeScreen() throws {
        try assertScreenSnapshot(state: .home, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testWhiteHomeScreen() throws {
        try assertScreenSnapshot(state: .home, themeKind: .whitePrecisionBoard, testName: #function)
    }

    func testDarkModeSelectScreen() throws {
        try assertScreenSnapshot(state: .modeSelect, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testWhiteModeSelectScreen() throws {
        try assertScreenSnapshot(state: .modeSelect, themeKind: .whitePrecisionBoard, testName: #function)
    }

    func testDarkAwardsScreen() throws {
        try assertScreenSnapshot(state: .awards, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testWhiteAwardsScreen() throws {
        try assertScreenSnapshot(state: .awards, themeKind: .whitePrecisionBoard, testName: #function)
    }

    func testDarkOptionsScreen() throws {
        try assertScreenSnapshot(state: .options, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testWhiteOptionsScreen() throws {
        try assertScreenSnapshot(state: .options, themeKind: .whitePrecisionBoard, testName: #function)
    }

    func testDarkCalibrationPreviewScreen() throws {
        try assertScreenSnapshot(state: .calibrationPreview, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testWhiteCalibrationPreviewScreen() throws {
        try assertScreenSnapshot(state: .calibrationPreview, themeKind: .whitePrecisionBoard, testName: #function)
    }

    func testDarkDeveloperTuningScreen() throws {
        try assertScreenSnapshot(state: .developerTuning, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testDarkPreRunScreen() throws {
        try assertScreenSnapshot(state: .preRun, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testDarkActiveGameplayScreen() throws {
        try assertScreenSnapshot(state: .activeGameplay, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testDarkPauseScreen() throws {
        try assertScreenSnapshot(state: .pause, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testDarkPostRunScreen() throws {
        try assertScreenSnapshot(state: .postRun, themeKind: .darkTacticalRadar, testName: #function)
    }

    private func assertScreenSnapshot(
        state: ArenaUISceneState,
        themeKind: ArenaThemeKind,
        testName: String,
        line: UInt = #line
    ) throws {
        assertSnapshot(
            of: try makeScreenImage(state: state, themeKind: themeKind),
            as: .image(precision: 0.99),
            file: #filePath,
            testName: testName,
            line: line
        )
    }

    private func makeScreenImage(state: ArenaUISceneState, themeKind: ArenaThemeKind) throws -> UIImage {
        let scene = try makeSnapshotScene()
        scene.scaleMode = .resizeFill

        return try SnapshotImageRenderer.render(scene: scene) {
            let localOptions = ArenaLocalOptions(
                audioEnabled: true,
                hapticsEnabled: true,
                themeKind: themeKind
            )
            if state.usesRunStateFixture {
                scene.prepareRunStateVisualSnapshot(
                    state: state,
                    profile: progressedProfile(),
                    localOptions: localOptions
                )
                if state.usesGameplayFixture {
                    addGameplayFixture(to: scene, theme: themeKind.theme)
                }
            } else {
                scene.prepareForVisualSnapshot(
                    state: state,
                    profile: progressedProfile(),
                    localOptions: localOptions
                )
            }
        }
    }

    private func makeSnapshotScene() throws -> ArenaScene {
        let suiteName = "TiltArena.ArenaScreenSnapshotTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))

        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        return ArenaScene(
            size: sceneSize,
            tiltSettingsStore: TiltSettingsStore(defaults: defaults),
            runProfileStore: RunProfileStore(defaults: defaults),
            localOptionsStore: ArenaLocalOptionsStore(defaults: defaults)
        )
    }

    private func progressedProfile() -> RunProfile {
        var profile = RunProfile()
        profile.bestScore = 6_400
        profile.highestCombo = 24
        profile.longestSurvivalTime = 64.2
        profile.totalRuns = 18
        profile.totalEnemiesDestroyed = 320
        profile.unlockedWeapons = Set(ArenaProgressionRules.allGameplayWeapons)
        profile.earnedAwardIDs = Set(ArenaAwardID.allCases)
        return profile
    }

    private func addGameplayFixture(to scene: ArenaScene, theme: ArenaTheme) {
        let bounds = scene.currentGameplayBounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        addTelegraphFixture(to: scene, bounds: bounds, theme: theme)
        addEnemyFixture(to: scene, center: center, bounds: bounds, theme: theme)
        addPickupFixture(to: scene, center: center, theme: theme)
        addEffectFixture(to: scene, center: center, theme: theme)
        scene.revealWeaponEffectsForSnapshotTesting()
    }

    private func addTelegraphFixture(to scene: SKScene, bounds: CGRect, theme: ArenaTheme) {
        let telegraph = EnemyTelegraph(
            id: 100,
            segments: [
                EnemyTelegraphSegment(
                    start: CGPoint(x: bounds.minX + 58, y: bounds.minY + 76),
                    end: CGPoint(x: bounds.maxX - 70, y: bounds.maxY - 48)
                ),
                EnemyTelegraphSegment(
                    start: CGPoint(x: bounds.minX + 76, y: bounds.maxY - 58),
                    end: CGPoint(x: bounds.maxX - 84, y: bounds.minY + 80)
                )
            ]
        )
        scene.addChild(EnemyTelegraphNode(telegraph: telegraph, theme: theme))
    }

    private func addEnemyFixture(to scene: SKScene, center: CGPoint, bounds: CGRect, theme: ArenaTheme) {
        let enemies = [
            ArenaEnemy(
                id: 101,
                position: CGPoint(x: center.x - 118, y: center.y + 50),
                radius: 12,
                speed: 0
            ),
            ArenaEnemy(
                id: 102,
                position: CGPoint(x: center.x + 96, y: center.y + 58),
                radius: 12,
                speed: 0,
                behavior: .hunterDot(predictionLead: 1.2, previousTarget: nil)
            ),
            ArenaEnemy(
                id: 103,
                position: CGPoint(x: center.x + 140, y: center.y - 54),
                radius: 13,
                speed: 0,
                behavior: .mineDot
            ),
            ArenaEnemy(
                id: 104,
                position: CGPoint(x: bounds.minX + 94, y: center.y - 28),
                radius: 12,
                speed: 0,
                frozenTimeRemaining: 1.4
            )
        ]

        enemies.forEach { scene.addChild(EnemyNode(enemy: $0, theme: theme)) }
    }

    private func addPickupFixture(to scene: SKScene, center: CGPoint, theme: ArenaTheme) {
        let pickups = [
            WeaponPickup(
                id: 201,
                kind: .chainLightning,
                position: CGPoint(x: center.x + 42, y: center.y - 82),
                radius: 13
            ),
            WeaponPickup(
                id: 202,
                kind: .gravityWell,
                position: CGPoint(x: center.x - 158, y: center.y - 78),
                radius: 13
            )
        ]

        pickups.forEach { scene.addChild(WeaponPickupNode(pickup: $0, theme: theme)) }
    }

    private func addEffectFixture(to scene: ArenaScene, center: CGPoint, theme: ArenaTheme) {
        scene.playShockwaveEffect(
            at: CGPoint(x: center.x - 58, y: center.y - 20),
            duration: 0.28,
            holdDuration: 0.04
        )
        scene.playChainLightningEffect(
            from: CGPoint(x: center.x + 24, y: center.y + 8),
            through: [
                WeaponImpactTarget(id: 101, position: CGPoint(x: center.x + 96, y: center.y + 58)),
                WeaponImpactTarget(id: 102, position: CGPoint(x: center.x + 140, y: center.y - 54))
            ],
            accentColor: theme.playerAccentColor,
            coreColor: theme.playerColor,
            onImpact: { _ in }
        )
        scene.playEnemyClearBursts(
            at: [
                CGPoint(x: center.x - 118, y: center.y + 50),
                CGPoint(x: center.x - 58, y: center.y - 20)
            ],
            weaponKind: .chainLightning,
            comboMultiplier: 3
        )
    }
}

private extension ArenaUISceneState {
    var usesRunStateFixture: Bool {
        switch self {
        case .preRun, .activeGameplay, .pause, .postRun:
            return true
        case .home, .modeSelect, .awards, .options, .developerTuning, .calibrationPreview:
            return false
        }
    }

    var usesGameplayFixture: Bool {
        switch self {
        case .activeGameplay, .pause, .postRun:
            return true
        case .home, .modeSelect, .awards, .options, .developerTuning, .calibrationPreview, .preRun:
            return false
        }
    }
}
