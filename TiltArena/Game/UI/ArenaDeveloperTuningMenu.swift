struct ArenaDeveloperTuningMenu {
    let groups: [String]
    let selectedGroup: String?
    let subgroups: [String]
    let selectedSubgroup: String?
    let parameters: [GameTuningParameterSpec]
    let pageIndex: Int
    let pageSize: Int
    let pageCount: Int
    let showsChangedOnly: Bool
    let changedCount: Int
    let confirmation: String?

    var visibleParameters: ArraySlice<GameTuningParameterSpec> {
        let start = pageIndex * pageSize
        return parameters[start..<min(parameters.count, start + pageSize)]
    }
}

extension ArenaDeveloperTuningNavigationState {
    /// Reconcile selection and pagination before rendering or navigating a page.
    mutating func menu(tuning: GameTuningConfiguration, pageSize: Int) -> ArenaDeveloperTuningMenu {
        let groups = GameTuningParameterCatalog.groupNames(changedOnly: showsChangedOnly, tuning: tuning)
        let group = reconcileGroups(groups)
        let subgroups = group.map {
            GameTuningParameterCatalog.subgroupNames(in: $0, changedOnly: showsChangedOnly, tuning: tuning)
        } ?? []
        let subgroup = reconcileSubgroups(subgroups)
        let parameters: [GameTuningParameterSpec]
        if let group, let subgroup {
            parameters = GameTuningParameterCatalog.parameters(
                in: group, subgroup: subgroup, changedOnly: showsChangedOnly, tuning: tuning
            )
        } else {
            parameters = []
        }

        let pageSize = max(1, pageSize)
        let pageCount = parameters.isEmpty ? 1 : (parameters.count - 1) / pageSize + 1
        clampPage(lastPageIndex: pageCount - 1)
        return ArenaDeveloperTuningMenu(
            groups: groups,
            selectedGroup: group,
            subgroups: subgroups,
            selectedSubgroup: subgroup,
            parameters: parameters,
            pageIndex: pageIndex,
            pageSize: pageSize,
            pageCount: pageCount,
            showsChangedOnly: showsChangedOnly,
            changedCount: tuning.changedParameters().count,
            confirmation: confirmation
        )
    }
}
