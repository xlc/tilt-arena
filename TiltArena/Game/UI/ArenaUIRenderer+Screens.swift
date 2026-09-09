import SpriteKit

extension ArenaUIRenderer {
    func addHomeIdentity(bestScore: Int, statusMessage: String?, in frame: CGRect) {
        addTitle(
            "TILT ARENA",
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 22)
        )
        addSmallLabel(
            "CLASSIC SURVIVAL",
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 48),
            color: theme.borderColor,
            alignment: .left
        )
        addSectionLabel(
            "PERSONAL BEST",
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 70)
        )
        addLabel(
            "\(bestScore)",
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 19),
            fontSize: 26,
            color: theme.playerAccentColor,
            alignment: .left
        )
        addGameCenterStatusMessage(statusMessage,
            at: CGPoint(x: frame.minX + 14, y: frame.minY - 12),
            alignment: .left
        )
    }

    func addHomePlayButton(layout: ArenaLandscapeUILayout, bottomButtonSize: CGSize) {
        let playFrame = CGRect(
            x: layout.controlRect.maxX - 164,
            y: layout.controlRect.minY + bottomButtonSize.height + 16,
            width: 164,
            height: 56
        )
        addButton(
            "PLAY",
            frame: playFrame,
            action: .play,
            style: .primary,
            glyph: .play,
            fontSize: 18
        )
    }

    func renderModeSelect(rows: [ArenaModeRow], selectedMode: ArenaModeKind, layout: ArenaLandscapeUILayout) {
        let contentFrame = addMenuChrome(title: "SELECT MODE", layout: layout)

        let detailWidth = min(168, contentFrame.width * 0.34)
        let columnGap: CGFloat = 14
        let rowWidth = max(0, contentFrame.width - detailWidth - columnGap)
        let rowSpacing: CGFloat = 8
        let availableRowHeight = (
            contentFrame.height - CGFloat(max(0, rows.count - 1)) * rowSpacing
        ) / CGFloat(max(1, rows.count))
        let rowHeight = min(
            50,
            max(40, availableRowHeight)
        )
        let rowStartY = contentFrame.maxY - rowHeight

        for (index, row) in rows.enumerated() {
            let frame = CGRect(
                x: contentFrame.minX,
                y: rowStartY - CGFloat(index) * (rowHeight + rowSpacing),
                width: rowWidth,
                height: rowHeight
            )
            addModeRow(row, selected: row.kind == selectedMode, frame: frame)
        }

        let detailFrame = CGRect(
            x: contentFrame.maxX - detailWidth,
            y: contentFrame.minY,
            width: detailWidth,
            height: contentFrame.height
        )
        if let selectedRow = rows.first(where: { $0.kind == selectedMode }) {
            addSelectedModeSummary(row: selectedRow, frame: detailFrame)
        }
    }

    func renderAwards(rows: [ArenaAwardRow], unlockText: String, layout: ArenaLandscapeUILayout) {
        let contentFrame = addMenuChrome(title: "AWARDS", layout: layout)

        let unlockFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.maxY - 42,
            width: contentFrame.width,
            height: 42
        )
        addActiveUnlockBanner(
            text: unlockText,
            frame: unlockFrame
        )

        let columnCount = 3
        let columnGap: CGFloat = 10
        let rowSpacing: CGFloat = 8
        let columnWidth = max(
            0,
            (contentFrame.width - CGFloat(columnCount - 1) * columnGap) / CGFloat(columnCount)
        )
        let awardTopY = unlockFrame.minY - 12
        let rowHeight = min(46, max(34, (awardTopY - contentFrame.minY - rowSpacing) / 2))

        for (index, row) in rows.enumerated() {
            let column = index % columnCount
            let rowIndex = index / columnCount
            let frame = CGRect(
                x: contentFrame.minX + CGFloat(column) * (columnWidth + columnGap),
                y: awardTopY - rowHeight - CGFloat(rowIndex) * (rowHeight + rowSpacing),
                width: columnWidth,
                height: rowHeight
            )
            addAwardRow(row, frame: frame)
        }
    }

    func renderWeaponCodex(rows: [WeaponCodexRow], layout: ArenaLandscapeUILayout) {
        let contentFrame = addMenuChrome(title: "WEAPON CODEX", layout: layout)

        let columnCount = 3
        let columnGap: CGFloat = 8
        let rowGap: CGFloat = 8
        let rowCount = Int(ceil(Double(rows.count) / Double(columnCount)))
        let columnWidth = max(
            0,
            (contentFrame.width - CGFloat(columnCount - 1) * columnGap) / CGFloat(columnCount)
        )
        let rowHeight = max(
            34,
            (
                contentFrame.height - CGFloat(max(0, rowCount - 1)) * rowGap
            ) / CGFloat(max(1, rowCount))
        )

        for (index, row) in rows.enumerated() {
            let column = index % columnCount
            let rowIndex = index / columnCount
            let frame = CGRect(
                x: contentFrame.minX + CGFloat(column) * (columnWidth + columnGap),
                y: contentFrame.maxY - rowHeight - CGFloat(rowIndex) * (rowHeight + rowGap),
                width: columnWidth,
                height: rowHeight
            )
            addWeaponCodexRow(row, frame: frame)
        }
    }

    func addGameCenterStatusMessage(_ message: String?, at position: CGPoint, alignment: SKLabelHorizontalAlignmentMode) {
        guard let message else { return }
        addSmallLabel(message, at: position, color: theme.playerAccentColor, alignment: alignment)
    }

    func addMenuChrome(title: String, layout: ArenaLandscapeUILayout) -> CGRect {
        addMenuBackdrop(layout: layout)
        addBackButton(
            frame: CGRect(
                x: layout.safeRect.minX + 14,
                y: layout.safeRect.maxY - 48,
                width: 42,
                height: 34
            )
        )
        addTitle(title, at: CGPoint(x: layout.safeRect.minX + 68, y: layout.safeRect.maxY - 31))
        addDividerLine(
            from: CGPoint(x: layout.safeRect.minX + 14, y: layout.safeRect.maxY - 62),
            to: CGPoint(x: layout.safeRect.maxX - 14, y: layout.safeRect.maxY - 62),
            color: theme.panelStrokeColor.withAlphaComponent(0.72)
        )
        addDividerLine(
            from: CGPoint(x: layout.safeRect.minX + 68, y: layout.safeRect.maxY - 62),
            to: CGPoint(x: layout.safeRect.minX + 148, y: layout.safeRect.maxY - 62),
            color: theme.playerAccentColor.withAlphaComponent(0.9)
        )

        return menuContentFrame(layout: layout)
    }

    func menuContentFrame(layout: ArenaLandscapeUILayout) -> CGRect {
        CGRect(
            x: layout.safeRect.minX + 14,
            y: layout.safeRect.minY + 16,
            width: max(0, layout.safeRect.width - 28),
            height: max(0, layout.safeRect.height - 76)
        )
    }

    func addMenuBackdrop(layout: ArenaLandscapeUILayout) {
        let backdrop = SKShapeNode(rect: layout.safeRect, cornerRadius: 10)
        backdrop.zPosition = ArenaUIZPosition.scrim
        backdrop.fillColor = theme.panelFillColor
        backdrop.strokeColor = .clear
        root.addChild(backdrop)
    }
}
