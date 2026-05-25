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
