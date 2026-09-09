import CoreGraphics

enum WeaponKind: String, CaseIterable, Codable, Equatable {
    case shockwave
    case seekerSwarm
    case razorShield
    case freezeBurst
    case gravityWell
    case chainLightning
    case flameTrail
    // Raw value kept for existing saves; display name now presents Time Dilation.
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
            return "Time Dilation"
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
    static let assetName = "WeaponGlyphs"

    // Measured centers in the 1254px source; the generated sheet is not an exact grid.
    private static let glyphCenters: [WeaponKind: CGPoint] = [
        .shockwave: CGPoint(x: 182, y: 220),
        .seekerSwarm: CGPoint(x: 487, y: 220),
        .razorShield: CGPoint(x: 776, y: 221),
        .freezeBurst: CGPoint(x: 1076, y: 222),
        .gravityWell: CGPoint(x: 186, y: 521),
        .chainLightning: CGPoint(x: 486, y: 514),
        .flameTrail: CGPoint(x: 779, y: 516),
        .warpDash: CGPoint(x: 1076, y: 516),
        .powerWave: CGPoint(x: 187, y: 810),
        .ricochetLance: CGPoint(x: 485, y: 801),
        .novaBomb: CGPoint(x: 776, y: 806)
    ]

    static func textureRect(for kind: WeaponKind) -> CGRect {
        guard let center = glyphCenters[kind] else {
            preconditionFailure("Missing weapon glyph for \(kind.rawValue).")
        }
        // Equal 300px crops preserve aspect ratio and transparent gutters around every glyph.
        let extent: CGFloat = 1254
        return CGRect(
            x: (center.x - 150) / extent,
            y: 1 - (center.y + 150) / extent,
            width: 300 / extent,
            height: 300 / extent
        )
    }
}
