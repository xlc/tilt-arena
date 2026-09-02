import SpriteKit
import XCTest
@testable import TiltArena

final class ArenaPickupRegistryTests: XCTestCase {
    @MainActor
    func testDuplicatePickupIDIsRejectedWithoutOrphaningNode() {
        let registry = ArenaPickupRegistry()
        let parent = SKNode()
        let pickup = makePickup(id: 1)

        let accepted = registry.add([pickup, pickup], to: parent, theme: ArenaThemeKind.darkTacticalRadar.theme)

        XCTAssertEqual(accepted, [pickup])
        XCTAssertEqual(registry.pickups, [pickup])
        XCTAssertEqual(registry.nodeCount, 1)
        XCTAssertEqual(parent.children.count, 1)
    }

    @MainActor
    func testChargeAdvancementUpdatesModelAndNodeTogether() {
        let registry = ArenaPickupRegistry()
        let parent = SKNode()
        let pickup = makePickup(id: 1)
        var configuration = PickupSpawnConfiguration()
        configuration.chargedPickupDelay = 1
        registry.add([pickup], to: parent, theme: ArenaThemeKind.darkTacticalRadar.theme)

        let chargedPickups = registry.advanceCharges(deltaTime: 1, configuration: configuration)

        XCTAssertEqual(chargedPickups.map(\.chargeTier), [.charged])
        XCTAssertEqual(registry.pickups.first?.chargeTier, .charged)
        XCTAssertEqual(parent.children.count, 1)
    }

    @MainActor
    func testRemovalKeepsPickupAndNodeOwnershipInSync() {
        let registry = ArenaPickupRegistry()
        let parent = SKNode()
        let pickup = makePickup(id: 1)
        registry.add([pickup], to: parent, theme: ArenaThemeKind.darkTacticalRadar.theme)

        XCTAssertEqual(registry.remove(id: pickup.id), pickup)
        XCTAssertTrue(registry.pickups.isEmpty)
        XCTAssertEqual(registry.nodeCount, 0)
        XCTAssertTrue(parent.children.isEmpty)
    }

    private func makePickup(id: Int) -> WeaponPickup {
        WeaponPickup(id: id, kind: .shockwave, position: CGPoint(x: 20, y: 30), radius: 8)
    }
}
