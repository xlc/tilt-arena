import Foundation

final class TiltSettingsStore {
    private static let currentCalibrationSpaceVersion = 3

    private let defaults: UserDefaults
    private let settingsKey = "tiltArena.tiltControlSettings"
    private let initialCalibrationKey = "tiltArena.hasCapturedInitialTiltCalibration"
    private let calibrationSpaceVersionKey = "tiltArena.tiltCalibrationSpaceVersion"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateCalibrationSpaceIfNeeded()
    }

    var settings: TiltControlSettings {
        get {
            guard
                let data = defaults.data(forKey: settingsKey),
                let settings = try? JSONDecoder().decode(TiltControlSettings.self, from: data)
            else {
                return .defaults
            }

            return settings
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            defaults.set(data, forKey: settingsKey)
        }
    }

    var needsInitialCalibration: Bool {
        !defaults.bool(forKey: initialCalibrationKey)
    }

    func ensureInitialCalibration(using gravity: TiltGravityVector) {
        guard needsInitialCalibration else {
            return
        }

        recalibrate(using: gravity)
        defaults.set(true, forKey: initialCalibrationKey)
        markCurrentCalibrationSpaceVersion()
    }

    func recalibrate(using gravity: TiltGravityVector) {
        var currentSettings = settings
        currentSettings.calibration = .custom(neutralGravity: gravity)
        settings = currentSettings
        markCurrentCalibrationSpaceVersion()
    }

    func selectPreset(_ preset: TiltCalibrationPreset) {
        var currentSettings = settings
        currentSettings.calibration = .defaultCalibration(for: preset)
        settings = currentSettings
        defaults.set(true, forKey: initialCalibrationKey)
        markCurrentCalibrationSpaceVersion()
    }

    func updateSensitivity(_ sensitivity: Double) {
        var currentSettings = settings
        currentSettings.sensitivity = min(
            TiltControlSettings.maximumSensitivity,
            max(TiltControlSettings.minimumSensitivity, sensitivity)
        )
        settings = currentSettings
    }

    func reset() {
        defaults.removeObject(forKey: settingsKey)
        defaults.removeObject(forKey: initialCalibrationKey)
        defaults.removeObject(forKey: calibrationSpaceVersionKey)
    }

    private func migrateCalibrationSpaceIfNeeded() {
        guard defaults.integer(forKey: calibrationSpaceVersionKey) < Self.currentCalibrationSpaceVersion else {
            return
        }

        guard defaults.data(forKey: settingsKey) != nil else {
            markCurrentCalibrationSpaceVersion()
            return
        }

        var currentSettings = settings
        switch currentSettings.calibration.preset {
        case .custom:
            currentSettings.calibration = TiltControlSettings.defaults.calibration
            settings = currentSettings
            defaults.removeObject(forKey: initialCalibrationKey)
        case .standard, .flatTable, .reclined:
            currentSettings.calibration = .defaultCalibration(for: currentSettings.calibration.preset)
            settings = currentSettings
        }

        markCurrentCalibrationSpaceVersion()
    }

    private func markCurrentCalibrationSpaceVersion() {
        defaults.set(Self.currentCalibrationSpaceVersion, forKey: calibrationSpaceVersionKey)
    }
}
