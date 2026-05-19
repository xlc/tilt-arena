import XCTest
@testable import TiltArena

final class TiltSettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TiltSettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testInitialCalibrationCapturesOnlyOnce() {
        let store = TiltSettingsStore(defaults: defaults)

        store.ensureInitialCalibration(using: TiltGravityVector(x: 0.2, y: -0.4))
        store.ensureInitialCalibration(using: TiltGravityVector(x: -0.3, y: 0.1))

        XCTAssertFalse(store.needsInitialCalibration)
        XCTAssertEqual(store.settings.calibration.preset, .custom)
        XCTAssertEqual(store.settings.calibration.neutralGravity, TiltGravityVector(x: 0.2, y: -0.4))
    }

    func testSensitivityUpdatesArePersistedAndClamped() {
        let store = TiltSettingsStore(defaults: defaults)

        store.updateSensitivity(10)

        XCTAssertEqual(store.settings.sensitivity, TiltControlSettings.maximumSensitivity)

        store.updateSensitivity(-10)

        XCTAssertEqual(store.settings.sensitivity, TiltControlSettings.minimumSensitivity)
    }

    func testPresetSelectionMarksCalibrationComplete() {
        let store = TiltSettingsStore(defaults: defaults)

        store.selectPreset(.flatTable)

        XCTAssertFalse(store.needsInitialCalibration)
        XCTAssertEqual(store.settings.calibration, .defaultCalibration(for: .flatTable))
    }
}
