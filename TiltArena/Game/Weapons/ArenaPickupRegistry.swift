import SpriteKit

@MainActor
final class ArenaPickupRegistry {
    private(set) var pickups: [WeaponPickup] = []
    private var nodesByID: [Int: WeaponPickupNode] = [:]
    private let logger = AppDiagnostics.logger(.weapon)

    var count: Int {
        pickups.count
    }

    var nodeCount: Int {
        nodesByID.count
    }

    var collisionCircles: [CollisionCircle] {
        pickups.map(\.collisionCircle)
    }

    @discardableResult
    func add(_ newPickups: [WeaponPickup], to parent: SKNode, theme: ArenaTheme) -> [WeaponPickup] {
        var knownIDs = Set(pickups.map(\.id))
        var accepted: [WeaponPickup] = []
        var duplicateIDs: Set<Int> = []

        for pickup in newPickups {
            guard knownIDs.insert(pickup.id).inserted else {
                duplicateIDs.insert(pickup.id)
                continue
            }

            pickups.append(pickup)
            accepted.append(pickup)
            let node = WeaponPickupNode(pickup: pickup, theme: theme)
            nodesByID[pickup.id] = node
            parent.addChild(node)
        }

        if !duplicateIDs.isEmpty {
            logger.critical("pickup.id_invariant_violated", metadata: [
                "duplicates": "\(duplicateIDs.count)",
                "pickups": "\(pickups.count)"
            ])
        }
        return accepted
    }

    func advanceCharges(
        deltaTime: TimeInterval,
        configuration: PickupSpawnConfiguration
    ) -> [WeaponPickup] {
        guard deltaTime > 0, !pickups.isEmpty else {
            return []
        }

        var chargedPickups: [WeaponPickup] = []
        for index in pickups.indices {
            let previousTier = pickups[index].chargeTier
            pickups[index].advanceCharge(deltaTime: deltaTime, configuration: configuration)
            guard pickups[index].chargeTier != previousTier else {
                continue
            }

            nodesByID[pickups[index].id]?.apply(pickups[index])
            chargedPickups.append(pickups[index])
        }
        return chargedPickups
    }

    @discardableResult
    func remove(id: Int) -> WeaponPickup? {
        guard let index = pickups.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let pickup = pickups.remove(at: index)
        nodesByID.removeValue(forKey: id)?.removeFromParent()
        return pickup
    }

    func reset() {
        pickups.removeAll()
        nodesByID.values.forEach { $0.removeFromParent() }
        nodesByID.removeAll()
    }

    func applyTheme(_ theme: ArenaTheme) {
        for pickup in pickups {
            nodesByID[pickup.id]?.applyTheme(theme, pickup: pickup)
        }
    }
}
