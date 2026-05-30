import CoreGraphics
import Foundation

enum WeaponPickupChargeTier: Int, Equatable, Comparable {
    case base
    case charged
    case overcharged

    static func < (lhs: WeaponPickupChargeTier, rhs: WeaponPickupChargeTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var metadataValue: String {
        switch self {
        case .base:
            return "base"
        case .charged:
            return "charged"
        case .overcharged:
            return "overcharged"
        }
    }
}

struct WeaponPickup: Equatable, Identifiable {
    let id: Int
    let kind: WeaponKind
    let position: CGPoint
    let radius: CGFloat
    var timeOnScreen: TimeInterval = 0
    var chargeTier: WeaponPickupChargeTier = .base

    var collisionCircle: CollisionCircle {
        CollisionCircle(center: position, radius: radius)
    }

    mutating func advanceCharge(deltaTime: TimeInterval, configuration: PickupSpawnConfiguration) {
        timeOnScreen += max(0, deltaTime)
        chargeTier = configuration.chargeTier(for: timeOnScreen)
    }
}
