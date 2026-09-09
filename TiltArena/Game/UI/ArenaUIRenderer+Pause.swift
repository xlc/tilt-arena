import SpriteKit

extension ArenaUIRenderer {
    func renderPause(runSummary: String, layout: ArenaLandscapeUILayout) {
        addScrim(alpha: 0.66)
        let panelFrame = pausePanelFrame(in: layout.safeRect)
        addPanel(
            frame: panelFrame,
            stroke: theme.playerAccentColor.withAlphaComponent(0.74),
            fill: theme.panelFillColor.withAlphaComponent(0.96),
            accent: theme.playerAccentColor.withAlphaComponent(0.9)
        )
        renderPauseHeader(runSummary: runSummary, in: panelFrame)
        renderPauseControls(in: panelFrame)
    }

    private func pausePanelFrame(in safeRect: CGRect) -> CGRect {
        let panelWidth = min(286, safeRect.width * 0.58)
        let panelHeight = min(204, safeRect.height - 20)
        return CGRect(
            x: safeRect.midX - panelWidth / 2,
            y: safeRect.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )
    }

    private func renderPauseHeader(runSummary: String, in panelFrame: CGRect) {
        addLabel(
            "PAUSED",
            at: CGPoint(x: panelFrame.midX, y: panelFrame.maxY - 28),
            fontSize: 24,
            color: theme.playerColor,
            alignment: .center
        )
        addLabel(
            runSummary,
            at: CGPoint(x: panelFrame.midX, y: panelFrame.maxY - 52),
            fontSize: 9,
            color: theme.borderColor,
            alignment: .center
        )
        addDividerLine(
            from: CGPoint(x: panelFrame.minX + 14, y: panelFrame.maxY - 66),
            to: CGPoint(x: panelFrame.maxX - 14, y: panelFrame.maxY - 66),
            color: theme.playerAccentColor.withAlphaComponent(0.58)
        )
    }

    private func renderPauseControls(in panelFrame: CGRect) {
        let contentMinX = panelFrame.minX + 14
        let contentWidth = panelFrame.width - 28
        addButton(
            "RESUME",
            frame: CGRect(x: contentMinX, y: panelFrame.maxY - 108, width: contentWidth, height: 42),
            action: .resume,
            style: .primary,
            glyph: .play,
            fontSize: 16
        )
        let utilityGap: CGFloat = 8
        let utilityWidth = (contentWidth - utilityGap) / 2
        addButton(
            "CALIBRATE",
            frame: CGRect(x: contentMinX, y: panelFrame.maxY - 150, width: utilityWidth, height: 34),
            action: .openCalibrationPreview,
            style: .secondary,
            glyph: .radar,
            fontSize: 10
        )
        addButton(
            "OPTIONS",
            frame: CGRect(
                x: contentMinX + utilityWidth + utilityGap,
                y: panelFrame.maxY - 150,
                width: utilityWidth,
                height: 34
            ),
            action: .openOptions,
            style: .secondary,
            glyph: .settings,
            fontSize: 10
        )
        renderPauseFooter(in: panelFrame)
    }

    private func renderPauseFooter(in panelFrame: CGRect) {
        let contentMinX = panelFrame.minX + 14
        let contentWidth = panelFrame.width - 28
        let utilityGap: CGFloat = 8
        let utilityWidth = (contentWidth - utilityGap) / 2
        #if DEBUG
        addButton(
            "DEV",
            frame: CGRect(
                x: contentMinX + utilityWidth + utilityGap,
                y: panelFrame.minY + 12,
                width: utilityWidth,
                height: 32
            ),
            action: .openDeveloperTuning,
            style: .secondary
        )
        let endRunWidth = utilityWidth
        #else
        let endRunWidth = contentWidth
        #endif
        addButton(
            "END RUN",
            frame: CGRect(
                x: contentMinX,
                y: panelFrame.minY + 12,
                width: endRunWidth,
                height: 32
            ),
            action: .endRun,
            style: .danger,
            fontSize: 11
        )
    }
}
