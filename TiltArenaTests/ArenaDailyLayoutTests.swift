import CoreGraphics
import XCTest
@testable import TiltArena

@MainActor
final class ArenaDailyLayoutTests: XCTestCase {
    func testDailySimulationUsesTheSameWorldAcrossPhoneLayoutsAndResize() throws {
        func makeScene(size: CGSize) throws -> ArenaScene {
            let suite = "DailyLayoutTests.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
            return ArenaScene(
                size: size,
                tiltSettingsStore: TiltSettingsStore(defaults: defaults),
                runProfileStore: RunProfileStore(defaults: defaults),
                localOptionsStore: ArenaLocalOptionsStore(defaults: defaults),
                gameTuningStore: GameTuningStore(defaults: defaults)
            )
        }
        let small = try makeScene(size: CGSize(width: 667, height: 375))
        let large = try makeScene(size: CGSize(width: 932, height: 430))
        for scene in [small, large] {
            scene.prepareActiveRunForTesting(mode: .daily, sequenceSeed: 20_260_909)
            scene.update(0)
        }
        XCTAssertEqual(small.currentGameplayBounds, large.currentGameplayBounds)
        XCTAssertEqual(small.currentPlayableRect.size, CGSize(width: 658, height: 317))
        for frame in 1...360 {
            let angle = Double(frame) / 90
            for scene in [small, large] {
                scene.inputOverrideForTesting = CGVector(dx: cos(angle), dy: sin(angle))
                if frame == 60 { scene.collectWeaponForTesting(.shockwave, id: 800) }
                if frame == 120 { scene.collectWeaponForTesting(.freezeBurst, id: 801) }
                scene.update(Double(frame) / 60)
            }
            if frame == 180 { large.size = CGSize(width: 852, height: 393) }
            XCTAssertEqual(small.playerPositionForTesting, large.playerPositionForTesting)
            XCTAssertEqual(small.enemiesForTesting.map(\.id), large.enemiesForTesting.map(\.id))
            XCTAssertEqual(small.enemiesForTesting.map(\.position), large.enemiesForTesting.map(\.position))
            XCTAssertEqual(small.enemiesForTesting.map(\.behavior), large.enemiesForTesting.map(\.behavior))
            XCTAssertEqual(small.enemiesForTesting.map(\.frozenTimeRemaining), large.enemiesForTesting.map(\.frozenTimeRemaining))
            XCTAssertEqual(small.pickupsForTesting, large.pickupsForTesting)
            XCTAssertEqual(small.scoreForTesting, large.scoreForTesting)
            XCTAssertEqual(small.uiStateForTesting, large.uiStateForTesting)
            XCTAssertEqual(small.uiStateForTesting, .activeGameplay)
        }
        XCTAssertGreaterThanOrEqual(small.scoreBreakdownForTesting.pickups, 2 * ClassicRunConfiguration().itemPickupScore)
        XCTAssertGreaterThan(small.runSurvivalTimeForTesting, 5)
        XCTAssertNotEqual(small.screenPositionForTesting(small.playerPositionForTesting),
                          large.screenPositionForTesting(large.playerPositionForTesting))
    }
}
