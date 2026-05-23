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
        XCTAssertEqual(input.dy, 0, accuracy: 0.0001)
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
}
