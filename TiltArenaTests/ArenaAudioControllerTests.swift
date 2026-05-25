import XCTest
@testable import TiltArena

final class ArenaAudioControllerTests: XCTestCase {
    func testRequiredEventsMapToDistinctCueFamilies() {
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .pickup).family, .pickup)
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .comboMilestone).family, .comboMilestone)
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .shieldWarning).family, .shieldWarning)
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .shieldExpired).family, .shieldExpired)
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .death).family, .death)
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .newBest).family, .newBest)
    }

    func testMajorEnemyClearsUseDistinctCueFromSmallClears() {
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .enemyClear(count: 1)).family, .enemyClear)
        XCTAssertEqual(ArenaAudioCueCatalog.cue(for: .enemyClear(count: 8)).family, .majorEnemyClear)
        XCTAssertGreaterThan(
            ArenaAudioCueCatalog.cue(for: .enemyClear(count: 8)).duration,
            ArenaAudioCueCatalog.cue(for: .enemyClear(count: 1)).duration
        )
    }

    func testPlaybackLimiterSuppressesRepeatedHighVolumeEventsInsideCooldown() {
        var limiter = ArenaAudioPlaybackLimiter()

        XCTAssertNotNil(limiter.cueIfAllowed(for: .shieldWarning, at: 1.0))
        XCTAssertNil(limiter.cueIfAllowed(for: .shieldWarning, at: 1.1))
        XCTAssertNotNil(limiter.cueIfAllowed(for: .shieldWarning, at: 1.36))
    }

    func testPlaybackLimiterUsesSeparateCooldownsPerCueFamily() {
        var limiter = ArenaAudioPlaybackLimiter()

        XCTAssertNotNil(limiter.cueIfAllowed(for: .enemyClear(count: 1), at: 2.0))
        XCTAssertNil(limiter.cueIfAllowed(for: .enemyClear(count: 1), at: 2.04))
        XCTAssertNotNil(limiter.cueIfAllowed(for: .enemyClear(count: 8), at: 2.04))
    }
}
