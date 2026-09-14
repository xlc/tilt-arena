import SpriteKit

struct ArenaControlHitTarget {
    let action: ArenaControlAction
    let frame: CGRect
}

enum ArenaControlAction: Equatable {
    case play
    case playAgain
    case openModes
    case openAwards
    case openWeaponCodex
    case weaponCodexPage(Int)
    case openOptions
    case openDeveloperTuning
    case openCalibrationPreview
    case home
    case back
    case selectMode(ArenaModeKind)
    case resume
    case calibrate
    case endRun
    case sensitivityDown
    case sensitivityUp
    case preset(TiltCalibrationPreset)
    case toggleAudio
    case toggleHaptics
    case selectTheme(ArenaThemeKind)
    case resetData
    case openDiagnostics
    case openClassicLeaderboard
    case developerTuningPreviousPage
    case developerTuningNextPage
    case selectTuningGroup(String)
    case selectTuningSubgroup(String)
    case toggleDeveloperTuningChangedOnly
    case adjustTuningParameter(String, GameTuningAdjustmentDirection)
    case copyTuningParameters
    case resetTuningParameters
}

enum ArenaButtonStyle {
    case primary
    case secondary
    case danger
}

enum ArenaTiltSettingsControlStyle {
    case calibration
    case options
}

enum ArenaControlGlyph: Equatable {
    case play
    case radar
    case award
    case weapon
    case ranks
    case settings
    case home
    case check
}

enum ArenaUIZPosition {
    static let scrim: CGFloat = 0
    static let preview: CGFloat = 4
    static let content: CGFloat = 8
    static let progress: CGFloat = 12
    static let panel: CGFloat = 16
    static let control: CGFloat = 24
    static let controlFill: CGFloat = 25
    static let label: CGFloat = 32
}

@MainActor
final class ArenaUIRenderer {
    let root = SKNode()
    private(set) var hitTargets: [ArenaControlHitTarget] = []
    private(set) var theme = ArenaThemeKind.darkTacticalRadar.theme
    private var sceneSize = CGSize.zero

    func begin(theme: ArenaTheme, sceneSize: CGSize) {
        self.theme = theme
        self.sceneSize = sceneSize
        root.removeAllChildren()
        hitTargets.removeAll()
    }

    func addHitTarget(action: ArenaControlAction, frame: CGRect) {
        hitTargets.append(ArenaControlHitTarget(action: action, frame: frame))
    }

    func addTiltSettingsControls(
        settings: TiltControlSettings,
        in frame: CGRect,
        style: ArenaTiltSettingsControlStyle
    ) {
        let metrics = tiltSettingsMetrics(for: style, frame: frame)
        addSensitivityControls(settings: settings, frame: frame, metrics: metrics)
        addPresetControls(settings: settings, frame: frame, metrics: metrics)
    }

    private func addSensitivityControls(
        settings: TiltControlSettings,
        frame: CGRect,
        metrics: TiltSettingsMetrics
    ) {
        addSmallLabel(
            "SENSITIVITY \(String(format: "%.1f", settings.clampedSensitivity))",
            at: CGPoint(x: frame.minX + metrics.inset, y: metrics.sensitivityLabelY),
            color: theme.borderColor,
            alignment: .left
        )
        addButton(
            "-",
            frame: CGRect(
                x: frame.minX + metrics.inset,
                y: metrics.stepperY,
                width: metrics.stepperWidth,
                height: metrics.stepperHeight
            ),
            action: .sensitivityDown,
            style: .secondary
        )
        addButton(
            "+",
            frame: CGRect(
                x: frame.maxX - metrics.inset - metrics.stepperWidth,
                y: metrics.stepperY,
                width: metrics.stepperWidth,
                height: metrics.stepperHeight
            ),
            action: .sensitivityUp,
            style: .secondary
        )
        addProgressBar(
            frame: CGRect(
                x: frame.minX + metrics.inset + metrics.stepperWidth + metrics.progressSpacing,
                y: metrics.progressY,
                width: max(
                    0,
                    frame.width - metrics.inset * 2 - metrics.stepperWidth * 2 - metrics.progressSpacing * 2
                ),
                height: 4
            ),
            fraction: (
                settings.clampedSensitivity - TiltControlSettings.minimumSensitivity
            ) / (
                TiltControlSettings.maximumSensitivity - TiltControlSettings.minimumSensitivity
            )
        )
    }

    private func addPresetControls(
        settings: TiltControlSettings,
        frame: CGRect,
        metrics: TiltSettingsMetrics
    ) {
        addSectionLabel("PRESET", at: CGPoint(x: frame.minX + metrics.inset, y: metrics.presetLabelY))
        let spacing: CGFloat = 5
        let width = max(0, (frame.width - metrics.inset * 2 - spacing * 2) / 3)
        for (index, preset) in [TiltCalibrationPreset.standard, .flatTable, .reclined].enumerated() {
            let buttonFrame = CGRect(
                x: frame.minX + metrics.inset + CGFloat(index) * (width + spacing),
                y: metrics.presetY,
                width: width,
                height: metrics.presetHeight
            )
            let isSelected = settings.calibration.preset == preset
            addButton(
                presetTitle(preset),
                frame: buttonFrame,
                action: .preset(preset),
                style: isSelected ? .primary : .secondary,
                fontSize: 9
            )
            if isSelected {
                addSelectionIndicator(in: buttonFrame)
            }
        }
    }

    func addToggle(title: String, isOn: Bool, frame: CGRect, action: ArenaControlAction) {
        addButton(
            "\(title) \(isOn ? "ON" : "OFF")",
            frame: frame,
            action: action,
            style: isOn ? .primary : .secondary,
            fontSize: 10
        )
        if isOn {
            addSelectionIndicator(in: frame)
        }
    }

    func addSelectionIndicator(in frame: CGRect) {
        let position = CGPoint(x: frame.maxX - 11, y: frame.maxY - 10)
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.position = position
        ring.zPosition = ArenaUIZPosition.controlFill
        ring.fillColor = theme.panelFillColor.withAlphaComponent(0.92)
        ring.strokeColor = theme.playerAccentColor
        ring.lineWidth = 1
        root.addChild(ring)
        addControlGlyph(.check, at: position, radius: 3.5, color: theme.playerAccentColor)
    }

    func addBackButton(frame: CGRect) {
        addButton("<", frame: frame, action: .back, style: .secondary)
    }

    func addScrim(alpha: CGFloat) {
        let scrim = SKShapeNode(rect: CGRect(origin: .zero, size: sceneSize))
        scrim.zPosition = ArenaUIZPosition.scrim
        let color = theme.kind == .darkTacticalRadar ? SKColor.black : theme.backgroundColor
        scrim.fillColor = color.withAlphaComponent(alpha)
        scrim.strokeColor = .clear
        root.addChild(scrim)
    }

    func addPanel(
        frame: CGRect,
        stroke: SKColor? = nil,
        fill: SKColor? = nil,
        accent: SKColor? = nil
    ) {
        let panel = SKShapeNode(rect: frame, cornerRadius: 8)
        panel.zPosition = ArenaUIZPosition.panel
        panel.fillColor = fill ?? theme.panelFillColor
        panel.strokeColor = stroke ?? theme.panelStrokeColor
        panel.lineWidth = 0.75
        root.addChild(panel)

        if let accent {
            addCornerAccents(frame: frame, color: accent)
        }
    }

    func addCornerAccents(frame: CGRect, color: SKColor) {
        let length = min(12, min(frame.width, frame.height) * 0.22)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: frame.minX + 3, y: frame.maxY - length - 3))
        path.addLine(to: CGPoint(x: frame.minX + 3, y: frame.maxY - 3))
        path.addLine(to: CGPoint(x: frame.minX + length + 3, y: frame.maxY - 3))
        path.move(to: CGPoint(x: frame.maxX - length - 3, y: frame.minY + 3))
        path.addLine(to: CGPoint(x: frame.maxX - 3, y: frame.minY + 3))
        path.addLine(to: CGPoint(x: frame.maxX - 3, y: frame.minY + length + 3))

        let accents = SKShapeNode(path: path)
        accents.zPosition = ArenaUIZPosition.controlFill
        accents.strokeColor = color
        accents.lineWidth = 0.9
        accents.lineCap = .square
        root.addChild(accents)
    }

    func addProgressBar(frame: CGRect, fraction: Double, color: SKColor? = nil) {
        let background = SKShapeNode(rect: frame, cornerRadius: 2)
        background.zPosition = ArenaUIZPosition.control
        background.fillColor = theme.borderColor.withAlphaComponent(0.18)
        background.strokeColor = .clear
        root.addChild(background)

        let fillWidth = max(0, frame.width * CGFloat(min(1, max(0, fraction))))
        guard fillWidth > 0 else {
            return
        }

        let fill = SKShapeNode(
            rect: CGRect(x: frame.minX, y: frame.minY, width: fillWidth, height: frame.height),
            cornerRadius: 2
        )
        fill.zPosition = ArenaUIZPosition.controlFill
        fill.fillColor = (color ?? theme.playerAccentColor).withAlphaComponent(0.9)
        fill.strokeColor = .clear
        root.addChild(fill)
    }

    func addDividerLine(from start: CGPoint, to end: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        let line = SKShapeNode(path: path)
        line.zPosition = ArenaUIZPosition.panel
        line.strokeColor = color
        line.lineWidth = 1
        root.addChild(line)
    }

    func addButton(
        _ title: String,
        frame: CGRect,
        action: ArenaControlAction,
        style: ArenaButtonStyle,
        glyph: ArenaControlGlyph? = nil,
        fontSize: CGFloat? = nil
    ) {
        let colors = buttonColors(for: style)
        let button = SKShapeNode(rect: frame, cornerRadius: 7)
        button.zPosition = ArenaUIZPosition.control
        button.fillColor = colors.fill
        button.strokeColor = colors.stroke
        button.lineWidth = style == .primary ? 1.1 : 0.8
        button.glowWidth = theme.kind == .darkTacticalRadar && style == .primary ? 0.45 : 0
        root.addChild(button)

        let compactGlyphLayout = glyph != nil && frame.width < 112
        let resolvedFontSize = fontSize ?? (glyph == nil ? 14 : (compactGlyphLayout ? 10 : 16))
        let labelX = glyph == nil ? frame.midX : frame.midX + (compactGlyphLayout ? 8 : 10)

        if let glyph {
            addControlGlyph(
                glyph,
                at: CGPoint(x: frame.minX + (compactGlyphLayout ? 14 : 24), y: frame.midY),
                radius: compactGlyphLayout ? 7 : 10,
                color: colors.text
            )
        }

        addLabel(
            title,
            at: CGPoint(x: labelX, y: frame.midY - 1),
            fontSize: resolvedFontSize,
            color: colors.text,
            alignment: .center
        )
        addHitTarget(action: action, frame: frame)
    }

    // The switch is the complete shape vocabulary for the compact in-game icon set.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func addControlGlyph(
        _ glyph: ArenaControlGlyph,
        at position: CGPoint,
        radius: CGFloat,
        color: SKColor
    ) {
        let glyphRoot = SKNode()
        glyphRoot.position = position
        glyphRoot.zPosition = ArenaUIZPosition.label
        root.addChild(glyphRoot)

        let path = CGMutablePath()
        switch glyph {
        case .play:
            path.move(to: CGPoint(x: -radius * 0.55, y: -radius * 0.8))
            path.addLine(to: CGPoint(x: radius * 0.8, y: 0))
            path.addLine(to: CGPoint(x: -radius * 0.55, y: radius * 0.8))
            path.closeSubpath()
        case .radar:
            for scale in [CGFloat(0.45), 0.9] {
                path.addEllipse(in: CGRect(
                    x: -radius * scale,
                    y: -radius * scale,
                    width: radius * scale * 2,
                    height: radius * scale * 2
                ))
            }
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: radius * 0.74, y: radius * 0.5))
        case .award:
            for index in 0..<10 {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
                let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.42
                let point = CGPoint(x: cos(angle) * pointRadius, y: sin(angle) * pointRadius)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        case .weapon:
            path.addEllipse(in: CGRect(x: -radius * 0.72, y: -radius * 0.72, width: radius * 1.44, height: radius * 1.44))
            path.move(to: CGPoint(x: -radius, y: 0))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.move(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: 0, y: radius))
        case .ranks:
            for offset in [-radius * 0.42, radius * 0.2] {
                path.move(to: CGPoint(x: -radius * 0.8, y: offset - radius * 0.2))
                path.addLine(to: CGPoint(x: 0, y: offset + radius * 0.38))
                path.addLine(to: CGPoint(x: radius * 0.8, y: offset - radius * 0.2))
            }
        case .settings:
            for index in 0..<6 {
                let angle = CGFloat(index) * CGFloat.pi / 3
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: -radius * 0.28, y: -radius * 0.28, width: radius * 0.56, height: radius * 0.56))
        case .home:
            path.move(to: CGPoint(x: -radius, y: -radius * 0.05))
            path.addLine(to: CGPoint(x: 0, y: radius * 0.86))
            path.addLine(to: CGPoint(x: radius, y: -radius * 0.05))
            path.move(to: CGPoint(x: -radius * 0.72, y: 0))
            path.addLine(to: CGPoint(x: -radius * 0.72, y: -radius * 0.82))
            path.addLine(to: CGPoint(x: radius * 0.72, y: -radius * 0.82))
            path.addLine(to: CGPoint(x: radius * 0.72, y: 0))
        case .check:
            path.move(to: CGPoint(x: -radius * 0.82, y: 0))
            path.addLine(to: CGPoint(x: -radius * 0.2, y: -radius * 0.62))
            path.addLine(to: CGPoint(x: radius * 0.9, y: radius * 0.68))
        }

        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.fillColor = glyph == .play || glyph == .award ? color.withAlphaComponent(0.9) : .clear
        node.lineWidth = max(1, radius * 0.15)
        node.lineCap = .round
        node.lineJoin = .round
        glyphRoot.addChild(node)
    }

    func addTitle(_ text: String, at position: CGPoint) {
        addLabel(text, at: position, fontSize: 22, color: theme.playerColor, alignment: .left)
    }

    func addSmallLabel(
        _ text: String,
        at position: CGPoint,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        addLabel(text, at: position, fontSize: 12, color: color, alignment: alignment)
    }

    func addSectionLabel(_ text: String, at position: CGPoint) {
        addLabel(
            text,
            at: position,
            fontSize: 10,
            color: theme.borderColor.withAlphaComponent(0.82),
            alignment: .left
        )
    }

    func addLabel(
        _ text: String,
        at position: CGPoint,
        fontSize: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        root.addChild(makeLabel(text, at: position, fontSize: fontSize, color: color, alignment: alignment))
    }

    func makeLabel(
        _ text: String,
        at position: CGPoint,
        fontSize: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode
    ) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: fontSize >= 16 ? "Menlo-Bold" : "Menlo")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = ArenaUIZPosition.label
        return label
    }

    func presetTitle(_ preset: TiltCalibrationPreset) -> String {
        switch preset {
        case .standard:
            return "STD"
        case .flatTable:
            return "TABLE"
        case .reclined:
            return "RECL"
        case .custom:
            return "CUSTOM"
        }
    }

    func presetDisplayTitle(_ preset: TiltCalibrationPreset) -> String {
        switch preset {
        case .standard:
            return "STANDARD"
        case .flatTable:
            return "TABLE"
        case .reclined:
            return "RECLINED"
        case .custom:
            return "CUSTOM"
        }
    }

    private func buttonColors(for style: ArenaButtonStyle) -> ButtonColors {
        switch style {
        case .primary:
            return ButtonColors(
                fill: theme.playerAccentColor.withAlphaComponent(0.18),
                stroke: theme.playerAccentColor.withAlphaComponent(0.82),
                text: theme.playerColor
            )
        case .secondary:
            return ButtonColors(
                fill: theme.borderColor.withAlphaComponent(0.07),
                stroke: theme.borderColor.withAlphaComponent(0.32),
                text: theme.playerColor.withAlphaComponent(0.8)
            )
        case .danger:
            return ButtonColors(
                fill: theme.enemyColor.withAlphaComponent(0.1),
                stroke: theme.enemyColor.withAlphaComponent(0.62),
                text: theme.enemyColor.withAlphaComponent(0.9)
            )
        }
    }

    private func tiltSettingsMetrics(
        for style: ArenaTiltSettingsControlStyle,
        frame: CGRect
    ) -> TiltSettingsMetrics {
        switch style {
        case .calibration:
            return TiltSettingsMetrics(
                inset: 12,
                sensitivityLabelY: frame.maxY - 108,
                stepperY: frame.maxY - 142,
                stepperWidth: 40,
                stepperHeight: 26,
                progressY: frame.maxY - 130,
                progressSpacing: 7,
                presetLabelY: frame.maxY - 154,
                presetY: frame.maxY - 188,
                presetHeight: 28
            )
        case .options:
            return TiltSettingsMetrics(
                inset: 10,
                sensitivityLabelY: frame.maxY - 74,
                stepperY: frame.maxY - 112,
                stepperWidth: 42,
                stepperHeight: 28,
                progressY: frame.maxY - 99,
                progressSpacing: 8,
                presetLabelY: frame.minY + 36,
                presetY: frame.minY + 7,
                presetHeight: 26
            )
        }
    }
}

private struct TiltSettingsMetrics {
    let inset: CGFloat
    let sensitivityLabelY: CGFloat
    let stepperY: CGFloat
    let stepperWidth: CGFloat
    let stepperHeight: CGFloat
    let progressY: CGFloat
    let progressSpacing: CGFloat
    let presetLabelY: CGFloat
    let presetY: CGFloat
    let presetHeight: CGFloat
}

private struct ButtonColors {
    let fill: SKColor
    let stroke: SKColor
    let text: SKColor
}
