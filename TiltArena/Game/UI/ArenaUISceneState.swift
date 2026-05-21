enum ArenaUISceneState: Equatable {
    case home
    case modeSelect
    case awards
    case options
    case preRun
    case activeGameplay
    case pause
    case postRun
}

enum ArenaModeKind: String, CaseIterable, Equatable {
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
