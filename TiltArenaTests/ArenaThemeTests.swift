import SpriteKit
import XCTest
@testable import TiltArena

final class ArenaThemeTests: XCTestCase {
    func testThemeKindOrderAndTitlesAreStable() {
        XCTAssertEqual(ArenaThemeKind.allCases, [.darkTacticalRadar, .whitePrecisionBoard])
        XCTAssertEqual(ArenaThemeKind.darkTacticalRadar.shortTitle, "DARK")
        XCTAssertEqual(ArenaThemeKind.whitePrecisionBoard.shortTitle, "WHITE")
    }

    func testThemeKindMapsToMatchingTheme() {
        XCTAssertEqual(ArenaThemeKind.darkTacticalRadar.theme.kind, .darkTacticalRadar)
        XCTAssertEqual(ArenaThemeKind.whitePrecisionBoard.theme.kind, .whitePrecisionBoard)
    }

    func testGameplayColorRolesStayDistinctAcrossThemes() {
        for themeKind in ArenaThemeKind.allCases {
            let theme = themeKind.theme
            let enemy = components(of: theme.enemyColor)
            XCTAssertGreaterThan(enemy.red - enemy.green, 0.6)
            XCTAssertGreaterThan(enemy.red - enemy.blue, 0.6)

            XCTAssertGreaterThan(colorDistance(theme.enemyColor, theme.pickupAmber), 0.4)
            XCTAssertGreaterThan(colorDistance(theme.enemyColor, theme.pickupBlue), 0.4)
            XCTAssertGreaterThan(colorDistance(theme.enemyColor, theme.pickupViolet), 0.4)
            XCTAssertLessThan(components(of: theme.gridColor).alpha, components(of: theme.enemyColor).alpha)
            XCTAssertLessThan(components(of: theme.panelStrokeColor).alpha, components(of: theme.enemyColor).alpha)
        }
    }

    func testWhitePrecisionBoardAvoidsBeigeDominance() {
        let background = components(of: ArenaTheme.whitePrecisionBoard.backgroundColor)

        XCTAssertLessThan(abs(background.red - background.blue), 0.04)
        XCTAssertGreaterThanOrEqual(background.green, background.red)
        XCTAssertGreaterThan(background.blue, 0.92)
    }

    private func components(of color: SKColor) -> ColorComponents {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

        return ColorComponents(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func colorDistance(_ lhs: SKColor, _ rhs: SKColor) -> CGFloat {
        let lhsComponents = components(of: lhs)
        let rhsComponents = components(of: rhs)
        let redDelta = lhsComponents.red - rhsComponents.red
        let greenDelta = lhsComponents.green - rhsComponents.green
        let blueDelta = lhsComponents.blue - rhsComponents.blue

        return sqrt(redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta)
    }
}

private struct ColorComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}
