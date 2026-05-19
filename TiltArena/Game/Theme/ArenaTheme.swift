import SpriteKit

struct ArenaTheme {
    let backgroundColor: SKColor
    let gridColor: SKColor
    let borderColor: SKColor
    let playerColor: SKColor
    let playerAccentColor: SKColor
    let enemyColor: SKColor
    let pickupAmber: SKColor
    let pickupBlue: SKColor
    let pickupViolet: SKColor

    static let darkTacticalRadar = ArenaTheme(
        backgroundColor: SKColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 1.00),
        gridColor: SKColor(red: 0.12, green: 0.35, blue: 0.48, alpha: 0.28),
        borderColor: SKColor(red: 0.37, green: 0.66, blue: 0.78, alpha: 0.70),
        playerColor: SKColor(red: 0.97, green: 0.98, blue: 1.00, alpha: 1.00),
        playerAccentColor: SKColor(red: 0.09, green: 0.78, blue: 1.00, alpha: 1.00),
        enemyColor: SKColor(red: 1.00, green: 0.16, blue: 0.16, alpha: 1.00),
        pickupAmber: SKColor(red: 1.00, green: 0.75, blue: 0.20, alpha: 1.00),
        pickupBlue: SKColor(red: 0.16, green: 0.78, blue: 1.00, alpha: 1.00),
        pickupViolet: SKColor(red: 0.55, green: 0.36, blue: 1.00, alpha: 1.00)
    )

    static let whitePrecisionBoard = ArenaTheme(
        backgroundColor: SKColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1.00),
        gridColor: SKColor(red: 0.68, green: 0.70, blue: 0.72, alpha: 0.28),
        borderColor: SKColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 0.70),
        playerColor: SKColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1.00),
        playerAccentColor: SKColor(red: 0.09, green: 0.78, blue: 1.00, alpha: 1.00),
        enemyColor: SKColor(red: 1.00, green: 0.16, blue: 0.16, alpha: 1.00),
        pickupAmber: SKColor(red: 1.00, green: 0.75, blue: 0.20, alpha: 1.00),
        pickupBlue: SKColor(red: 0.16, green: 0.78, blue: 1.00, alpha: 1.00),
        pickupViolet: SKColor(red: 0.55, green: 0.36, blue: 1.00, alpha: 1.00)
    )
}
