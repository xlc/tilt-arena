enum WeaponKind: String, CaseIterable, Codable, Equatable {
    case shockwave
    case seekerSwarm
    case razorShield
    case novaBomb

    var displayName: String {
        switch self {
        case .shockwave:
            return "Shockwave"
        case .seekerSwarm:
            return "Seeker Swarm"
        case .razorShield:
            return "Razor Shield"
        case .novaBomb:
            return "Nova Bomb"
        }
    }
}
