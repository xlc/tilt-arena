import CoreGraphics
import Foundation
import UIKit

enum TiltScreenOrientation: String, Equatable {
    case landscapeLeft
    case landscapeRight

    init?(interfaceOrientation: UIInterfaceOrientation?) {
        switch interfaceOrientation {
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .landscapeLeft:
            return "LAND L"
        case .landscapeRight:
            return "LAND R"
        }
    }

    var interfaceOrientation: UIInterfaceOrientation {
        switch self {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        }
    }
}

enum TiltGravityMapper {
    static func screenGravity(
        from rawGravity: TiltGravityVector,
        orientation: TiltScreenOrientation
    ) -> TiltGravityVector {
        switch orientation {
        case .landscapeLeft:
            return TiltGravityVector(x: rawGravity.y, y: -rawGravity.x)
        case .landscapeRight:
            return TiltGravityVector(x: -rawGravity.y, y: rawGravity.x)
        }
    }
}

struct TiltInputReadout: Equatable {
    let orientation: TiltScreenOrientation
    let rawGravity: TiltGravityVector
    let screenGravity: TiltGravityVector
    let neutralGravity: TiltGravityVector
    let normalizedInput: CGVector
}

struct TiltReadoutRow: Equatable {
    let title: String
    let value: String
}

enum TiltReadoutFormatter {
    static func rows(
        for readout: TiltInputReadout?,
        fallbackOrientation: TiltScreenOrientation
    ) -> [TiltReadoutRow] {
        guard let readout else {
            return [
                TiltReadoutRow(title: "ORIENT", value: fallbackOrientation.displayName),
                TiltReadoutRow(title: "RAW", value: "--"),
                TiltReadoutRow(title: "SCREEN", value: "--"),
                TiltReadoutRow(title: "NEUTRAL", value: "--"),
                TiltReadoutRow(title: "INPUT", value: "--")
            ]
        }

        return [
            TiltReadoutRow(title: "ORIENT", value: readout.orientation.displayName),
            TiltReadoutRow(title: "RAW", value: format(readout.rawGravity)),
            TiltReadoutRow(title: "SCREEN", value: format(readout.screenGravity)),
            TiltReadoutRow(title: "NEUTRAL", value: format(readout.neutralGravity)),
            TiltReadoutRow(title: "INPUT", value: format(readout.normalizedInput))
        ]
    }

    static func gameplayRows(
        for readout: TiltInputReadout?,
        fallbackOrientation: TiltScreenOrientation
    ) -> [TiltReadoutRow] {
        guard let readout else {
            return [
                TiltReadoutRow(title: "ORIENTATION", value: fallbackOrientation.displayName),
                TiltReadoutRow(title: "MOVE INPUT", value: "--")
            ]
        }

        return [
            TiltReadoutRow(title: "ORIENTATION", value: readout.orientation.displayName),
            TiltReadoutRow(title: "MOVE INPUT", value: format(readout.normalizedInput))
        ]
    }

    private static func format(_ vector: TiltGravityVector) -> String {
        String(format: "%+.3f %+.3f", vector.x, vector.y)
    }

    private static func format(_ vector: CGVector) -> String {
        String(format: "%+.3f %+.3f", Double(vector.dx), Double(vector.dy))
    }
}
