import CoreGraphics
import Foundation

struct GameModeTuningConfiguration: Equatable {
    var enemySpawnConfiguration: EnemySpawnConfiguration
    var pickupSpawnConfiguration: PickupSpawnConfiguration
}

struct GameFeedbackTuningConfiguration: Equatable {
    var deathReplayDuration: TimeInterval = 2
    var deathShakeAmplitude: CGFloat = 5
    var deathShakeDuration: TimeInterval = 0.18
    var multiKillShakeThreshold = 8
    var multiKillShakeAmplitude: CGFloat = 3
    var multiKillShakeDuration: TimeInterval = 0.14
    var razorShieldWarningLeadTime: TimeInterval = 0.75
}

struct GameTuningConfiguration: Equatable {
    var playerMovement = PlayerMovementConfiguration()
    var run = ClassicRunConfiguration()
    var readyStart = ReadyStartHoldConfiguration()
    var classic: GameModeTuningConfiguration
    var redline: GameModeTuningConfiguration
    var daily: GameModeTuningConfiguration
    // Weapon tuning entry points:
    // - startingWeapons: gameplay reach, duration, target counts, and clear strength.
    // - weaponEffectTiming: shared visual travel timing only.
    // - flameTrail: persistent trail segments and its movement boost.
    // Keep GameTuningParameterCatalog in sync when adding new public tuning knobs.
    var startingWeapons = StartingWeaponConfiguration()
    var weaponEffectTiming = WeaponEffectTiming()
    var flameTrail = FlameTrailConfiguration()
    var feedback = GameFeedbackTuningConfiguration()

    init(
        playerMovement: PlayerMovementConfiguration = PlayerMovementConfiguration(),
        run: ClassicRunConfiguration = ClassicRunConfiguration(),
        readyStart: ReadyStartHoldConfiguration = ReadyStartHoldConfiguration(),
        classic: GameModeTuningConfiguration = GameTuningConfiguration.defaultModeTuning(for: .classic),
        redline: GameModeTuningConfiguration = GameTuningConfiguration.defaultModeTuning(for: .redline),
        daily: GameModeTuningConfiguration = GameTuningConfiguration.defaultModeTuning(for: .daily),
        startingWeapons: StartingWeaponConfiguration = StartingWeaponConfiguration(),
        weaponEffectTiming: WeaponEffectTiming = WeaponEffectTiming(),
        flameTrail: FlameTrailConfiguration = FlameTrailConfiguration(),
        feedback: GameFeedbackTuningConfiguration = GameFeedbackTuningConfiguration()
    ) {
        self.playerMovement = playerMovement
        self.run = run
        self.readyStart = readyStart
        self.classic = classic
        self.redline = redline
        self.daily = daily
        self.startingWeapons = startingWeapons
        self.weaponEffectTiming = weaponEffectTiming
        self.flameTrail = flameTrail
        self.feedback = feedback
    }

    static var defaults: GameTuningConfiguration {
        GameTuningConfiguration()
    }

    func modeTuning(for mode: ArenaModeKind) -> GameModeTuningConfiguration {
        switch mode {
        case .classic:
            return classic
        case .redline:
            return redline
        case .daily:
            return daily
        }
    }

    mutating func adjustParameter(id: String, direction: GameTuningAdjustmentDirection) {
        guard let parameter = GameTuningParameterCatalog.parameter(id: id) else {
            return
        }

        parameter.adjust(&self, direction: direction)
    }

    func isChanged(_ parameter: GameTuningParameterSpec, comparedTo baseline: GameTuningConfiguration = .defaults) -> Bool {
        !parameter.matchesDefault(in: self, baseline: baseline)
    }

    func changedParameters(comparedTo baseline: GameTuningConfiguration = .defaults) -> [GameTuningParameterSpec] {
        GameTuningParameterCatalog.parameters.filter { isChanged($0, comparedTo: baseline) }
    }

    func sourceSnapshot(changedOnly: Bool = false) -> String {
        let baseline = GameTuningConfiguration.defaults
        let parameters = changedOnly ? changedParameters(comparedTo: baseline) : GameTuningParameterCatalog.parameters
        let parameterLines = parameters.map { parameter in
            "tuning.\(parameter.sourcePath) = \(parameter.sourceValue(in: self))"
        }
        let weaponCycleLines = weaponCycleSourceLines(changedOnly: changedOnly, baseline: baseline)

        return ([
            "var tuning = GameTuningConfiguration.defaults"
        ] + parameterLines + weaponCycleLines + [
            "return tuning"
        ]).joined(separator: "\n")
    }

    private static func defaultModeTuning(for mode: ArenaModeKind) -> GameModeTuningConfiguration {
        let settings = ArenaModeRules.runSettings(for: mode)
        return GameModeTuningConfiguration(
            enemySpawnConfiguration: settings.enemySpawnConfiguration,
            pickupSpawnConfiguration: settings.pickupSpawnConfiguration
        )
    }

    private func weaponCycleSourceLine(modePath: String, tuning: GameModeTuningConfiguration) -> String {
        let values = tuning.pickupSpawnConfiguration.weaponKindCycle.map { ".\($0.rawValue)" }.joined(separator: ", ")
        return "tuning.\(modePath).pickupSpawnConfiguration.weaponKindCycle = [\(values)]"
    }

    private func weaponCycleSourceLines(changedOnly: Bool, baseline: GameTuningConfiguration) -> [String] {
        [
            (modePath: "classic", tuning: classic, baseline: baseline.classic),
            (modePath: "redline", tuning: redline, baseline: baseline.redline),
            (modePath: "daily", tuning: daily, baseline: baseline.daily)
        ].compactMap { entry in
            guard
                !changedOnly
                    || entry.tuning.pickupSpawnConfiguration.weaponKindCycle
                    != entry.baseline.pickupSpawnConfiguration.weaponKindCycle
            else {
                return nil
            }

            return weaponCycleSourceLine(modePath: entry.modePath, tuning: entry.tuning)
        }
    }
}

enum GameTuningAdjustmentDirection: Equatable {
    case decrease
    case increase

    var multiplier: Double {
        switch self {
        case .decrease:
            return -1
        case .increase:
            return 1
        }
    }
}

struct GameTuningParameterSpec {
    let id: String
    let group: String
    let title: String
    let sourcePath: String
    private let value: GameTuningParameterValue

    init(id: String, group: String, title: String, sourcePath: String, value: GameTuningParameterValue) {
        self.id = id
        self.group = group
        self.title = title
        self.sourcePath = sourcePath
        self.value = value
    }

    var menuGroup: String {
        if id.hasPrefix("classic.") {
            return "Classic"
        }
        if id.hasPrefix("redline.") {
            return "Redline"
        }
        if id.hasPrefix("daily.") {
            return "Daily"
        }
        if id.hasPrefix("startingWeapons.") {
            return "Weapons"
        }
        if id.hasPrefix("weaponEffectTiming.") {
            return "Effects"
        }
        if id.hasPrefix("flameTrail.") {
            return "Flame Trail"
        }
        if id.hasPrefix("feedback.") {
            return "Feedback"
        }
        if id.hasPrefix("playerMovement.") {
            return "Player"
        }
        if id.hasPrefix("run.") {
            return "Scoring"
        }
        if id.hasPrefix("readyStart.") {
            return "Ready"
        }

        return group
    }

    var menuSubgroup: String {
        if id.contains(".pickupSpawnConfiguration.") {
            return "Pickups"
        }
        if id.contains(".enemySpawnConfiguration.warmup.") {
            return "Warmup"
        }
        if id.contains(".enemySpawnConfiguration.pressure.") {
            return "Pressure"
        }
        if id.contains(".enemySpawnConfiguration.chaos.") {
            return "Chaos"
        }
        if id.contains(".enemySpawnConfiguration.survivalHell.") {
            return "Hell"
        }
        if id.contains(".enemySpawnConfiguration.") {
            return "Enemies"
        }
        if id.hasPrefix("startingWeapons.") {
            return Self.weaponSubgroup(for: id)
        }
        if id.hasPrefix("playerMovement.") {
            return "Movement"
        }
        if id.hasPrefix("run.") {
            return "Rules"
        }
        if id.hasPrefix("readyStart.") {
            return "Start"
        }
        if id.hasPrefix("weaponEffectTiming.") {
            return "Timing"
        }
        if id.hasPrefix("flameTrail.") {
            return "Trail"
        }
        if id.hasPrefix("feedback.") {
            return "Impact"
        }

        return "General"
    }

    func displayValue(in tuning: GameTuningConfiguration) -> String {
        value.displayValue(in: tuning)
    }

    func sourceValue(in tuning: GameTuningConfiguration) -> String {
        value.sourceValue(in: tuning)
    }

    func adjust(_ tuning: inout GameTuningConfiguration, direction: GameTuningAdjustmentDirection) {
        value.adjust(&tuning, direction: direction)
    }

    func storedValue(in tuning: GameTuningConfiguration) -> GameTuningStoredValue {
        value.storedValue(in: tuning)
    }

    func applyStoredValue(_ storedValue: GameTuningStoredValue, to tuning: inout GameTuningConfiguration) {
        value.applyStoredValue(storedValue, to: &tuning)
    }

    func matchesDefault(in tuning: GameTuningConfiguration, baseline: GameTuningConfiguration = .defaults) -> Bool {
        sourceValue(in: tuning) == sourceValue(in: baseline)
    }

    private static func weaponSubgroup(for id: String) -> String {
        if id.hasPrefix("startingWeapons.shockwave") {
            return "Shockwave"
        }
        if id.hasPrefix("startingWeapons.seeker") {
            return "Seeker"
        }
        if id.hasPrefix("startingWeapons.razorShield") {
            return "Razor Shield"
        }
        if id.hasPrefix("startingWeapons.freeze") {
            return "Freeze Burst"
        }
        if id.hasPrefix("startingWeapons.gravityWell") {
            return "Gravity Well"
        }
        if id.hasPrefix("startingWeapons.chainLightning") {
            return "Chain Lightning"
        }
        if id.hasPrefix("startingWeapons.timeDilation") {
            return "Time Dilation"
        }
        if id.hasPrefix("startingWeapons.powerWave") {
            return "Power Wave"
        }
        if id.hasPrefix("startingWeapons.ricochetLance") {
            return "Ricochet Lance"
        }
        if id.hasPrefix("startingWeapons.novaBomb") {
            return "Nova Bomb"
        }

        return "Weapons"
    }
}

struct GameTuningStoredValue: Codable, Equatable {
    enum Kind: String, Codable {
        case double
        case int
        case none
    }

    let kind: Kind
    let doubleValue: Double?
    let intValue: Int?

    static func double(_ value: Double) -> GameTuningStoredValue {
        GameTuningStoredValue(kind: .double, doubleValue: value, intValue: nil)
    }

    static func int(_ value: Int) -> GameTuningStoredValue {
        GameTuningStoredValue(kind: .int, doubleValue: nil, intValue: value)
    }

    static var none: GameTuningStoredValue {
        GameTuningStoredValue(kind: .none, doubleValue: nil, intValue: nil)
    }
}

enum GameTuningParameterValue {
    case cgFloat(WritableKeyPath<GameTuningConfiguration, CGFloat>, step: CGFloat, min: CGFloat, max: CGFloat?, decimals: Int)
    case double(WritableKeyPath<GameTuningConfiguration, Double>, step: Double, min: Double, max: Double?, decimals: Int)
    case optionalDouble(WritableKeyPath<GameTuningConfiguration, Double?>, step: Double, min: Double, max: Double?, decimals: Int)
    case int(WritableKeyPath<GameTuningConfiguration, Int>, step: Int, min: Int, max: Int?)

    func displayValue(in tuning: GameTuningConfiguration) -> String {
        switch self {
        case let .cgFloat(keyPath, _, _, _, decimals):
            return Self.format(Double(tuning[keyPath: keyPath]), decimals: decimals)
        case let .double(keyPath, _, _, _, decimals):
            return Self.format(tuning[keyPath: keyPath], decimals: decimals)
        case let .optionalDouble(keyPath, _, _, _, decimals):
            guard let value = tuning[keyPath: keyPath] else {
                return "OFF"
            }
            return Self.format(value, decimals: decimals)
        case let .int(keyPath, _, _, _):
            return "\(tuning[keyPath: keyPath])"
        }
    }

    func sourceValue(in tuning: GameTuningConfiguration) -> String {
        switch self {
        case let .cgFloat(keyPath, _, _, _, decimals):
            return Self.format(Double(tuning[keyPath: keyPath]), decimals: decimals)
        case let .double(keyPath, _, _, _, decimals):
            return Self.format(tuning[keyPath: keyPath], decimals: decimals)
        case let .optionalDouble(keyPath, _, _, _, decimals):
            guard let value = tuning[keyPath: keyPath] else {
                return "nil"
            }
            return Self.format(value, decimals: decimals)
        case let .int(keyPath, _, _, _):
            return "\(tuning[keyPath: keyPath])"
        }
    }

    func adjust(_ tuning: inout GameTuningConfiguration, direction: GameTuningAdjustmentDirection) {
        switch self {
        case let .cgFloat(keyPath, step, minValue, maxValue, _):
            let currentValue = tuning[keyPath: keyPath]
            tuning[keyPath: keyPath] = Self.clamp(
                currentValue + step * CGFloat(direction.multiplier),
                min: minValue,
                max: maxValue
            )
        case let .double(keyPath, step, minValue, maxValue, _):
            let currentValue = tuning[keyPath: keyPath]
            tuning[keyPath: keyPath] = Self.clamp(
                currentValue + step * direction.multiplier,
                min: minValue,
                max: maxValue
            )
        case let .optionalDouble(keyPath, step, minValue, maxValue, _):
            switch (tuning[keyPath: keyPath], direction) {
            case (.none, .increase):
                tuning[keyPath: keyPath] = Self.clamp(max(step, minValue), min: minValue, max: maxValue)
            case (.none, .decrease):
                return
            case let (.some(currentValue), _):
                let nextValue = currentValue + step * direction.multiplier
                if nextValue < minValue {
                    tuning[keyPath: keyPath] = nil
                } else {
                    tuning[keyPath: keyPath] = Self.clamp(nextValue, min: minValue, max: maxValue)
                }
            }
        case let .int(keyPath, step, minValue, maxValue):
            let currentValue = tuning[keyPath: keyPath]
            tuning[keyPath: keyPath] = Self.clamp(
                currentValue + step * (direction == .increase ? 1 : -1),
                min: minValue,
                max: maxValue
            )
        }
    }

    func storedValue(in tuning: GameTuningConfiguration) -> GameTuningStoredValue {
        switch self {
        case let .cgFloat(keyPath, _, _, _, _):
            return .double(Double(tuning[keyPath: keyPath]))
        case let .double(keyPath, _, _, _, _):
            return .double(tuning[keyPath: keyPath])
        case let .optionalDouble(keyPath, _, _, _, _):
            guard let value = tuning[keyPath: keyPath] else {
                return .none
            }

            return .double(value)
        case let .int(keyPath, _, _, _):
            return .int(tuning[keyPath: keyPath])
        }
    }

    func applyStoredValue(_ storedValue: GameTuningStoredValue, to tuning: inout GameTuningConfiguration) {
        switch (self, storedValue.kind) {
        case let (.cgFloat(keyPath, _, _, _, _), .double):
            guard let value = storedValue.doubleValue else { return }
            tuning[keyPath: keyPath] = CGFloat(value)
        case let (.double(keyPath, _, _, _, _), .double):
            guard let value = storedValue.doubleValue else { return }
            tuning[keyPath: keyPath] = value
        case let (.optionalDouble(keyPath, _, _, _, _), .double):
            guard let value = storedValue.doubleValue else { return }
            tuning[keyPath: keyPath] = value
        case let (.optionalDouble(keyPath, _, _, _, _), .none):
            tuning[keyPath: keyPath] = nil
        case let (.int(keyPath, _, _, _), .int):
            guard let value = storedValue.intValue else { return }
            tuning[keyPath: keyPath] = value
        default:
            return
        }
    }

    private static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T?) -> T {
        var result = Swift.max(value, minValue)
        if let maxValue {
            result = Swift.min(result, maxValue)
        }
        return result
    }

    private static func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
