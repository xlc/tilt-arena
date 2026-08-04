import CoreGraphics
import Foundation

struct TiltSignalConfiguration: Equatable {
    var deadZoneDegrees: Double = 3
    var maximumTiltDegrees: Double = 25
    var smoothingDuration: TimeInterval = 0.11

    var deadZoneMagnitude: Double {
        sin(deadZoneDegrees * .pi / 180)
    }

    var maximumTiltMagnitude: Double {
        sin(maximumTiltDegrees * .pi / 180)
    }
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
        guard gravity.isFinite else {
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
        let neutral = settings.calibration.neutralGravity
        guard gravity.isFinite, neutral.isFinite else {
            return .zero
        }

        let rawInput = CGVector(
            dx: gravity.x - neutral.x,
            dy: gravity.y - neutral.y
        )
        let magnitude = rawInput.length
        let deadZone = configuration.deadZoneMagnitude
        let maximumTilt = configuration.maximumTiltMagnitude

        guard magnitude.isFinite, deadZone.isFinite, maximumTilt.isFinite else {
            return .zero
        }

        guard magnitude > deadZone else {
            return .zero
        }

        let activeRange = max(0.001, maximumTilt - deadZone)
        let normalizedMagnitude = min(1, (magnitude - deadZone) / activeRange)
        let scaledMagnitude = min(1, normalizedMagnitude * settings.clampedSensitivity)

        let direction = rawInput.normalized

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
