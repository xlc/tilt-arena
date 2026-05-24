import XCTest
@testable import TiltArena

final class ArenaUISceneStateTests: XCTestCase {
    func testCalibrationPreviewLocksCurrentLandscapeOrientation() {
        XCTAssertTrue(ArenaUISceneState.calibrationPreview.requiresLockedRunOrientation)
    }

    func testMenuStatesDoNotLockRunOrientation() {
        XCTAssertFalse(ArenaUISceneState.home.requiresLockedRunOrientation)
        XCTAssertFalse(ArenaUISceneState.modeSelect.requiresLockedRunOrientation)
        XCTAssertFalse(ArenaUISceneState.awards.requiresLockedRunOrientation)
        XCTAssertFalse(ArenaUISceneState.options.requiresLockedRunOrientation)
        XCTAssertFalse(ArenaUISceneState.developerTuning.requiresLockedRunOrientation)
    }
}
