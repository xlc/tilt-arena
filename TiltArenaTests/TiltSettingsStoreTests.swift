import XCTest
@testable import TiltArena

final class TiltSettingsStoreTests: XCTestCase {
    private static let settingsKey = "tiltArena.tiltControlSettings"
    private static let initialCalibrationKey = "tiltArena.hasCapturedInitialTiltCalibration"
    private static let calibrationSpaceVersionKey = "tiltArena.tiltCalibrationSpaceVersion"

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

    func testInitialCalibrationRejectsNonFiniteGravity() {
        let store = TiltSettingsStore(defaults: defaults)

        store.ensureInitialCalibration(using: TiltGravityVector(x: .nan, y: 0))

        XCTAssertTrue(store.needsInitialCalibration)
        XCTAssertEqual(store.settings, .defaults)
    }

    func testCorruptSettingsResetCalibrationStateInsteadOfTrustingStaleFlag() {
        defaults.set(Data("not-json".utf8), forKey: Self.settingsKey)
        defaults.set(true, forKey: Self.initialCalibrationKey)
        defaults.set(3, forKey: Self.calibrationSpaceVersionKey)

        let store = TiltSettingsStore(defaults: defaults)

        XCTAssertTrue(store.needsInitialCalibration)
        XCTAssertEqual(store.settings, .defaults)
        XCTAssertNil(defaults.data(forKey: Self.settingsKey))
        XCTAssertFalse(defaults.bool(forKey: Self.initialCalibrationKey))
    }

    func testMissingSettingsResetOrphanedCalibrationFlag() {
        defaults.set(true, forKey: Self.initialCalibrationKey)

        let store = TiltSettingsStore(defaults: defaults)

        XCTAssertTrue(store.needsInitialCalibration)
        XCTAssertFalse(defaults.bool(forKey: Self.initialCalibrationKey))
    }

    func testSensitivityUpdatesArePersistedAndClamped() {
        let store = TiltSettingsStore(defaults: defaults)

        store.updateSensitivity(10)

        XCTAssertEqual(store.settings.sensitivity, TiltControlSettings.maximumSensitivity)

        store.updateSensitivity(-10)

        XCTAssertEqual(store.settings.sensitivity, TiltControlSettings.minimumSensitivity)
    }

    func testSensitivityUpdateRejectsNonFiniteValue() {
        let store = TiltSettingsStore(defaults: defaults)

        store.updateSensitivity(.nan)

        XCTAssertEqual(store.settings.sensitivity, TiltControlSettings.defaultSensitivity)
    }

    func testPresetSelectionMarksCalibrationComplete() {
        let store = TiltSettingsStore(defaults: defaults)

        store.selectPreset(.flatTable)

        XCTAssertFalse(store.needsInitialCalibration)
        XCTAssertEqual(store.settings.calibration, .defaultCalibration(for: .flatTable))
    }

    func testResetRestoresDefaultSettingsAndInitialCalibrationNeed() {
        let store = TiltSettingsStore(defaults: defaults)
        store.selectPreset(.reclined)
        store.updateSensitivity(1.3)

        store.reset()

        XCTAssertTrue(store.needsInitialCalibration)
        XCTAssertEqual(store.settings, .defaults)
    }

    func testLegacyCustomCalibrationMigratesToScreenSpaceDefaults() throws {
        try writeLegacySettings(
            TiltControlSettings(
                calibration: .custom(neutralGravity: TiltGravityVector(x: 0.2, y: -0.4)),
                sensitivity: 1.3
            )
        )

        let store = TiltSettingsStore(defaults: defaults)

        XCTAssertTrue(store.needsInitialCalibration)
        XCTAssertEqual(store.settings.calibration, TiltControlSettings.defaults.calibration)
        XCTAssertEqual(store.settings.sensitivity, 1.3)
    }

    func testLegacyPresetCalibrationKeepsCapturedState() throws {
        let legacySettings = TiltControlSettings(
            calibration: .defaultCalibration(for: .flatTable),
            sensitivity: 1.2
        )
        try writeLegacySettings(legacySettings)

        let store = TiltSettingsStore(defaults: defaults)

        XCTAssertFalse(store.needsInitialCalibration)
        XCTAssertEqual(store.settings, legacySettings)
    }

    func testVersionTwoCustomCalibrationMigratesAfterScreenAxisFlip() throws {
        try writeLegacySettings(
            TiltControlSettings(
                calibration: .custom(neutralGravity: TiltGravityVector(x: 0.2, y: -0.4)),
                sensitivity: 1.3
            ),
            calibrationSpaceVersion: 2
        )

        let store = TiltSettingsStore(defaults: defaults)

        XCTAssertTrue(store.needsInitialCalibration)
        XCTAssertEqual(store.settings.calibration, TiltControlSettings.defaults.calibration)
        XCTAssertEqual(store.settings.sensitivity, 1.3)
        XCTAssertEqual(defaults.integer(forKey: Self.calibrationSpaceVersionKey), 3)
    }

    func testVersionTwoPresetCalibrationRefreshesAfterScreenAxisFlip() throws {
        try writeLegacySettings(
            TiltControlSettings(
                calibration: TiltCalibration(
                    preset: .standard,
                    neutralGravity: TiltGravityVector(x: 0, y: -0.35)
                ),
                sensitivity: 1.2
            ),
            calibrationSpaceVersion: 2
        )

        let store = TiltSettingsStore(defaults: defaults)

        XCTAssertFalse(store.needsInitialCalibration)
        XCTAssertEqual(store.settings.calibration, .defaultCalibration(for: .standard))
        XCTAssertEqual(store.settings.sensitivity, 1.2)
        XCTAssertEqual(defaults.integer(forKey: Self.calibrationSpaceVersionKey), 3)
    }

    private func writeLegacySettings(
        _ settings: TiltControlSettings,
        calibrationSpaceVersion: Int? = nil
    ) throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: Self.settingsKey)
        defaults.set(true, forKey: Self.initialCalibrationKey)
        if let calibrationSpaceVersion {
            defaults.set(calibrationSpaceVersion, forKey: Self.calibrationSpaceVersionKey)
        }
    }
}
