import XCTest
@testable import TiltArena

final class ArenaLocalOptionsStoreTests: XCTestCase {
    private static let optionsKey = "tiltArena.localOptions"

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ArenaLocalOptionsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testOptionsPersistAndReset() {
        let store = ArenaLocalOptionsStore(defaults: defaults)
        store.options = ArenaLocalOptions(
            audioEnabled: false,
            hapticsEnabled: false,
            reducedEffects: true,
            themeKind: .whitePrecisionBoard
        )

        XCTAssertEqual(
            ArenaLocalOptionsStore(defaults: defaults).options,
            ArenaLocalOptions(
                audioEnabled: false,
                hapticsEnabled: false,
                reducedEffects: true,
                themeKind: .whitePrecisionBoard
            )
        )

        store.reset()

        XCTAssertEqual(store.options, .defaults)
    }

    func testLegacyOptionsDecodeWithDefaultTheme() {
        let legacyJSON = """
        {
          "audioEnabled": false,
          "hapticsEnabled": true,
          "reducedEffects": true
        }
        """
        defaults.set(Data(legacyJSON.utf8), forKey: Self.optionsKey)

        XCTAssertEqual(
            ArenaLocalOptionsStore(defaults: defaults).options,
            ArenaLocalOptions(
                audioEnabled: false,
                hapticsEnabled: true,
                reducedEffects: true,
                themeKind: .darkTacticalRadar
            )
        )
    }

    func testUnknownThemeDecodePreservesOtherOptionsWithDefaultTheme() {
        let json = """
        {
          "audioEnabled": false,
          "hapticsEnabled": false,
          "reducedEffects": true,
          "themeKind": "futureTheme"
        }
        """
        defaults.set(Data(json.utf8), forKey: Self.optionsKey)

        XCTAssertEqual(
            ArenaLocalOptionsStore(defaults: defaults).options,
            ArenaLocalOptions(
                audioEnabled: false,
                hapticsEnabled: false,
                reducedEffects: true,
                themeKind: .darkTacticalRadar
            )
        )
    }
}
