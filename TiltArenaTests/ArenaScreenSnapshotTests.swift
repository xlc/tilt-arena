import SnapshotTesting
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaScreenSnapshotTests: XCTestCase {
    private let sceneSize = CGSize(width: 560, height: 280)

    func testDarkHomeScreen() throws {
        try assertScreenSnapshot(state: .home, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testDarkModeSelectScreen() throws {
        try assertScreenSnapshot(state: .modeSelect, themeKind: .darkTacticalRadar, testName: #function)
    }

    func testDarkAwardsScreen() throws {
        try assertScreenSnapshot(state: .awards, themeKind: .darkTacticalRadar, testName: #function)
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
        let scene = ArenaScene(size: sceneSize)
        scene.scaleMode = .resizeFill

        return try SnapshotImageRenderer.render(scene: scene) {
            scene.prepareForVisualSnapshot(
                state: state,
                profile: progressedProfile(),
                localOptions: ArenaLocalOptions(
                    audioEnabled: true,
                    hapticsEnabled: true,
                    themeKind: themeKind
                )
            )
        }
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
}
