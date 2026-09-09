import SpriteKit

extension ArenaUIRenderer {
    func renderOptions(
        settings: TiltControlSettings,
        options: ArenaLocalOptions,
        resetDataArmed: Bool,
        layout: ArenaLandscapeUILayout
    ) {
        let contentFrame = addMenuChrome(title: "OPTIONS", layout: layout)

        let columnGap: CGFloat = 8
        let controlWidth = max(184, contentFrame.width * 0.42)
        let feedbackWidth = max(112, contentFrame.width * 0.24)
        let displayWidth = max(0, contentFrame.width - controlWidth - feedbackWidth - columnGap * 2)
        let controlFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.minY,
            width: controlWidth,
            height: contentFrame.height
        )
        let feedbackFrame = CGRect(
            x: controlFrame.maxX + columnGap,
            y: contentFrame.minY,
            width: feedbackWidth,
            height: contentFrame.height
        )
        let displayFrame = CGRect(
            x: feedbackFrame.maxX + columnGap,
            y: contentFrame.minY,
            width: displayWidth,
            height: contentFrame.height
        )
        addPanel(frame: controlFrame, accent: theme.playerAccentColor.withAlphaComponent(0.58))
        addPanel(frame: feedbackFrame)
        addPanel(frame: displayFrame)

        renderTiltOptions(settings: settings, in: controlFrame)
        renderFeedbackOptions(options: options, in: feedbackFrame)
        renderDisplayDataOptions(options: options, resetDataArmed: resetDataArmed, in: displayFrame)
    }

    private func renderTiltOptions(settings: TiltControlSettings, in frame: CGRect) {
        let inset: CGFloat = 10
        addSectionLabel("CONTROL", at: CGPoint(x: frame.minX + inset, y: frame.maxY - 18))
        addButton(
            "CALIBRATE",
            frame: CGRect(x: frame.minX + inset, y: frame.maxY - 58, width: frame.width - inset * 2, height: 32),
            action: .openCalibrationPreview,
            style: .primary,
            glyph: .radar,
            fontSize: 12
        )
        addTiltSettingsControls(settings: settings, in: frame, style: .options)
    }

    private func renderFeedbackOptions(options: ArenaLocalOptions, in frame: CGRect) {
        let inset: CGFloat = 10
        addSectionLabel("FEEDBACK", at: CGPoint(x: frame.minX + inset, y: frame.maxY - 18))
        addToggle(
            title: "AUDIO",
            isOn: options.audioEnabled,
            frame: CGRect(x: frame.minX + inset, y: frame.maxY - 72, width: frame.width - inset * 2, height: 40),
            action: .toggleAudio
        )
        addToggle(
            title: "HAPTICS",
            isOn: options.hapticsEnabled,
            frame: CGRect(x: frame.minX + inset, y: frame.maxY - 122, width: frame.width - inset * 2, height: 40),
            action: .toggleHaptics
        )
    }

    private func renderDisplayDataOptions(options: ArenaLocalOptions, resetDataArmed: Bool, in frame: CGRect) {
        let inset: CGFloat = 10
        let contentWidth = max(0, frame.width - inset * 2)
        let rowSpacing: CGFloat = 6
        addSectionLabel("DISPLAY & DATA", at: CGPoint(x: frame.minX + inset, y: frame.maxY - 18))
        let themeKinds = ArenaThemeKind.allCases
        let themeButtonWidth = max(
            0,
            (contentWidth - CGFloat(max(0, themeKinds.count - 1)) * rowSpacing) / CGFloat(themeKinds.count)
        )
        for (index, themeKind) in themeKinds.enumerated() {
            let buttonFrame = CGRect(
                x: frame.minX + inset + CGFloat(index) * (themeButtonWidth + rowSpacing),
                y: frame.maxY - 68,
                width: themeButtonWidth,
                height: 34
            )
            let isSelected = options.themeKind == themeKind
            addButton(
                themeKind.shortTitle,
                frame: buttonFrame,
                action: .selectTheme(themeKind),
                style: isSelected ? .primary : .secondary,
                fontSize: 10
            )
            if isSelected {
                addSelectionIndicator(in: buttonFrame)
            }
        }
        addButton(
            "VIEW / SHARE LOGS",
            frame: CGRect(x: frame.minX + inset, y: frame.maxY - 110, width: contentWidth, height: 32),
            action: .openDiagnostics,
            style: .secondary,
            fontSize: 10
        )
        addButton(
            resetDataArmed ? "CONFIRM RESET" : "RESET PROFILE",
            frame: CGRect(x: frame.minX + inset, y: frame.minY + 8, width: contentWidth, height: 32),
            action: .resetData,
            style: .danger,
            fontSize: 10
        )
    }
}
