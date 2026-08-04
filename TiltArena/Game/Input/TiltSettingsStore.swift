import Foundation

final class TiltSettingsStore {
    private static let currentCalibrationSpaceVersion = 3
    private static let settingsKey = "tiltArena.tiltControlSettings"
    private static let initialCalibrationKey = "tiltArena.hasCapturedInitialTiltCalibration"
    private static let calibrationSpaceVersionKey = "tiltArena.tiltCalibrationSpaceVersion"

    private let defaults: UserDefaults
    private(set) var settings: TiltControlSettings
    private var hasCapturedInitialCalibration: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = Self.loadSettings(from: defaults, key: Self.settingsKey) ?? .defaults
        hasCapturedInitialCalibration = defaults.bool(forKey: Self.initialCalibrationKey)
        migrateCalibrationSpaceIfNeeded()
    }

    var needsInitialCalibration: Bool {
        !hasCapturedInitialCalibration
    }

    func ensureInitialCalibration(using gravity: TiltGravityVector) {
        guard needsInitialCalibration, gravity.isFinite else {
            return
        }

        recalibrate(using: gravity)
        hasCapturedInitialCalibration = true
        defaults.set(true, forKey: Self.initialCalibrationKey)
        markCurrentCalibrationSpaceVersion()
    }

    func recalibrate(using gravity: TiltGravityVector) {
        guard gravity.isFinite else {
            return
        }

        var currentSettings = settings
        currentSettings.calibration = .custom(neutralGravity: gravity)
        save(currentSettings)
        markCurrentCalibrationSpaceVersion()
    }

    func selectPreset(_ preset: TiltCalibrationPreset) {
        var currentSettings = settings
        currentSettings.calibration = .defaultCalibration(for: preset)
        save(currentSettings)
        hasCapturedInitialCalibration = true
        defaults.set(true, forKey: Self.initialCalibrationKey)
        markCurrentCalibrationSpaceVersion()
    }

    func updateSensitivity(_ sensitivity: Double) {
        var currentSettings = settings
        guard sensitivity.isFinite else {
            return
        }

        currentSettings.sensitivity = min(
            TiltControlSettings.maximumSensitivity,
            max(TiltControlSettings.minimumSensitivity, sensitivity)
        )
        save(currentSettings)
    }

    func reset() {
        settings = .defaults
        hasCapturedInitialCalibration = false
        defaults.removeObject(forKey: Self.settingsKey)
        defaults.removeObject(forKey: Self.initialCalibrationKey)
        defaults.removeObject(forKey: Self.calibrationSpaceVersionKey)
    }

    private func migrateCalibrationSpaceIfNeeded() {
        guard defaults.integer(forKey: Self.calibrationSpaceVersionKey) < Self.currentCalibrationSpaceVersion else {
            return
        }

        guard defaults.data(forKey: Self.settingsKey) != nil else {
            markCurrentCalibrationSpaceVersion()
            return
        }

        var currentSettings = settings
        switch currentSettings.calibration.preset {
        case .custom:
            currentSettings.calibration = TiltControlSettings.defaults.calibration
            save(currentSettings)
            hasCapturedInitialCalibration = false
            defaults.removeObject(forKey: Self.initialCalibrationKey)
        case .standard, .flatTable, .reclined:
            currentSettings.calibration = .defaultCalibration(for: currentSettings.calibration.preset)
            save(currentSettings)
        }

        markCurrentCalibrationSpaceVersion()
    }

    private func markCurrentCalibrationSpaceVersion() {
        defaults.set(Self.currentCalibrationSpaceVersion, forKey: Self.calibrationSpaceVersionKey)
    }

    private func save(_ updatedSettings: TiltControlSettings) {
        guard let data = try? JSONEncoder().encode(updatedSettings) else {
            return
        }

        settings = updatedSettings
        defaults.set(data, forKey: Self.settingsKey)
    }

    private static func loadSettings(from defaults: UserDefaults, key: String) -> TiltControlSettings? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(TiltControlSettings.self, from: data)
    }
}
