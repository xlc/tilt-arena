import CoreGraphics
import Foundation
import simd

enum TiltCalibrationPreset: String, CaseIterable, Codable {
    case standard
    case flatTable
    case reclined
    case custom

    var defaultNeutralGravity: TiltGravityVector {
        switch self {
        case .standard:
            TiltGravityVector(x: 0, y: 0.35)
        case .flatTable:
            TiltGravityVector(x: 0, y: 0)
        case .reclined:
            TiltGravityVector(x: 0, y: 0.65)
        case .custom:
            TiltGravityVector(x: 0, y: 0.35)
        }
    }
}

struct TiltGravityVector: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double

    init(x: Double, y: Double, z: Double? = nil) {
        self.x = x
        self.y = y
        self.z = z ?? -sqrt(max(0, 1 - x * x - y * y))
    }

    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }

    var unitVector: SIMD3<Double>? {
        let vector = SIMD3(x, y, z)
        let length = simd_length(vector)
        guard isFinite, length.isFinite, length > 0.000_001 else {
            return nil
        }
        return vector / length
    }
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
        guard sensitivity.isFinite else {
            return Self.defaultSensitivity
        }

        return min(Self.maximumSensitivity, max(Self.minimumSensitivity, sensitivity))
    }
}
