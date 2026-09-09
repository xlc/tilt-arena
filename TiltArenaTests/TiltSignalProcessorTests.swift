import CoreGraphics
import XCTest
@testable import TiltArena

final class TiltSignalProcessorTests: XCTestCase {
    func testDeadZoneSuppressesTinyTilt() {
        var processor = TiltSignalProcessor(
            configuration: TiltSignalConfiguration(deadZoneDegrees: 3, maximumTiltDegrees: 25, smoothingDuration: 0.11)
        )

        let neutralGravity = TiltControlSettings.defaults.calibration.neutralGravity
        let input = processor.inputVector(
            gravity: TiltGravityVector(x: neutralGravity.x + 0.01, y: neutralGravity.y),
            settings: .defaults,
            deltaTime: 1
        )

        XCTAssertEqual(input.dx, 0, accuracy: 0.0001)
        XCTAssertEqual(input.dy, 0, accuracy: 0.0001)
    }

    func testCalibrationOffsetCreatesRelativeNeutral() {
        var processor = TiltSignalProcessor()
        let settings = TiltControlSettings(
            calibration: .custom(neutralGravity: TiltGravityVector(x: 0.2, y: -0.4)),
            sensitivity: 1
        )

        let input = processor.inputVector(
            gravity: TiltGravityVector(x: 0.35, y: -0.4),
            settings: settings,
            deltaTime: 1
        )

        XCTAssertGreaterThan(input.dx, 0)
        XCTAssertEqual(processor.normalizedInputVector(
            gravity: settings.calibration.neutralGravity,
            settings: settings
        ), .zero)
    }

    func testSensitivityScalesAndClampsInput() {
        var slowProcessor = TiltSignalProcessor()
        var fastProcessor = TiltSignalProcessor()
        let neutralGravity = TiltControlSettings.defaults.calibration.neutralGravity
        let gravity = TiltGravityVector(x: neutralGravity.x + 0.2, y: neutralGravity.y)

        let slowInput = slowProcessor.inputVector(
            gravity: gravity,
            settings: TiltControlSettings(calibration: .defaultCalibration(for: .standard), sensitivity: 0.6),
            deltaTime: 1
        )
        let fastInput = fastProcessor.inputVector(
            gravity: gravity,
            settings: TiltControlSettings(calibration: .defaultCalibration(for: .standard), sensitivity: 1.4),
            deltaTime: 1
        )

        XCTAssertLessThan(slowInput.length, fastInput.length)
        XCTAssertLessThanOrEqual(fastInput.length, 1.0001)
    }

    func testSmoothingMovesTowardTargetOverTime() {
        var processor = TiltSignalProcessor(
            configuration: TiltSignalConfiguration(deadZoneDegrees: 3, maximumTiltDegrees: 25, smoothingDuration: 0.2)
        )
        let settings = TiltControlSettings(calibration: .defaultCalibration(for: .standard), sensitivity: 1)
        let neutralGravity = settings.calibration.neutralGravity

        let firstInput = processor.inputVector(
            gravity: TiltGravityVector(x: neutralGravity.x + 0.3, y: neutralGravity.y),
            settings: settings,
            deltaTime: 1.0 / 60.0
        )
        let laterInput = processor.inputVector(
            gravity: TiltGravityVector(x: neutralGravity.x + 0.3, y: neutralGravity.y),
            settings: settings,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertGreaterThan(laterInput.length, firstInput.length)
        XCTAssertLessThan(firstInput.length, 1)
    }

    func testNonFiniteGravityCannotPoisonSmoothedInput() {
        var processor = TiltSignalProcessor()
        let settings = TiltControlSettings(
            calibration: .custom(neutralGravity: TiltGravityVector(x: 0, y: 0)),
            sensitivity: 1
        )

        let invalidInput = processor.inputVector(
            gravity: TiltGravityVector(x: .nan, y: 0),
            settings: settings,
            deltaTime: 1.0 / 60.0
        )
        let recoveredInput = processor.inputVector(
            gravity: TiltGravityVector(x: 0.3, y: 0),
            settings: settings,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertEqual(invalidInput, .zero)
        XCTAssertTrue(recoveredInput.isFinite)
        XCTAssertGreaterThan(recoveredInput.dx, 0)
    }

    func testNonFiniteCalibrationProducesSafeZeroInput() {
        let processor = TiltSignalProcessor()
        let settings = TiltControlSettings(
            calibration: .custom(neutralGravity: TiltGravityVector(x: .infinity, y: 0)),
            sensitivity: 1
        )

        let input = processor.normalizedInputVector(
            gravity: TiltGravityVector(x: 0.3, y: 0),
            settings: settings
        )

        XCTAssertEqual(input, .zero)
    }

    func testAllSensitivitiesReachEqualSpeedInEveryDirectionAndPosture() {
        let processor = TiltSignalProcessor()
        let bounds = CGRect(x: 0, y: 0, width: 718, height: 377)
        for pitch in [0.0, asin(0.35), asin(0.65), 75 * .pi / 180] {
            let calibration = TiltCalibration.custom(neutralGravity: tiltedGravity(pitch: pitch, angle: 0, heading: 0))
            for sensitivity in [0.6, 0.8, 1.0, 1.2, 1.4] {
                for heading in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
                    let input = processor.normalizedInputVector(
                        gravity: tiltedGravity(pitch: pitch, angle: 42 * .pi / 180, heading: heading),
                        settings: TiltControlSettings(calibration: calibration, sensitivity: sensitivity)
                    )
                    XCTAssertEqual(input.dx, cos(heading), accuracy: 0.0001)
                    XCTAssertEqual(input.dy, sin(heading), accuracy: 0.0001)
                    var movement = PlayerMovementController()
                    _ = movement.reset(in: bounds)
                    let state = movement.update(input: input, deltaTime: 1 / 60, arenaBounds: bounds)
                    XCTAssertEqual(state.velocity.length, movement.configuration.maximumSpeed(in: bounds), accuracy: 0.0001)
                }
            }
        }
    }

    func testResponseIncreasesMonotonicallyAtLowSensitivity() {
        let processor = TiltSignalProcessor()
        let settings = TiltControlSettings(calibration: .defaultCalibration(for: .flatTable), sensitivity: 0.6)
        var previous: CGFloat = 0
        for degrees in 0...50 {
            let input = processor.normalizedInputVector(
                gravity: tiltedGravity(pitch: 0, angle: Double(degrees) * .pi / 180, heading: 0),
                settings: settings
            )
            XCTAssertGreaterThanOrEqual(input.length + 0.000_001, previous)
            XCTAssertLessThanOrEqual(input.length, 1)
            previous = input.length
        }
        XCTAssertEqual(previous, 1, accuracy: 0.0001)
    }

    func testZeroAndInvalidDepthProduceSafeInput() {
        let processor = TiltSignalProcessor()
        for gravity in [TiltGravityVector(x: 0, y: 0, z: 0), TiltGravityVector(x: 0, y: 0, z: .nan)] {
            XCTAssertEqual(processor.normalizedInputVector(gravity: gravity, settings: .defaults), .zero)
        }
    }

    private func tiltedGravity(pitch: Double, angle: Double, heading: Double) -> TiltGravityVector {
        TiltGravityVector(
            x: sin(angle) * cos(heading),
            y: sin(pitch) * cos(angle) + cos(pitch) * sin(angle) * sin(heading),
            z: -cos(pitch) * cos(angle) + sin(pitch) * sin(angle) * sin(heading)
        )
    }
}
