import CoreGraphics

enum WeaponKind: String, CaseIterable, Codable, Equatable {
    case shockwave
    case seekerSwarm
    case razorShield
    case freezeBurst
    case gravityWell
    case chainLightning
    case flameTrail
    case warpDash
    case powerWave
    case ricochetLance
    case novaBomb

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        if rawValue == "decoyBeacon" {
            self = .powerWave
            return
        }

        guard let value = WeaponKind(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown weapon kind: \(rawValue)"
            )
        }

        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .shockwave:
            return "Shockwave"
        case .seekerSwarm:
            return "Seeker Swarm"
        case .razorShield:
            return "Razor Shield"
        case .freezeBurst:
            return "Freeze Burst"
        case .gravityWell:
            return "Gravity Well"
        case .chainLightning:
            return "Chain Lightning"
        case .flameTrail:
            return "Flame Trail"
        case .warpDash:
            return "Warp Dash"
        case .powerWave:
            return "Power Wave"
        case .ricochetLance:
            return "Ricochet Lance"
        case .novaBomb:
            return "Nova Bomb"
        }
    }
}

struct WeaponSpriteSheet {
    enum Role {
        case icon
        case effect
    }

    static let assetName = "WeaponSprites"
    static let rowCount = 2
    static var columnCount: Int { WeaponKind.allCases.count }

    static func column(for kind: WeaponKind) -> Int {
        guard let column = WeaponKind.allCases.firstIndex(of: kind) else {
            preconditionFailure("Missing sprite sheet column for \(kind.rawValue).")
        }
        return column
    }

    static func textureRect(for kind: WeaponKind, role: Role) -> CGRect {
        let cellWidth = 1 / CGFloat(columnCount)
        let cellHeight = 1 / CGFloat(rowCount)
        let rowFromTop: Int

        switch role {
        case .icon:
            rowFromTop = 0
        case .effect:
            rowFromTop = 1
        }

        return CGRect(
            x: CGFloat(column(for: kind)) * cellWidth,
            y: CGFloat(rowCount - rowFromTop - 1) * cellHeight,
            width: cellWidth,
            height: cellHeight
        )
    }
}
