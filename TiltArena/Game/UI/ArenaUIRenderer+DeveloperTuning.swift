import SpriteKit

extension ArenaUIRenderer {
    func renderDeveloperTuning(
        menu: ArenaDeveloperTuningMenu,
        tuning: GameTuningConfiguration,
        layout: ArenaLandscapeUILayout
    ) {
        let contentFrame = addMenuChrome(title: "DEV TUNING", layout: layout)

        renderDeveloperTuningHeaderActions(menu: menu, layout: layout)

        let frames = ArenaDeveloperTuningLayout(contentFrame: contentFrame)
        renderDeveloperTuningSelector(
            title: "GROUP",
            items: menu.groups,
            selected: menu.selectedGroup,
            frame: frames.group,
            action: { .selectTuningGroup($0) }
        )
        renderDeveloperTuningSelector(
            title: "SUBGROUP",
            items: menu.subgroups,
            selected: menu.selectedSubgroup,
            frame: frames.subgroup,
            action: { .selectTuningSubgroup($0) }
        )
        renderDeveloperTuningParameterList(
            menu: menu,
            tuning: tuning,
            frame: frames.parameters
        )
    }

    private func renderDeveloperTuningHeaderActions(menu: ArenaDeveloperTuningMenu, layout: ArenaLandscapeUILayout) {
        addButton(
            "COPY",
            frame: CGRect(x: layout.safeRect.maxX - 246, y: layout.safeRect.maxY - 48, width: 66, height: 34),
            action: .copyTuningParameters,
            style: menu.changedCount == 0 ? .secondary : .primary
        )
        addButton(
            menu.showsChangedOnly ? "CHANGED" : "ALL",
            frame: CGRect(x: layout.safeRect.maxX - 174, y: layout.safeRect.maxY - 48, width: 98, height: 34),
            action: .toggleDeveloperTuningChangedOnly,
            style: menu.showsChangedOnly ? .primary : .secondary
        )
        addButton(
            "RESET",
            frame: CGRect(x: layout.safeRect.maxX - 68, y: layout.safeRect.maxY - 48, width: 54, height: 34),
            action: .resetTuningParameters,
            style: menu.changedCount == 0 ? .secondary : .danger
        )

        if let developerTuningCopyConfirmation = menu.confirmation {
            addLabel(
                developerTuningCopyConfirmation,
                at: CGPoint(x: layout.safeRect.maxX - 14, y: layout.safeRect.maxY - 66),
                fontSize: 9,
                color: theme.playerAccentColor,
                alignment: .right
            )
        }
    }

    private func renderDeveloperTuningSelector(
        title: String,
        items: [String],
        selected: String?,
        frame: CGRect,
        action: (String) -> ArenaControlAction
    ) {
        addPanel(frame: frame)
        addSectionLabel(title, at: CGPoint(x: frame.minX + 10, y: frame.maxY - 15))

        guard !items.isEmpty else {
            addLabel(
                "NONE",
                at: CGPoint(x: frame.minX + 10, y: frame.maxY - 42),
                fontSize: 9,
                color: theme.borderColor.withAlphaComponent(0.75),
                alignment: .left
            )
            return
        }

        let headerHeight: CGFloat = 22
        let bottomPadding: CGFloat = 6
        let rowGap: CGFloat = 2
        let rowHeight = min(
            28,
            max(
                10,
                (
                    frame.height - headerHeight - bottomPadding - CGFloat(max(0, items.count - 1)) * rowGap
                ) / CGFloat(items.count)
            )
        )
        let rowFontSize = min(10, max(6.8, rowHeight * 0.42))

        for (index, item) in items.enumerated() {
            let rowFrame = CGRect(
                x: frame.minX + 6,
                y: frame.maxY - headerHeight - CGFloat(index + 1) * rowHeight - CGFloat(index) * rowGap,
                width: frame.width - 12,
                height: rowHeight
            )
            let isSelected = item == selected
            addPanel(
                frame: rowFrame,
                stroke: isSelected ? theme.playerAccentColor.withAlphaComponent(0.85) : theme.borderColor.withAlphaComponent(0.26),
                fill: isSelected ? theme.playerAccentColor.withAlphaComponent(0.11) : theme.backgroundColor.withAlphaComponent(0.28)
            )
            addLabel(
                truncatedText(item.uppercased(), fontSize: rowFontSize, width: rowFrame.width - 14),
                at: CGPoint(x: rowFrame.minX + 7, y: rowFrame.midY),
                fontSize: rowFontSize,
                color: isSelected ? theme.playerAccentColor : theme.playerColor.withAlphaComponent(0.82),
                alignment: .left
            )
            addHitTarget(action: action(item), frame: rowFrame)
        }
    }

    private func renderDeveloperTuningParameterList(
        menu: ArenaDeveloperTuningMenu,
        tuning: GameTuningConfiguration,
        frame: CGRect
    ) {
        addPanel(frame: frame)
        renderDeveloperTuningParameterHeader(
            selectedGroup: menu.selectedGroup,
            selectedSubgroup: menu.selectedSubgroup,
            frame: frame,
            changedCount: menu.changedCount
        )
        guard !menu.parameters.isEmpty else {
            renderDeveloperTuningEmptyParameterList(showsChangedOnly: menu.showsChangedOnly, in: frame)
            return
        }
        renderDeveloperTuningPageControls(menu: menu, frame: frame)
        renderDeveloperTuningRows(menu: menu, tuning: tuning, frame: frame)
    }

    private func renderDeveloperTuningParameterHeader(
        selectedGroup: String?,
        selectedSubgroup: String?,
        frame: CGRect,
        changedCount: Int
    ) {
        let heading = [selectedGroup, selectedSubgroup].compactMap { $0 }.joined(separator: " / ")
        let headingText = heading.isEmpty ? "NO PARAMETERS" : heading.uppercased()
        addLabel(
            truncatedText(headingText, fontSize: 10, width: frame.width - 116),
            at: CGPoint(x: frame.minX + 10, y: frame.maxY - 17),
            fontSize: 10,
            color: theme.playerColor,
            alignment: .left
        )
        addLabel(
            "\(changedCount) CHANGED",
            at: CGPoint(x: frame.maxX - 10, y: frame.maxY - 17),
            fontSize: 8,
            color: changedCount == 0 ? theme.borderColor : theme.playerAccentColor,
            alignment: .right
        )
    }

    private func renderDeveloperTuningEmptyParameterList(showsChangedOnly: Bool, in frame: CGRect) {
        addLabel(
            showsChangedOnly ? "NO CHANGED PARAMETERS" : "NO PARAMETERS",
            at: CGPoint(x: frame.midX, y: frame.midY),
            fontSize: 11,
            color: theme.borderColor.withAlphaComponent(0.78),
            alignment: .center
        )
    }

    private func renderDeveloperTuningPageControls(menu: ArenaDeveloperTuningMenu, frame: CGRect) {
        let controlsY = frame.maxY - 46
        addButton(
            "<",
            frame: CGRect(x: frame.minX + 10, y: controlsY - 13, width: 34, height: 26),
            action: .developerTuningPreviousPage,
            style: menu.pageIndex == 0 ? .secondary : .primary
        )
        addButton(
            ">",
            frame: CGRect(x: frame.minX + 52, y: controlsY - 13, width: 34, height: 26),
            action: .developerTuningNextPage,
            style: menu.pageIndex + 1 >= menu.pageCount ? .secondary : .primary
        )
        addLabel(
            "PAGE \(menu.pageIndex + 1)/\(menu.pageCount)  \(menu.parameters.count) VALUES",
            at: CGPoint(x: frame.minX + 98, y: controlsY),
            fontSize: 8,
            color: theme.borderColor,
            alignment: .left
        )
    }

    private func renderDeveloperTuningRows(
        menu: ArenaDeveloperTuningMenu,
        tuning: GameTuningConfiguration,
        frame: CGRect
    ) {
        let rowHeight = ArenaDeveloperTuningLayout.rowHeight(in: frame)
        let rowStartY = frame.maxY - 68
        for (index, parameter) in menu.visibleParameters.enumerated() {
            let rowFrame = CGRect(
                x: frame.minX + 8,
                y: rowStartY - CGFloat(index + 1) * rowHeight,
                width: frame.width - 16,
                height: rowHeight - 4
            )
            renderDeveloperTuningRow(parameter, tuning: tuning, frame: rowFrame)
        }
    }

    private func renderDeveloperTuningRow(_ parameter: GameTuningParameterSpec, tuning: GameTuningConfiguration, frame: CGRect) {
        let isChanged = tuning.isChanged(parameter)
        addPanel(
            frame: frame,
            stroke: isChanged ? theme.playerAccentColor.withAlphaComponent(0.62) : theme.borderColor.withAlphaComponent(0.28),
            fill: isChanged ? theme.playerAccentColor.withAlphaComponent(0.08) : theme.backgroundColor.withAlphaComponent(0.42)
        )

        let compact = frame.width < 320
        if isChanged {
            addLabel(
                "*",
                at: CGPoint(x: frame.minX + 10, y: frame.midY),
                fontSize: 11,
                color: theme.playerAccentColor,
                alignment: .left
            )
        }
        let titleFontSize: CGFloat = compact ? 8 : 9
        let titleX = frame.minX + (isChanged ? 24 : 12)
        let titleMaxWidth = max(44, frame.maxX - titleX - 124)
        addLabel(
            truncatedText(parameter.title.uppercased(), fontSize: titleFontSize, width: titleMaxWidth),
            at: CGPoint(x: titleX, y: frame.midY),
            fontSize: titleFontSize,
            color: theme.playerColor,
            alignment: .left
        )
        addLabel(
            parameter.displayValue(in: tuning),
            at: CGPoint(x: frame.maxX - 90, y: frame.midY),
            fontSize: 10,
            color: theme.playerAccentColor,
            alignment: .right
        )
        addButton(
            "-",
            frame: CGRect(x: frame.maxX - 78, y: frame.midY - 12, width: 32, height: 24),
            action: .adjustTuningParameter(parameter.id, .decrease),
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(x: frame.maxX - 38, y: frame.midY - 12, width: 32, height: 24),
            action: .adjustTuningParameter(parameter.id, .increase),
            style: .secondary
        )
    }
}
