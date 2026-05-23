import CoreGraphics
import XCTest
@testable import TiltArena

final class TiltGravityMappingTests: XCTestCase {
    private let settings = TiltControlSettings(
        calibration: .custom(neutralGravity: TiltGravityVector(x: 0, y: 0)),
        sensitivity: 1
    )

    func testLandscapeLeftMapsRawYToScreenXAndRawXToScreenY() {
        let screenGravity = TiltGravityMapper.screenGravity(
            from: TiltGravityVector(x: 0.25, y: -0.4),
            orientation: .landscapeLeft
        )

        XCTAssertEqual(screenGravity.x, -0.4, accuracy: 0.0001)
        XCTAssertEqual(screenGravity.y, -0.25, accuracy: 0.0001)
    }

    func testLandscapeRightMapsRawYToScreenXAndRawXToScreenYWithOppositeSigns() {
        let screenGravity = TiltGravityMapper.screenGravity(
            from: TiltGravityVector(x: -0.25, y: 0.4),
            orientation: .landscapeRight
        )

        XCTAssertEqual(screenGravity.x, -0.4, accuracy: 0.0001)
        XCTAssertEqual(screenGravity.y, -0.25, accuracy: 0.0001)
    }

    func testLandscapeLeftVisibleTiltDirectionsDriveScreenInputAxes() {
        XCTAssertGreaterThan(input(from: TiltGravityVector(x: 0, y: 0.3), orientation: .landscapeLeft).dx, 0)
        XCTAssertLessThan(input(from: TiltGravityVector(x: 0, y: -0.3), orientation: .landscapeLeft).dx, 0)
        XCTAssertGreaterThan(input(from: TiltGravityVector(x: -0.3, y: 0), orientation: .landscapeLeft).dy, 0)
        XCTAssertLessThan(input(from: TiltGravityVector(x: 0.3, y: 0), orientation: .landscapeLeft).dy, 0)
    }

    func testLandscapeRightVisibleTiltDirectionsDriveScreenInputAxes() {
        XCTAssertGreaterThan(input(from: TiltGravityVector(x: 0, y: -0.3), orientation: .landscapeRight).dx, 0)
        XCTAssertLessThan(input(from: TiltGravityVector(x: 0, y: 0.3), orientation: .landscapeRight).dx, 0)
        XCTAssertGreaterThan(input(from: TiltGravityVector(x: 0.3, y: 0), orientation: .landscapeRight).dy, 0)
        XCTAssertLessThan(input(from: TiltGravityVector(x: -0.3, y: 0), orientation: .landscapeRight).dy, 0)
    }

    func testReadoutFormatterUsesStableCompactRows() {
        let readout = TiltInputReadout(
            orientation: .landscapeLeft,
            rawGravity: TiltGravityVector(x: 0.1234, y: -0.9876),
            screenGravity: TiltGravityVector(x: -0.9876, y: -0.1234),
            neutralGravity: TiltGravityVector(x: 0, y: 0.35),
            normalizedInput: CGVector(dx: 0.5, dy: -0.25)
        )

        XCTAssertEqual(
            TiltReadoutFormatter.rows(for: readout, fallbackOrientation: .landscapeRight),
            [
                TiltReadoutRow(title: "ORIENT", value: "LAND L"),
                TiltReadoutRow(title: "RAW", value: "+0.123 -0.988"),
                TiltReadoutRow(title: "SCREEN", value: "-0.988 -0.123"),
                TiltReadoutRow(title: "NEUTRAL", value: "+0.000 +0.350"),
                TiltReadoutRow(title: "INPUT", value: "+0.500 -0.250")
            ]
        )
    }

    private func input(from rawGravity: TiltGravityVector, orientation: TiltScreenOrientation) -> CGVector {
        TiltSignalProcessor().normalizedInputVector(
            gravity: TiltGravityMapper.screenGravity(from: rawGravity, orientation: orientation),
            settings: settings
        )
    }
}
