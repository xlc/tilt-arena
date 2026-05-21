import Foundation

final class TiltSettingsStore {
    private let defaults: UserDefaults
    private let settingsKey = "tiltArena.tiltControlSettings"
    private let initialCalibrationKey = "tiltArena.hasCapturedInitialTiltCalibration"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    }

    func recalibrate(using gravity: TiltGravityVector) {
        var currentSettings = settings
        currentSettings.calibration = .custom(neutralGravity: gravity)
        settings = currentSettings
    }

    func selectPreset(_ preset: TiltCalibrationPreset) {
        var currentSettings = settings
        currentSettings.calibration = .defaultCalibration(for: preset)
        settings = currentSettings
        defaults.set(true, forKey: initialCalibrationKey)
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
    }
}
