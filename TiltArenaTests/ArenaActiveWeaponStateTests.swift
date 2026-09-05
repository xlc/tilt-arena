import XCTest
@testable import TiltArena

final class ArenaActiveWeaponStateTests: XCTestCase {
    func testRazorShieldActivationMergesCoverageAndExtendsDuration() {
        var state = ArenaRazorShieldState()
        var first = StartingWeaponConfiguration()
        first.razorShieldDuration = 3
        first.razorShieldRadius = 20
        var second = StartingWeaponConfiguration()
        second.razorShieldDuration = 1
        second.razorShieldRadius = 40

        _ = state.activate(with: first)
        let resolved = state.activate(with: second)

        XCTAssertEqual(state.timeRemaining, 3)
        XCTAssertEqual(resolved.razorShieldRadius, 40)
    }

    func testFlameTrailProtectionConsumesBoostBeforeInvulnerability() {
        var state = ArenaFlameTrailProtectionState()
        var configuration = FlameTrailConfiguration()
        configuration.duration = 1
        configuration.invulnerabilityDuration = 2
        state.activate(configuration: configuration, postWeaponSafetyDuration: 0)

        state.advance(by: 1.5)

        XCTAssertEqual(state.speedBoostTimeRemaining, 0)
        XCTAssertEqual(state.invulnerabilityTimeRemaining, 1.5)
    }

    func testTimeDilationOnlyMergesUpgradesWhileActive() {
        var state = ArenaTimeDilationState()
        let base = StartingWeaponConfiguration()
        let charged = base.applying(chargeTier: .overcharged)

        _ = state.activate(with: charged)
        XCTAssertEqual(state.activate(with: base).timeDilationRadius, charged.timeDilationRadius)
        XCTAssertFalse(state.advance(by: charged.timeDilationDuration / 2))
        XCTAssertTrue(state.isActive)

        XCTAssertTrue(state.advance(by: charged.timeDilationDuration))
        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.configuration)
        XCTAssertFalse(state.advance(by: 1))
        XCTAssertEqual(state.activate(with: base), base)
    }

    func testPostWeaponSafetyRejectsNonfiniteDurationAndExpires() {
        var state = ArenaPostWeaponSafetyState()
        state.grant(duration: .infinity)
        XCTAssertFalse(state.isActive)

        state.grant(duration: 1)
        state.advance(by: 1)
        XCTAssertFalse(state.isActive)
    }
}
