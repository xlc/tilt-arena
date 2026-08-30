import Foundation
import Logging

final class TiltSettingsStore {
    private static let currentCalibrationSpaceVersion = 3
    private static let settingsKey = "tiltArena.tiltControlSettings"
    private static let initialCalibrationKey = "tiltArena.hasCapturedInitialTiltCalibration"
    private static let calibrationSpaceVersionKey = "tiltArena.tiltCalibrationSpaceVersion"

    private let defaults: UserDefaults
    private let logger: Logger
    private(set) var settings: TiltControlSettings
    private var hasCapturedInitialCalibration: Bool

    init(
        defaults: UserDefaults = .standard,
        logger: Logger = AppDiagnostics.logger(.input)
    ) {
        self.defaults = defaults
        self.logger = logger
        if let data = defaults.data(forKey: Self.settingsKey) {
            do {
                settings = try JSONDecoder().decode(TiltControlSettings.self, from: data)
                hasCapturedInitialCalibration = defaults.bool(forKey: Self.initialCalibrationKey)
            } catch {
                settings = .defaults
                hasCapturedInitialCalibration = false
                defaults.removeObject(forKey: Self.settingsKey)
                defaults.removeObject(forKey: Self.initialCalibrationKey)
                defaults.removeObject(forKey: Self.calibrationSpaceVersionKey)
                logger.warning("input.settings_load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
            }
        } else {
            settings = .defaults
            hasCapturedInitialCalibration = false
            defaults.removeObject(forKey: Self.initialCalibrationKey)
        }
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
            logger.warning("input.calibration_rejected", metadata: [
                "reason": "nonfinite_gravity"
            ])
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
        logger.info("input.preset_selected", metadata: [
            "preset": "\(preset.rawValue)"
        ])
    }

    func updateSensitivity(_ sensitivity: Double) {
        var currentSettings = settings
        guard sensitivity.isFinite else {
            logger.warning("input.sensitivity_rejected", metadata: [
                "reason": "nonfinite_value"
            ])
            return
        }

        currentSettings.sensitivity = min(
            TiltControlSettings.maximumSensitivity,
            max(TiltControlSettings.minimumSensitivity, sensitivity)
        )
        save(currentSettings)
        logger.info("input.sensitivity_changed", metadata: [
            "value": "\(currentSettings.sensitivity)"
        ])
    }

    func reset() {
        settings = .defaults
        hasCapturedInitialCalibration = false
        defaults.removeObject(forKey: Self.settingsKey)
        defaults.removeObject(forKey: Self.initialCalibrationKey)
        defaults.removeObject(forKey: Self.calibrationSpaceVersionKey)
        logger.notice("input.settings_reset")
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
        logger.notice("input.calibration_migrated", metadata: [
            "version": "\(Self.currentCalibrationSpaceVersion)"
        ])
    }

    private func markCurrentCalibrationSpaceVersion() {
        defaults.set(Self.currentCalibrationSpaceVersion, forKey: Self.calibrationSpaceVersionKey)
    }

    private func save(_ updatedSettings: TiltControlSettings) {
        do {
            let data = try JSONEncoder().encode(updatedSettings)
            settings = updatedSettings
            defaults.set(data, forKey: Self.settingsKey)
        } catch {
            logger.error("input.settings_save_failed", error: error)
        }
    }

}
