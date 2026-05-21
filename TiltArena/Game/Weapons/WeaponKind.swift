enum WeaponKind: String, CaseIterable, Codable, Equatable {
    case shockwave
    case seekerSwarm
    case razorShield
    case freezeBurst
    case gravityWell
    case chainLightning
    case flameTrail
    case warpDash
    case novaBomb

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
        case .novaBomb:
            return "Nova Bomb"
        }
    }
}
