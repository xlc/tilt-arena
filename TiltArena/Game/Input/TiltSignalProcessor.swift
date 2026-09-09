import CoreGraphics
import Foundation
import simd

struct TiltSignalConfiguration: Equatable {
    var deadZoneDegrees: Double = 3
    var maximumTiltDegrees: Double = 25
    var smoothingDuration: TimeInterval = 0.11
}

struct TiltSignalProcessor {
    var configuration = TiltSignalConfiguration()
    private(set) var smoothedInput = CGVector.zero

    mutating func reset() {
        smoothedInput = .zero
    }

    mutating func inputVector(
        gravity: TiltGravityVector,
        settings: TiltControlSettings,
        deltaTime: TimeInterval
    ) -> CGVector {
        guard gravity.unitVector != nil else {
            reset()
            return .zero
        }
        if !smoothedInput.isFinite {
            reset()
        }

        let target = normalizedInputVector(gravity: gravity, settings: settings)
        let smoothing = smoothingAlpha(deltaTime: deltaTime)

        smoothedInput = CGVector(
            dx: smoothedInput.dx + (target.dx - smoothedInput.dx) * smoothing,
            dy: smoothedInput.dy + (target.dy - smoothedInput.dy) * smoothing
        )

        guard smoothedInput.isFinite else {
            reset()
            return .zero
        }

        if smoothedInput.length < 0.001 {
            smoothedInput = .zero
        }

        return smoothedInput.clamped(toMaximumLength: 1)
    }

    func normalizedInputVector(gravity: TiltGravityVector, settings: TiltControlSettings) -> CGVector {
        guard let current = gravity.unitVector,
              let neutral = settings.calibration.neutralGravity.unitVector else {
            return .zero
        }

        // Measure the angle around the calibrated posture. Keeping depth avoids
        // losing the upward range when a reclined device tilts past vertical.
        let projectedRight = SIMD3<Double>(1, 0, 0) - neutral * neutral.x
        let right = simd_length(projectedRight) > 0.000_001
            ? simd_normalize(projectedRight)
            : simd_normalize(simd_cross(neutral, SIMD3<Double>(0, 1, 0)))
        let upward = simd_cross(right, neutral)
        let tangent = CGVector(dx: simd_dot(current, right), dy: simd_dot(current, upward))
        let magnitude = atan2(Double(tangent.length), simd_dot(current, neutral))
        let deadZone = max(0, configuration.deadZoneDegrees) * .pi / 180
        let maximumTilt = configuration.maximumTiltDegrees * .pi / 180

        guard magnitude.isFinite, deadZone.isFinite, maximumTilt.isFinite else {
            return .zero
        }

        guard magnitude > deadZone, tangent.length > 0.000_001 else {
            return .zero
        }

        let activeRange = max(0.001, maximumTilt - deadZone)
        let normalizedMagnitude = (magnitude - deadZone) / activeRange
        let scaledMagnitude = min(1, normalizedMagnitude * settings.clampedSensitivity)

        let direction = tangent.normalized

        return CGVector(
            dx: direction.dx * CGFloat(scaledMagnitude),
            dy: direction.dy * CGFloat(scaledMagnitude)
        )
    }

    private func smoothingAlpha(deltaTime: TimeInterval) -> CGFloat {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return 0
        }

        let duration = max(0.001, configuration.smoothingDuration)
        return CGFloat(1 - exp(-deltaTime / duration))
    }
}
