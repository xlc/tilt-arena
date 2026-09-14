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
        let currentTime = timeOnScreen.isFinite ? max(0, timeOnScreen) : 0
        let deltaTime = deltaTime.isFinite ? max(0, deltaTime) : 0
        timeOnScreen = currentTime + deltaTime
        chargeTier = configuration.chargeTier(for: timeOnScreen)
    }
}
