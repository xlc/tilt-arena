import XCTest
@testable import TiltArena

final class ArenaHapticsControllerTests: XCTestCase {
    func testPickupAndDangerPickupUseDistinctImpactPatterns() {
        XCTAssertEqual(
            ArenaHapticEvent.pickup.pattern,
            .impact(.light, intensity: 0.45)
        )
        XCTAssertEqual(
            ArenaHapticEvent.dangerPickup.pattern,
            .impact(.heavy, intensity: 0.82)
        )
    }

    func testNearMissUsesLightImpactPattern() {
        XCTAssertEqual(
            ArenaHapticEvent.nearMiss.pattern,
            .impact(.light, intensity: 0.35)
        )
    }

    func testEnemyClearScalesWithClearSize() {
        XCTAssertEqual(
            ArenaHapticEvent.enemyClear(count: 1).pattern,
            .impact(.light, intensity: 0.42)
        )
        XCTAssertEqual(
            ArenaHapticEvent.enemyClear(count: 3).pattern,
            .impact(.medium, intensity: 0.68)
        )
        XCTAssertEqual(
            ArenaHapticEvent.enemyClear(count: 8).pattern,
            .impact(.heavy, intensity: 0.9)
        )
    }

    func testComboMilestoneScalesWithMultiplier() {
        XCTAssertEqual(
            ArenaHapticEvent.comboMilestone(multiplier: 2).pattern,
            .impact(.medium, intensity: 0.78)
        )
        XCTAssertEqual(
            ArenaHapticEvent.comboMilestone(multiplier: 4).pattern,
            .impact(.heavy, intensity: 1.0)
        )
    }

    func testShieldDeathAndNewBestUseDistinctNotificationPatterns() {
        XCTAssertEqual(
            ArenaHapticEvent.shieldExpired.pattern,
            .notification(.warning)
        )
        XCTAssertEqual(
            ArenaHapticEvent.death.pattern,
            .notification(.error)
        )
        XCTAssertEqual(
            ArenaHapticEvent.newBest.pattern,
            .notification(.success)
        )
    }
}
