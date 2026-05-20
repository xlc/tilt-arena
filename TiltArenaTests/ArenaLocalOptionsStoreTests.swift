import XCTest
@testable import TiltArena

final class ArenaLocalOptionsStoreTests: XCTestCase {
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
        store.options = ArenaLocalOptions(audioEnabled: false, hapticsEnabled: false, reducedEffects: true)

        XCTAssertEqual(
            ArenaLocalOptionsStore(defaults: defaults).options,
            ArenaLocalOptions(audioEnabled: false, hapticsEnabled: false, reducedEffects: true)
        )

        store.reset()

        XCTAssertEqual(store.options, .defaults)
    }
}
