import SpriteKit

extension ArenaUIRenderer {
    func addHomeNavigationButtons(layout: ArenaLandscapeUILayout, buttonSize: CGSize) {
        let buttons = [
            ArenaMenuButton(title: "MODES", action: .openModes, glyph: .radar),
            ArenaMenuButton(title: "AWARDS", action: .openAwards, glyph: .award),
            ArenaMenuButton(title: "WEAPONS", action: .openWeaponCodex, glyph: .weapon),
            ArenaMenuButton(title: "RANKS", action: .openClassicLeaderboard, glyph: .ranks),
            ArenaMenuButton(title: "OPTIONS", action: .openOptions, glyph: .settings)
        ]
        for (index, button) in buttons.enumerated() {
            addButton(
                button.title,
                frame: layout.bottomButtonFrame(index: index, count: buttons.count, buttonSize: buttonSize),
                action: button.action,
                style: .secondary,
                glyph: button.glyph
            )
        }
    }

    func addSelectedModeSummary(row: ArenaModeRow, frame: CGRect) {
        addPanel(
            frame: frame,
            stroke: theme.playerAccentColor.withAlphaComponent(0.62),
            accent: theme.playerAccentColor.withAlphaComponent(0.85)
        )
        addSectionLabel("MISSION BRIEF", at: CGPoint(x: frame.minX + 14, y: frame.maxY - 24))
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 54),
            fontSize: 18,
            color: theme.playerColor,
            alignment: .left
        )
        addSmallLabel(
            row.subtitle.uppercased(),
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 78),
            color: theme.borderColor,
            alignment: .left
        )
        addLabel(
            row.progressText,
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 66),
            fontSize: 10,
            color: theme.playerAccentColor,
            alignment: .left
        )
        addButton(
            "PLAY",
            frame: CGRect(x: frame.minX + 14, y: frame.minY + 14, width: frame.width - 28, height: 40),
            action: .play,
            style: .primary
        )
    }

    func addActiveUnlockBanner(text: String, frame: CGRect) {
        addPanel(
            frame: frame,
            stroke: theme.playerAccentColor.withAlphaComponent(0.55),
            accent: theme.playerAccentColor.withAlphaComponent(0.72)
        )
        addSectionLabel("NEXT UNLOCK", at: CGPoint(x: frame.minX + 14, y: frame.midY + 7))
        addLabel(
            text,
            at: CGPoint(x: frame.minX + 132, y: frame.midY - 1),
            fontSize: 13,
            color: theme.playerAccentColor,
            alignment: .left
        )
    }

    func addModeRow(_ row: ArenaModeRow, selected: Bool, frame: CGRect) {
        let detailFontSize: CGFloat = frame.width < 340 ? 9 : 11
        let presentation = modePresentation(for: row.kind)
        addModeRowPanel(frame: frame, selected: selected, presentation: presentation)
        addModeRowTitle(row, frame: frame, presentation: presentation)
        addModeRowMetadata(
            row,
            frame: frame,
            selected: selected,
            detailFontSize: detailFontSize,
            presentation: presentation
        )
        addHitTarget(action: .selectMode(row.kind), frame: frame)
    }

    func addAwardRow(_ row: ArenaAwardRow, frame: CGRect) {
        let accentColor = row.isComplete ? theme.playerAccentColor : theme.pickupAmber
        addPanel(
            frame: frame,
            stroke: accentColor.withAlphaComponent(row.isComplete ? 0.56 : 0.34),
            fill: accentColor.withAlphaComponent(row.isComplete ? 0.04 : 0.025)
        )
        let fontSize: CGFloat = frame.width < 170 ? 9 : 11
        addControlGlyph(
            row.isComplete ? .check : .award,
            at: CGPoint(x: frame.minX + 14, y: frame.maxY - 17),
            radius: 6,
            color: accentColor
        )
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 28, y: frame.maxY - 17),
            fontSize: fontSize,
            color: row.isComplete ? theme.playerAccentColor : theme.playerColor,
            alignment: .left
        )
        addLabel(
            row.progressText,
            at: CGPoint(x: frame.maxX - 12, y: frame.minY + 20),
            fontSize: fontSize,
            color: theme.borderColor,
            alignment: .right
        )
        addProgressBar(
            frame: CGRect(x: frame.minX + 12, y: frame.minY + 9, width: frame.width - 24, height: 5),
            fraction: row.progressFraction,
            color: accentColor
        )
    }

    func addWeaponCodexRow(_ row: WeaponCodexRow, frame: CGRect) {
        let strokeColor = row.isUnlocked
            ? theme.playerAccentColor.withAlphaComponent(0.3)
            : theme.borderColor.withAlphaComponent(0.28)
        let fillColor = row.isUnlocked
            ? theme.playerAccentColor.withAlphaComponent(0.06)
            : theme.backgroundColor.withAlphaComponent(0.46)
        addPanel(frame: frame, stroke: strokeColor, fill: fillColor)

        let compact = frame.height < 42
        let iconRadius = min(compact ? 9 : 12, max(7, frame.height * 0.27))
        let iconPosition = CGPoint(x: frame.minX + 15, y: frame.midY)
        addWeaponCodexIcon(
            kind: row.kind,
            position: iconPosition,
            radius: iconRadius,
            isUnlocked: row.isUnlocked
        )

        let titleX = iconPosition.x + iconRadius + 8
        let titleWidth = max(30, frame.maxX - titleX - 48)
        addLabel(
            truncatedText(row.title, fontSize: compact ? 7.4 : 8.4, width: titleWidth),
            at: CGPoint(x: titleX, y: frame.maxY - (compact ? 9 : 11)),
            fontSize: compact ? 7.4 : 8.4,
            color: row.isUnlocked ? theme.playerColor : theme.borderColor.withAlphaComponent(0.78),
            alignment: .left
        )
        addLabel(
            row.statusText,
            at: CGPoint(x: frame.maxX - 8, y: frame.maxY - (compact ? 9 : 11)),
            fontSize: compact ? 5.8 : 6.6,
            color: row.isUnlocked ? theme.playerAccentColor : theme.borderColor.withAlphaComponent(0.72),
            alignment: .right
        )
        addWeaponCodexDetails(row, frame: frame, titleX: titleX, compact: compact)
    }

    func addPostRunHighlights(_ highlights: [String], frame: CGRect) {
        addPanel(
            frame: frame,
            stroke: theme.playerAccentColor.withAlphaComponent(0.54),
            accent: theme.playerAccentColor.withAlphaComponent(0.72)
        )
        let compact = frame.height < 150
        let topPadding: CGFloat = compact ? 16 : 22
        let bottomPadding: CGFloat = compact ? 10 : 14
        let availableHeight = max(0, frame.height - topPadding - bottomPadding)
        let rowSpacing = highlights.count > 1
            ? min(26, max(compact ? 14 : 18, availableHeight / CGFloat(highlights.count - 1)))
            : 0

        for (index, text) in highlights.enumerated() {
            let position = CGPoint(
                x: frame.minX + 14,
                y: frame.maxY - topPadding - CGFloat(index) * rowSpacing
            )
            addPostRunHighlight(text, index: index, position: position, compact: compact)
        }
    }

    func addPostRunButtons(layout: ArenaLandscapeUILayout) {
        let primaryWidth = min(190, layout.controlRect.width * 0.42)
        let primaryFrame = CGRect(
            x: layout.controlRect.maxX - primaryWidth,
            y: layout.controlRect.minY,
            width: primaryWidth,
            height: 48
        )
        addButton(
            "PLAY AGAIN",
            frame: primaryFrame,
            action: .playAgain,
            style: .primary,
            glyph: .play,
            fontSize: 15
        )
        addPostRunNavigationButtons(layout: layout, before: primaryFrame)
    }

    func truncatedText(_ text: String, fontSize: CGFloat, width: CGFloat) -> String {
        let maxCharacters = max(1, Int(width / max(1, fontSize * 0.62)))
        guard text.count > maxCharacters else {
            return text
        }
        guard maxCharacters > 3 else {
            return String(text.prefix(maxCharacters))
        }
        return "\(text.prefix(maxCharacters - 3))..."
    }

    private func addModeRowPanel(
        frame: CGRect,
        selected: Bool,
        presentation: ArenaModePresentation
    ) {
        addPanel(
            frame: frame,
            stroke: selected
                ? presentation.color.withAlphaComponent(0.9)
                : theme.borderColor.withAlphaComponent(0.35),
            fill: selected
                ? presentation.color.withAlphaComponent(0.1)
                : theme.backgroundColor.withAlphaComponent(0.55),
            accent: selected ? presentation.color.withAlphaComponent(0.9) : nil
        )
    }

    private func addModeRowTitle(
        _ row: ArenaModeRow,
        frame: CGRect,
        presentation: ArenaModePresentation
    ) {
        addControlGlyph(
            presentation.glyph,
            at: CGPoint(x: frame.minX + 20, y: frame.midY),
            radius: 8,
            color: row.isAvailable ? presentation.color : theme.borderColor.withAlphaComponent(0.55)
        )
        addLabel(
            row.title,
            at: CGPoint(x: frame.minX + 38, y: frame.maxY - 16),
            fontSize: 15,
            color: row.isAvailable ? theme.playerColor : theme.borderColor.withAlphaComponent(0.75),
            alignment: .left
        )
    }

    private func addModeRowMetadata(
        _ row: ArenaModeRow,
        frame: CGRect,
        selected: Bool,
        detailFontSize: CGFloat,
        presentation: ArenaModePresentation
    ) {
        addLabel(
            truncatedText(row.subtitle, fontSize: detailFontSize, width: max(42, frame.width * 0.34)),
            at: CGPoint(x: frame.minX + 38, y: frame.minY + 12),
            fontSize: detailFontSize,
            color: theme.borderColor,
            alignment: .left
        )
        addSmallLabel(
            row.statusText,
            at: CGPoint(x: frame.maxX - (selected ? 30 : 14), y: frame.maxY - 16),
            color: row.isAvailable ? presentation.color : theme.borderColor,
            alignment: .right
        )
        if selected {
            addControlGlyph(
                .check,
                at: CGPoint(x: frame.maxX - 15, y: frame.maxY - 16),
                radius: 5,
                color: presentation.color
            )
        }
        addLabel(
            row.progressText,
            at: CGPoint(x: frame.maxX - 14, y: frame.minY + 12),
            fontSize: detailFontSize,
            color: theme.borderColor,
            alignment: .right
        )
    }

    private func addWeaponCodexDetails(
        _ row: WeaponCodexRow,
        frame: CGRect,
        titleX: CGFloat,
        compact: Bool
    ) {
        let detailWidth = frame.maxX - titleX - 8
        addLabel(
            truncatedText(row.description.uppercased(), fontSize: compact ? 5.8 : 6.6, width: detailWidth),
            at: CGPoint(x: titleX, y: frame.midY - 1),
            fontSize: compact ? 5.8 : 6.6,
            color: theme.playerColor.withAlphaComponent(row.isUnlocked ? 0.78 : 0.48),
            alignment: .left
        )
        addLabel(
            truncatedText(row.unlockText, fontSize: compact ? 5.8 : 6.4, width: detailWidth),
            at: CGPoint(x: titleX, y: frame.minY + (compact ? 7 : 9)),
            fontSize: compact ? 5.8 : 6.4,
            color: theme.playerAccentColor.withAlphaComponent(row.isUnlocked ? 0.82 : 0.52),
            alignment: .left
        )
    }

    private func addPostRunHighlight(
        _ text: String,
        index: Int,
        position: CGPoint,
        compact: Bool
    ) {
        let markerColor = index == 1 ? theme.pickupAmber : theme.playerAccentColor
        let marker = SKShapeNode(circleOfRadius: 2.5)
        marker.position = position
        marker.zPosition = ArenaUIZPosition.label
        marker.fillColor = markerColor
        marker.strokeColor = .clear
        root.addChild(marker)
        addLabel(
            text,
            at: CGPoint(x: position.x + 12, y: position.y),
            fontSize: compact ? 10 : 12,
            color: index == 1 ? theme.pickupAmber : theme.borderColor,
            alignment: .left
        )
    }

    private func modePresentation(for kind: ArenaModeKind) -> ArenaModePresentation {
        switch kind {
        case .classic:
            return ArenaModePresentation(color: theme.playerAccentColor, glyph: .radar)
        case .redline:
            return ArenaModePresentation(color: theme.enemyColor, glyph: .ranks)
        case .daily:
            return ArenaModePresentation(color: theme.pickupAmber, glyph: .award)
        }
    }

    private func addWeaponCodexIcon(
        kind: WeaponKind,
        position: CGPoint,
        radius: CGFloat,
        isUnlocked: Bool
    ) {
        let color = weaponAccentColor(for: kind)
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = position
        ring.zPosition = ArenaUIZPosition.content
        ring.fillColor = color.withAlphaComponent(isUnlocked ? 0.12 : 0.03)
        ring.strokeColor = color.withAlphaComponent(isUnlocked ? 0.7 : 0.24)
        ring.lineWidth = 0.9
        root.addChild(ring)

        let icon = SKSpriteNode(texture: WeaponSpriteSheet.texture(for: kind, role: .icon))
        icon.position = position
        icon.zPosition = ArenaUIZPosition.label
        icon.size = CGSize(width: radius * 1.65, height: radius * 1.65)
        icon.alpha = isUnlocked ? 0.92 : 0.35
        icon.blendMode = .alpha
        root.addChild(icon)
    }

    private func weaponAccentColor(for kind: WeaponKind) -> SKColor {
        switch kind {
        case .shockwave, .flameTrail, .powerWave, .novaBomb:
            return theme.pickupAmber
        case .seekerSwarm, .chainLightning, .ricochetLance:
            return theme.pickupBlue
        case .freezeBurst, .gravityWell, .warpDash:
            return theme.pickupViolet
        case .razorShield:
            return theme.playerAccentColor
        }
    }

    private func addPostRunNavigationButtons(layout: ArenaLandscapeUILayout, before primaryFrame: CGRect) {
        let spacing: CGFloat = 10
        let availableWidth = max(0, primaryFrame.minX - layout.controlRect.minX - 20)
        let buttonWidth = min(104, max(72, (availableWidth - spacing * 2) / 3))
        let buttons = [
            ArenaMenuButton(title: "MODES", action: .openModes, glyph: .radar),
            ArenaMenuButton(title: "RANKS", action: .openClassicLeaderboard, glyph: .ranks),
            ArenaMenuButton(title: "HOME", action: .home, glyph: .home)
        ]
        for (index, button) in buttons.enumerated() {
            addButton(
                button.title,
                frame: CGRect(
                    x: layout.controlRect.minX + CGFloat(index) * (buttonWidth + spacing),
                    y: layout.controlRect.minY,
                    width: buttonWidth,
                    height: 36
                ),
                action: button.action,
                style: .secondary,
                glyph: button.glyph,
                fontSize: 9
            )
        }
    }
}

private struct ArenaMenuButton {
    let title: String
    let action: ArenaControlAction
    let glyph: ArenaControlGlyph
}

private struct ArenaModePresentation {
    let color: SKColor
    let glyph: ArenaControlGlyph
}
