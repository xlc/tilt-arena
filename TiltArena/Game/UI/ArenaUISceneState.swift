enum ArenaUISceneState: Equatable {
    case home
    case modeSelect
    case awards
    case options
    case preRun
    case activeGameplay
    case pause
    case postRun

    var requiresLockedRunOrientation: Bool {
        switch self {
        case .preRun, .activeGameplay, .pause, .postRun:
            return true
        case .home, .modeSelect, .awards, .options:
            return false
        }
    }
}

enum ArenaModeKind: String, CaseIterable, Codable, Equatable {
    case classic
    case redline
    case daily

    var displayName: String {
        switch self {
        case .classic:
            return "CLASSIC"
        case .redline:
            return "REDLINE"
        case .daily:
            return "DAILY"
        }
    }
}
