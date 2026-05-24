import SpriteKit

enum ArenaThemeKind: String, CaseIterable, Codable, Equatable {
    case darkTacticalRadar
    case whitePrecisionBoard

    var shortTitle: String {
        switch self {
        case .darkTacticalRadar:
            return "DARK"
        case .whitePrecisionBoard:
            return "WHITE"
        }
    }

    var theme: ArenaTheme {
        switch self {
        case .darkTacticalRadar:
            return .darkTacticalRadar
        case .whitePrecisionBoard:
            return .whitePrecisionBoard
        }
    }
}

struct ArenaTheme {
    let kind: ArenaThemeKind
    let backgroundColor: SKColor
    let gridColor: SKColor
    let borderColor: SKColor
    let panelFillColor: SKColor
    let panelStrokeColor: SKColor
    let playerColor: SKColor
    let playerAccentColor: SKColor
    let enemyColor: SKColor
    let pickupAmber: SKColor
    let pickupBlue: SKColor
    let pickupViolet: SKColor
    let flameTrailFillColor: SKColor

    static let darkTacticalRadar = ArenaTheme(
        kind: .darkTacticalRadar,
        backgroundColor: SKColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 1.00),
        gridColor: SKColor(red: 0.12, green: 0.35, blue: 0.48, alpha: 0.28),
        borderColor: SKColor(red: 0.37, green: 0.66, blue: 0.78, alpha: 0.70),
        panelFillColor: SKColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 0.84),
        panelStrokeColor: SKColor(red: 0.37, green: 0.66, blue: 0.78, alpha: 0.35),
        playerColor: SKColor(red: 0.97, green: 0.98, blue: 1.00, alpha: 1.00),
        playerAccentColor: SKColor(red: 0.09, green: 0.78, blue: 1.00, alpha: 1.00),
        enemyColor: SKColor(red: 1.00, green: 0.16, blue: 0.16, alpha: 1.00),
        pickupAmber: SKColor(red: 1.00, green: 0.75, blue: 0.20, alpha: 1.00),
        pickupBlue: SKColor(red: 0.16, green: 0.78, blue: 1.00, alpha: 1.00),
        pickupViolet: SKColor(red: 0.55, green: 0.36, blue: 1.00, alpha: 1.00),
        flameTrailFillColor: SKColor(red: 1.00, green: 0.46, blue: 0.12, alpha: 0.24)
    )

    static let whitePrecisionBoard = ArenaTheme(
        kind: .whitePrecisionBoard,
        backgroundColor: SKColor(red: 0.95, green: 0.96, blue: 0.94, alpha: 1.00),
        gridColor: SKColor(red: 0.37, green: 0.41, blue: 0.43, alpha: 0.24),
        borderColor: SKColor(red: 0.10, green: 0.12, blue: 0.13, alpha: 0.74),
        panelFillColor: SKColor(red: 1.00, green: 1.00, blue: 0.98, alpha: 0.94),
        panelStrokeColor: SKColor(red: 0.10, green: 0.12, blue: 0.13, alpha: 0.24),
        playerColor: SKColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1.00),
        playerAccentColor: SKColor(red: 0.09, green: 0.78, blue: 1.00, alpha: 1.00),
        enemyColor: SKColor(red: 1.00, green: 0.16, blue: 0.16, alpha: 1.00),
        pickupAmber: SKColor(red: 1.00, green: 0.75, blue: 0.20, alpha: 1.00),
        pickupBlue: SKColor(red: 0.16, green: 0.78, blue: 1.00, alpha: 1.00),
        pickupViolet: SKColor(red: 0.55, green: 0.36, blue: 1.00, alpha: 1.00),
        flameTrailFillColor: SKColor(red: 1.00, green: 0.54, blue: 0.18, alpha: 0.18)
    )
}
