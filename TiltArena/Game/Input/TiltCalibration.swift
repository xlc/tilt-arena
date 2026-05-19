import CoreGraphics
import Foundation

enum TiltCalibrationPreset: String, CaseIterable, Codable {
    case standard
    case flatTable
    case reclined
    case custom

    var defaultNeutralGravity: TiltGravityVector {
        switch self {
        case .standard:
            TiltGravityVector(x: 0, y: -0.35)
        case .flatTable:
            TiltGravityVector(x: 0, y: 0)
        case .reclined:
            TiltGravityVector(x: 0, y: -0.65)
        case .custom:
            TiltGravityVector(x: 0, y: -0.35)
        }
    }
}

struct TiltGravityVector: Codable, Equatable {
    var x: Double
    var y: Double
}

struct TiltCalibration: Codable, Equatable {
    var preset: TiltCalibrationPreset
    var neutralGravity: TiltGravityVector

    static func defaultCalibration(for preset: TiltCalibrationPreset) -> TiltCalibration {
        TiltCalibration(preset: preset, neutralGravity: preset.defaultNeutralGravity)
    }

    static func custom(neutralGravity: TiltGravityVector) -> TiltCalibration {
        TiltCalibration(preset: .custom, neutralGravity: neutralGravity)
    }
}

struct TiltControlSettings: Codable, Equatable {
    static let defaultSensitivity = 1.0
    static let minimumSensitivity = 0.6
    static let maximumSensitivity = 1.4

    var calibration: TiltCalibration
    var sensitivity: Double

    static let defaults = TiltControlSettings(
        calibration: .defaultCalibration(for: .standard),
        sensitivity: defaultSensitivity
    )

    var clampedSensitivity: Double {
        min(Self.maximumSensitivity, max(Self.minimumSensitivity, sensitivity))
    }
}
