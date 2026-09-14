import SnapshotTesting
import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaWeaponCodexTests: XCTestCase {
    func testSmallDarkPages() throws {
        try assertPages(size: CGSize(width: 667, height: 375), theme: .darkTacticalRadar)
    }

    func testSmallWhitePages() throws {
        try assertPages(size: CGSize(width: 667, height: 375), theme: .whitePrecisionBoard)
    }

    func testLargeDarkPages() throws {
        try assertPages(size: CGSize(width: 932, height: 430), theme: .darkTacticalRadar)
    }

    func testLargeWhitePages() throws {
        try assertPages(size: CGSize(width: 932, height: 430), theme: .whitePrecisionBoard)
    }

    func testScenePreservesPageAndReconcilesItAfterResize() throws {
        let suite = "CodexNavigation.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let scene = ArenaScene(
            size: CGSize(width: 560, height: 280),
            tiltSettingsStore: TiltSettingsStore(defaults: defaults),
            runProfileStore: RunProfileStore(defaults: defaults),
            localOptionsStore: ArenaLocalOptionsStore(defaults: defaults),
            gameTuningStore: GameTuningStore(defaults: defaults)
        )
        scene.prepareForVisualSnapshot(state: .home)
        scene.activateControlForTesting(.openWeaponCodex)
        XCTAssertEqual(scene.uiStateForTesting, .weaponCodex)
        scene.activateControlForTesting(.weaponCodexPage(5))
        XCTAssertEqual(scene.weaponCodexPageIndexForTesting, 5)
        scene.activateControlForTesting(.back)
        XCTAssertEqual(scene.uiStateForTesting, .home)
        scene.activateControlForTesting(.openWeaponCodex)
        XCTAssertEqual(scene.weaponCodexPageIndexForTesting, 5)
        scene.size = CGSize(width: 932, height: 430)
        XCTAssertEqual(scene.weaponCodexPageIndexForTesting, 2)
        scene.activateControlForTesting(.weaponCodexPage(1))
        XCTAssertEqual(scene.weaponCodexPageIndexForTesting, 1)
    }

    private func assertPages(size: CGSize, theme: ArenaThemeKind, testName: String = #function) throws {
        let insets: UIEdgeInsets = size.width > 900
            ? UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59) : .zero
        let layout = ArenaLandscapeUILayout(sceneSize: size, safeAreaInsets: insets, margin: 24)
        var profile = RunProfile()
        profile.totalEnemiesDestroyed = 75
        profile.unlockedWeapons.insert(.freezeBurst)
        let rows = ArenaMenuContent.weaponCodexRows(profile: profile)
        let pageCount = (rows.count - 1) / layout.weaponCodexPageSize + 1
        var seen: [WeaponKind] = []
        for pageIndex in 0..<pageCount {
            let renderer = ArenaUIRenderer()
            let image = try SnapshotImageRenderer.render(size: size, backgroundColor: theme.theme.backgroundColor) { scene in
                renderer.begin(theme: theme.theme, sceneSize: size)
                renderer.renderWeaponCodex(rows: rows, pageIndex: pageIndex, layout: layout)
                scene.addChild(renderer.root)
            }
            let labels = renderer.root.children.compactMap { $0 as? SKLabelNode }
            for row in rows.dropFirst(pageIndex * layout.weaponCodexPageSize).prefix(layout.weaponCodexPageSize) {
                seen.append(row.kind)
                let title = try XCTUnwrap(labels.first { $0.text == row.title })
                let body = try XCTUnwrap(labels.first { $0.text == row.description })
                let requirement = try XCTUnwrap(labels.first { $0.text == row.unlockText })
                for label in [title, body, requirement] {
                    XCTAssertTrue(layout.menuContentFrame.contains(label.frame), "Overflow: \(label.text ?? "")")
                    XCTAssertGreaterThanOrEqual(label.fontSize, 12)
                    XCTAssertEqual(label.fontColor?.cgColor.alpha, 1)
                }
                XCTAssertGreaterThan(title.frame.minY, body.frame.maxY)
                // STARTER repeats, so compare the requirement in this card's column and row.
                let cardRequirement = try XCTUnwrap(labels.first {
                    $0.text == row.unlockText && abs($0.position.x - body.position.x) < 1
                        && $0.frame.maxY < body.frame.minY
                })
                XCTAssertGreaterThan(body.frame.minY, cardRequirement.frame.maxY)
            }
            let pageActions = renderer.hitTargets.compactMap { target -> Int? in
                guard case let .weaponCodexPage(index) = target.action else { return nil }
                XCTAssertGreaterThanOrEqual(target.frame.height, 44)
                XCTAssertGreaterThanOrEqual(target.frame.width, 44)
                return index
            }
            XCTAssertEqual(pageActions, [pageIndex - 1, pageIndex + 1].filter { (0..<pageCount).contains($0) })
            assertSnapshot(of: image, as: .image(precision: 0.99), named: "page-\(pageIndex + 1)", testName: testName)
        }
        XCTAssertEqual(seen, rows.map(\.kind))
    }
}
