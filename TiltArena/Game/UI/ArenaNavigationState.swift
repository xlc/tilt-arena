struct ArenaNavigationTransition: Equatable {
    let previous: ArenaUISceneState
    let current: ArenaUISceneState
}

struct ArenaDeveloperTuningNavigationState: Equatable {
    private(set) var pageIndex = 0
    private(set) var selectedGroup: String?
    private(set) var selectedSubgroup: String?
    private(set) var showsChangedOnly = false
    var confirmation: String?

    mutating func selectGroup(_ group: String) {
        selectedGroup = group
        selectedSubgroup = nil
        resetPageAndConfirmation()
    }

    mutating func selectSubgroup(_ subgroup: String) {
        selectedSubgroup = subgroup
        resetPageAndConfirmation()
    }

    mutating func toggleChangedOnly() {
        showsChangedOnly.toggle()
        resetPageAndConfirmation()
    }

    mutating func moveToPreviousPage() {
        pageIndex = max(0, pageIndex - 1)
    }

    mutating func moveToNextPage(lastPageIndex: Int) {
        pageIndex = min(max(0, lastPageIndex), pageIndex + 1)
    }

    mutating func clampPage(lastPageIndex: Int) {
        pageIndex = min(max(0, pageIndex), max(0, lastPageIndex))
    }

    mutating func reconcileGroups(_ groups: [String]) -> String? {
        if selectedGroup.map({ !groups.contains($0) }) ?? true {
            selectedGroup = groups.first
            pageIndex = 0
        }
        if selectedGroup == nil {
            selectedSubgroup = nil
        }
        return selectedGroup
    }

    mutating func reconcileSubgroups(_ subgroups: [String]) -> String? {
        if selectedSubgroup.map({ !subgroups.contains($0) }) ?? true {
            selectedSubgroup = subgroups.first
            pageIndex = 0
        }
        return selectedSubgroup
    }

    mutating func reset(confirmation: String? = nil) {
        pageIndex = 0
        selectedGroup = nil
        selectedSubgroup = nil
        showsChangedOnly = false
        self.confirmation = confirmation
    }

    private mutating func resetPageAndConfirmation() {
        pageIndex = 0
        confirmation = nil
    }
}

struct ArenaNavigationState: Equatable {
    private(set) var current: ArenaUISceneState = .home
    private(set) var optionsReturnDestination: ArenaUISceneState = .home
    private(set) var calibrationReturnDestination: ArenaUISceneState = .home
    private(set) var developerReturnDestination: ArenaUISceneState = .home
    var weaponCodexPageIndex = 0
    var gameCenterStatusMessage: String?
    var isResetDataArmed = false
    var developerTuning = ArenaDeveloperTuningNavigationState()

    var shouldLockCurrentOrientation: Bool {
        switch current {
        case .options:
            return optionsReturnDestination.requiresLockedRunOrientation
        case .developerTuning:
            return developerReturnDestination.requiresLockedRunOrientation
        default:
            return current.requiresLockedRunOrientation
        }
    }

    mutating func transition(to destination: ArenaUISceneState) -> ArenaNavigationTransition {
        if destination != .options {
            isResetDataArmed = false
        }
        if destination != .home && destination != .postRun {
            gameCenterStatusMessage = nil
        }

        let transition = ArenaNavigationTransition(previous: current, current: destination)
        current = destination
        return transition
    }

    mutating func prepareOptionsPresentation() {
        optionsReturnDestination = current
    }

    mutating func prepareDeveloperTuningPresentation() {
        developerReturnDestination = current
        developerTuning.confirmation = nil
    }

    mutating func prepareCalibrationPresentation() {
        guard current != .calibrationPreview else {
            return
        }
        calibrationReturnDestination = current
    }

    mutating func prepareBackNavigation() -> ArenaUISceneState {
        switch current {
        case .calibrationPreview:
            return calibrationReturnDestination
        case .developerTuning:
            developerTuning.confirmation = nil
            return developerReturnDestination
        case .options:
            return optionsReturnDestination
        default:
            return .home
        }
    }

    #if DEBUG
    mutating func resetForSnapshot(resetDataArmed: Bool) {
        current = .home
        optionsReturnDestination = .home
        calibrationReturnDestination = .home
        developerReturnDestination = .home
        gameCenterStatusMessage = nil
        isResetDataArmed = resetDataArmed
        weaponCodexPageIndex = 0
        developerTuning.reset()
    }
    #endif
}
