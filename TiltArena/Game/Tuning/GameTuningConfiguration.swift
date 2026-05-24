// swiftlint:disable line_length function_parameter_count
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
    var startingWeapons = StartingWeaponConfiguration()
    var weaponEffectTiming = WeaponEffectTiming()
    var flameTrail = FlameTrailConfiguration()
    var decoyBeacon = DecoyBeaconConfiguration()
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
        decoyBeacon: DecoyBeaconConfiguration = DecoyBeaconConfiguration(),
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
        self.decoyBeacon = decoyBeacon
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

    func sourceSnapshot() -> String {
        let parameterLines = GameTuningParameterCatalog.parameters.map { parameter in
            "tuning.\(parameter.sourcePath) = \(parameter.sourceValue(in: self))"
        }
        let weaponCycleLines = [
            weaponCycleSourceLine(modePath: "classic", tuning: classic),
            weaponCycleSourceLine(modePath: "redline", tuning: redline),
            weaponCycleSourceLine(modePath: "daily", tuning: daily)
        ]

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

    func displayValue(in tuning: GameTuningConfiguration) -> String {
        value.displayValue(in: tuning)
    }

    func sourceValue(in tuning: GameTuningConfiguration) -> String {
        value.sourceValue(in: tuning)
    }

    func adjust(_ tuning: inout GameTuningConfiguration, direction: GameTuningAdjustmentDirection) {
        value.adjust(&tuning, direction: direction)
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

enum GameTuningParameterCatalog {
    nonisolated(unsafe) static let parameters: [GameTuningParameterSpec] = {
        var specs: [GameTuningParameterSpec] = []

        appendPlayerParameters(to: &specs)
        appendRunParameters(to: &specs)
        appendReadyStartParameters(to: &specs)
        appendModeParameters(
            modeTitle: "Classic",
            sourcePrefix: "classic",
            modeKeyPath: \.classic,
            to: &specs
        )
        appendModeParameters(
            modeTitle: "Redline",
            sourcePrefix: "redline",
            modeKeyPath: \.redline,
            to: &specs
        )
        appendModeParameters(
            modeTitle: "Daily",
            sourcePrefix: "daily",
            modeKeyPath: \.daily,
            to: &specs
        )
        appendStartingWeaponParameters(to: &specs)
        appendWeaponEffectParameters(to: &specs)
        appendFlameTrailParameters(to: &specs)
        appendDecoyBeaconParameters(to: &specs)
        appendFeedbackParameters(to: &specs)

        return specs
    }()

    static func parameter(id: String) -> GameTuningParameterSpec? {
        parameters.first { $0.id == id }
    }

    private static func appendPlayerParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(cgFloat("playerMovement.visualRadius", "Player", "visual radius", \.playerMovement.visualRadius, 1, 1, nil, 1))
        specs.append(cgFloat("playerMovement.borderInset", "Player", "border inset", \.playerMovement.borderInset, 1, 0, nil, 1))
        specs.append(double("playerMovement.arenaCrossingDuration", "Player", "crossing duration", \.playerMovement.arenaCrossingDuration, 0.1, 0.1, nil, 2))
    }

    private static func appendRunParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(cgFloat("run.playerVisualRadius", "Scoring", "player visual radius", \.run.playerVisualRadius, 1, 1, nil, 1))
        specs.append(cgFloat("run.playerHitRadiusScale", "Scoring", "hit radius scale", \.run.playerHitRadiusScale, 0.05, 0.05, 2, 2))
        specs.append(int("run.baseEnemyScore", "Scoring", "base enemy score", \.run.baseEnemyScore, 1, 0, nil))
        specs.append(int("run.eliteEnemyScore", "Scoring", "elite enemy score", \.run.eliteEnemyScore, 1, 0, nil))
        specs.append(int("run.frozenShatterScore", "Scoring", "frozen shatter score", \.run.frozenShatterScore, 1, 0, nil))
        specs.append(int("run.formationBonusScore", "Scoring", "formation bonus", \.run.formationBonusScore, 5, 0, nil))
        specs.append(int("run.nearMissScore", "Scoring", "near miss score", \.run.nearMissScore, 1, 0, nil))
        specs.append(int("run.dangerGrabScore", "Scoring", "danger grab score", \.run.dangerGrabScore, 1, 0, nil))
        specs.append(double("run.comboWindow", "Scoring", "combo window", \.run.comboWindow, 0.1, 0, nil, 2))
        specs.append(int("run.killsPerMultiplierStep", "Scoring", "kills per multiplier", \.run.killsPerMultiplierStep, 1, 1, nil))
        specs.append(double("run.survivalBonusStartTime", "Scoring", "survival bonus start", \.run.survivalBonusStartTime, 5, 0, nil, 1))
        specs.append(double("run.survivalBonusInterval", "Scoring", "survival bonus interval", \.run.survivalBonusInterval, 1, 0, nil, 1))
        specs.append(int("run.survivalBonusPointsPerInterval", "Scoring", "survival bonus points", \.run.survivalBonusPointsPerInterval, 1, 0, nil))
        specs.append(cgFloat("run.nearMissEdgeGap", "Scoring", "near miss edge gap", \.run.nearMissEdgeGap, 1, 0, nil, 1))
        specs.append(cgFloat("run.dangerGrabEnemyDistance", "Scoring", "danger grab distance", \.run.dangerGrabEnemyDistance, 4, 0, nil, 1))
    }

    private static func appendReadyStartParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(double("readyStart.requiredDuration", "Ready", "required duration", \.readyStart.requiredDuration, 0.25, 0, nil, 2))
        specs.append(cgFloat("readyStart.startCircleRadius", "Ready", "start circle radius", \.readyStart.startCircleRadius, 2, 4, nil, 1))
    }

    private static func appendModeParameters(
        modeTitle: String,
        sourcePrefix: String,
        modeKeyPath: WritableKeyPath<GameTuningConfiguration, GameModeTuningConfiguration>,
        to specs: inout [GameTuningParameterSpec]
    ) {
        let enemyKeyPath = modeKeyPath.appending(path: \.enemySpawnConfiguration)
        let pickupKeyPath = modeKeyPath.appending(path: \.pickupSpawnConfiguration)

        appendEnemyParameters(
            modeTitle: modeTitle,
            sourcePrefix: "\(sourcePrefix).enemySpawnConfiguration",
            keyPath: enemyKeyPath,
            to: &specs
        )
        appendPickupParameters(
            modeTitle: modeTitle,
            sourcePrefix: "\(sourcePrefix).pickupSpawnConfiguration",
            keyPath: pickupKeyPath,
            to: &specs
        )
    }

    private static func appendEnemyParameters(
        modeTitle: String,
        sourcePrefix: String,
        keyPath: WritableKeyPath<GameTuningConfiguration, EnemySpawnConfiguration>,
        to specs: inout [GameTuningParameterSpec]
    ) {
        let group = "\(modeTitle) Enemies"
        specs.append(cgFloat("\(sourcePrefix).enemyRadius", group, "enemy radius", keyPath.appending(path: \.enemyRadius), 1, 1, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).playerSafetyRadius", group, "player safety radius", keyPath.appending(path: \.playerSafetyRadius), 4, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).pickupClearance", group, "pickup clearance", keyPath.appending(path: \.pickupClearance), 1, 0, nil, 1))
        specs.append(double("\(sourcePrefix).formationTelegraphDuration", group, "formation telegraph", keyPath.appending(path: \.formationTelegraphDuration), 0.05, 0, nil, 2))
        specs.append(cgFloat("\(sourcePrefix).formationLineInset", group, "formation line inset", keyPath.appending(path: \.formationLineInset), 1, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).formationGapScale", group, "formation gap scale", keyPath.appending(path: \.formationGapScale), 0.05, 0.1, 3, 2))
        specs.append(cgFloat("\(sourcePrefix).formationSpawnOffset", group, "formation spawn offset", keyPath.appending(path: \.formationSpawnOffset), 1, 0, nil, 1))
        specs.append(int("\(sourcePrefix).minimumFormationEnemyCount", group, "min formation enemies", keyPath.appending(path: \.minimumFormationEnemyCount), 1, 1, nil))
        specs.append(double("\(sourcePrefix).arrowRushTelegraphDuration", group, "arrow telegraph", keyPath.appending(path: \.arrowRushTelegraphDuration), 0.05, 0, nil, 2))
        specs.append(cgFloat("\(sourcePrefix).arrowRushSpawnOffset", group, "arrow spawn offset", keyPath.appending(path: \.arrowRushSpawnOffset), 1, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).arrowRushEnemySpacing", group, "arrow spacing", keyPath.appending(path: \.arrowRushEnemySpacing), 1, 0, nil, 1))
        specs.append(int("\(sourcePrefix).minimumArrowRushEnemyCount", group, "min arrow enemies", keyPath.appending(path: \.minimumArrowRushEnemyCount), 1, 1, nil))
        specs.append(double("\(sourcePrefix).mineDotTelegraphDuration", group, "mine telegraph", keyPath.appending(path: \.mineDotTelegraphDuration), 0.05, 0, nil, 2))
        specs.append(cgFloat("\(sourcePrefix).mineDotTelegraphRadius", group, "mine telegraph radius", keyPath.appending(path: \.mineDotTelegraphRadius), 1, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).mineDotPickupGuardDistance", group, "mine pickup guard", keyPath.appending(path: \.mineDotPickupGuardDistance), 2, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).mineDotCandidateInset", group, "mine candidate inset", keyPath.appending(path: \.mineDotCandidateInset), 2, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).mineDotMinimumSpacing", group, "mine spacing", keyPath.appending(path: \.mineDotMinimumSpacing), 2, 0, nil, 1))
        specs.append(double("\(sourcePrefix).hunterDotTelegraphDuration", group, "hunter telegraph", keyPath.appending(path: \.hunterDotTelegraphDuration), 0.05, 0, nil, 2))
        specs.append(double("\(sourcePrefix).paddleTrapTelegraphDuration", group, "paddle telegraph", keyPath.appending(path: \.paddleTrapTelegraphDuration), 0.05, 0, nil, 2))
        specs.append(cgFloat("\(sourcePrefix).paddleTrapBarSpacing", group, "paddle bar spacing", keyPath.appending(path: \.paddleTrapBarSpacing), 1, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).paddleTrapBarGap", group, "paddle bar gap", keyPath.appending(path: \.paddleTrapBarGap), 2, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).paddleTrapCandidateInset", group, "paddle candidate inset", keyPath.appending(path: \.paddleTrapCandidateInset), 2, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).paddleTrapMinimumSpacing", group, "paddle spacing", keyPath.appending(path: \.paddleTrapMinimumSpacing), 2, 0, nil, 1))
        specs.append(int("\(sourcePrefix).maxPendingEnemyTelegraphs", group, "max pending telegraphs", keyPath.appending(path: \.maxPendingEnemyTelegraphs), 1, 0, nil))
        specs.append(cgFloat("\(sourcePrefix).cullingOutset", group, "culling outset", keyPath.appending(path: \.cullingOutset), 4, 0, nil, 1))

        appendPhaseParameters("Warmup", sourcePrefix, keyPath.appending(path: \.warmup), to: &specs)
        appendPhaseParameters("Pressure", sourcePrefix, keyPath.appending(path: \.pressure), to: &specs)
        appendPhaseParameters("Chaos", sourcePrefix, keyPath.appending(path: \.chaos), to: &specs)
        appendPhaseParameters("Hell", sourcePrefix, keyPath.appending(path: \.survivalHell), to: &specs)
    }

    private static func appendPhaseParameters(
        _ phaseTitle: String,
        _ sourcePrefix: String,
        _ keyPath: WritableKeyPath<GameTuningConfiguration, EnemyPhaseTuning>,
        to specs: inout [GameTuningParameterSpec]
    ) {
        let sourcePhase = phaseTitle == "Hell" ? "survivalHell" : phaseTitle.prefix(1).lowercased() + phaseTitle.dropFirst()
        let group = "\(sourcePrefix.components(separatedBy: ".").first?.capitalized ?? "") \(phaseTitle)"
        let phasePrefix = "\(sourcePrefix).\(sourcePhase)"

        specs.append(double("\(phasePrefix).chaserSpawnInterval", group, "chaser interval", keyPath.appending(path: \.chaserSpawnInterval), 0.05, 0.05, nil, 2))
        specs.append(cgFloat("\(phasePrefix).chaserSpeed", group, "chaser speed", keyPath.appending(path: \.chaserSpeed), 2, 0, nil, 1))
        specs.append(int("\(phasePrefix).maxActiveEnemies", group, "max active enemies", keyPath.appending(path: \.maxActiveEnemies), 5, 0, nil))
        specs.append(optionalDouble("\(phasePrefix).formationSpawnInterval", group, "formation interval", keyPath.appending(path: \.formationSpawnInterval), 0.5, 0.1, nil, 2))
        specs.append(cgFloat("\(phasePrefix).formationSpeed", group, "formation speed", keyPath.appending(path: \.formationSpeed), 2, 0, nil, 1))
        specs.append(int("\(phasePrefix).formationLaneCount", group, "formation lanes", keyPath.appending(path: \.formationLaneCount), 1, 1, nil))
        specs.append(optionalDouble("\(phasePrefix).arrowRushSpawnInterval", group, "arrow interval", keyPath.appending(path: \.arrowRushSpawnInterval), 0.5, 0.1, nil, 2))
        specs.append(cgFloat("\(phasePrefix).arrowRushSpeed", group, "arrow speed", keyPath.appending(path: \.arrowRushSpeed), 2, 0, nil, 1))
        specs.append(int("\(phasePrefix).arrowRushEnemyCount", group, "arrow count", keyPath.appending(path: \.arrowRushEnemyCount), 1, 0, nil))
        specs.append(optionalDouble("\(phasePrefix).mineDotSpawnInterval", group, "mine interval", keyPath.appending(path: \.mineDotSpawnInterval), 0.5, 0.1, nil, 2))
        specs.append(int("\(phasePrefix).maxActiveMineDots", group, "max mines", keyPath.appending(path: \.maxActiveMineDots), 1, 0, nil))
        specs.append(optionalDouble("\(phasePrefix).hunterDotSpawnInterval", group, "hunter interval", keyPath.appending(path: \.hunterDotSpawnInterval), 0.5, 0.1, nil, 2))
        specs.append(cgFloat("\(phasePrefix).hunterDotSpeed", group, "hunter speed", keyPath.appending(path: \.hunterDotSpeed), 2, 0, nil, 1))
        specs.append(cgFloat("\(phasePrefix).hunterDotPredictionLead", group, "hunter lead", keyPath.appending(path: \.hunterDotPredictionLead), 0.05, 0, nil, 2))
        specs.append(int("\(phasePrefix).maxActiveHunterDots", group, "max hunters", keyPath.appending(path: \.maxActiveHunterDots), 1, 0, nil))
        specs.append(optionalDouble("\(phasePrefix).paddleTrapSpawnInterval", group, "paddle interval", keyPath.appending(path: \.paddleTrapSpawnInterval), 0.5, 0.1, nil, 2))
        specs.append(int("\(phasePrefix).maxActivePaddleTraps", group, "max paddles", keyPath.appending(path: \.maxActivePaddleTraps), 1, 0, nil))
        specs.append(double("\(phasePrefix).paddleTrapLifetime", group, "paddle lifetime", keyPath.appending(path: \.paddleTrapLifetime), 0.5, 0, nil, 2))
        specs.append(int("\(phasePrefix).paddleTrapBarEnemyCount", group, "paddle bar count", keyPath.appending(path: \.paddleTrapBarEnemyCount), 1, 0, nil))
        specs.append(cgFloat("\(phasePrefix).paddleTrapDotSpeed", group, "paddle dot speed", keyPath.appending(path: \.paddleTrapDotSpeed), 2, 0, nil, 1))
    }

    private static func appendPickupParameters(
        modeTitle: String,
        sourcePrefix: String,
        keyPath: WritableKeyPath<GameTuningConfiguration, PickupSpawnConfiguration>,
        to specs: inout [GameTuningParameterSpec]
    ) {
        let group = "\(modeTitle) Pickups"
        specs.append(double("\(sourcePrefix).refillDelay", group, "refill delay", keyPath.appending(path: \.refillDelay), 0.05, 0, nil, 2))
        specs.append(int("\(sourcePrefix).maxActivePickups", group, "max active pickups", keyPath.appending(path: \.maxActivePickups), 1, 0, nil))
        specs.append(cgFloat("\(sourcePrefix).pickupRadius", group, "pickup radius", keyPath.appending(path: \.pickupRadius), 1, 1, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).edgeInset", group, "edge inset", keyPath.appending(path: \.edgeInset), 2, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).playerClearance", group, "player clearance", keyPath.appending(path: \.playerClearance), 2, 0, nil, 1))
        specs.append(cgFloat("\(sourcePrefix).enemyClearance", group, "enemy clearance", keyPath.appending(path: \.enemyClearance), 1, 0, nil, 1))
    }

    private static func appendStartingWeaponParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(cgFloat("startingWeapons.shockwaveRadius", "Weapons", "shockwave radius", \.startingWeapons.shockwaveRadius, 4, 0, nil, 1))
        specs.append(int("startingWeapons.seekerTargetLimit", "Weapons", "seeker target limit", \.startingWeapons.seekerTargetLimit, 1, 0, nil))
        specs.append(cgFloat("startingWeapons.razorShieldRadius", "Weapons", "shield radius", \.startingWeapons.razorShieldRadius, 2, 0, nil, 1))
        specs.append(double("startingWeapons.razorShieldDuration", "Weapons", "shield duration", \.startingWeapons.razorShieldDuration, 0.25, 0, nil, 2))
        specs.append(cgFloat("startingWeapons.freezeBurstRadius", "Weapons", "freeze radius", \.startingWeapons.freezeBurstRadius, 4, 0, nil, 1))
        specs.append(double("startingWeapons.freezeDuration", "Weapons", "freeze duration", \.startingWeapons.freezeDuration, 0.25, 0, nil, 2))
        specs.append(double("startingWeapons.frozenCrasherDuration", "Weapons", "frozen crasher", \.startingWeapons.frozenCrasherDuration, 0.1, 0, nil, 2))
        specs.append(cgFloat("startingWeapons.gravityWellRadius", "Weapons", "gravity radius", \.startingWeapons.gravityWellRadius, 4, 0, nil, 1))
        specs.append(double("startingWeapons.gravityWellPullDuration", "Weapons", "gravity pull duration", \.startingWeapons.gravityWellPullDuration, 0.05, 0.05, nil, 2))
        specs.append(cgFloat("startingWeapons.gravityWellClearRadius", "Weapons", "gravity clear radius", \.startingWeapons.gravityWellClearRadius, 2, 0, nil, 1))
        specs.append(cgFloat("startingWeapons.chainLightningInitialRange", "Weapons", "chain initial range", \.startingWeapons.chainLightningInitialRange, 4, 0, nil, 1))
        specs.append(cgFloat("startingWeapons.chainLightningJumpRange", "Weapons", "chain jump range", \.startingWeapons.chainLightningJumpRange, 4, 0, nil, 1))
        specs.append(int("startingWeapons.chainLightningTargetLimit", "Weapons", "chain target limit", \.startingWeapons.chainLightningTargetLimit, 1, 0, nil))
        specs.append(cgFloat(
            "startingWeapons.warpDashDistanceFractionOfShortSide",
            "Weapons",
            "warp distance fraction",
            \.startingWeapons.warpDashDistanceFractionOfShortSide,
            0.05,
            0,
            1,
            2
        ))
        specs.append(double(
            "startingWeapons.warpDashInvulnerabilityDuration",
            "Weapons",
            "warp invuln duration",
            \.startingWeapons.warpDashInvulnerabilityDuration,
            0.05,
            0,
            nil,
            2
        ))
    }

    private static func appendWeaponEffectParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(cgFloat("weaponEffectTiming.projectileSpeed", "Effects", "projectile speed", \.weaponEffectTiming.projectileSpeed, 20, 1, nil, 1))
        specs.append(cgFloat("weaponEffectTiming.waveSpeed", "Effects", "wave speed", \.weaponEffectTiming.waveSpeed, 20, 1, nil, 1))
        specs.append(double("weaponEffectTiming.minimumTravelDuration", "Effects", "min travel duration", \.weaponEffectTiming.minimumTravelDuration, 0.01, 0, nil, 2))
        specs.append(double(
            "weaponEffectTiming.maximumProjectileTravelDuration",
            "Effects",
            "max projectile duration",
            \.weaponEffectTiming.maximumProjectileTravelDuration,
            0.05,
            0.01,
            nil,
            2
        ))
        specs.append(double("weaponEffectTiming.maximumWaveTravelDuration", "Effects", "max wave duration", \.weaponEffectTiming.maximumWaveTravelDuration, 0.05, 0.01, nil, 2))
    }

    private static func appendFlameTrailParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(double("flameTrail.duration", "Flame Trail", "duration", \.flameTrail.duration, 0.25, 0, nil, 2))
        specs.append(double("flameTrail.segmentLifetime", "Flame Trail", "segment lifetime", \.flameTrail.segmentLifetime, 0.1, 0, nil, 2))
        specs.append(cgFloat("flameTrail.segmentRadius", "Flame Trail", "segment radius", \.flameTrail.segmentRadius, 1, 0, nil, 1))
        specs.append(cgFloat("flameTrail.segmentSpacing", "Flame Trail", "segment spacing", \.flameTrail.segmentSpacing, 1, 0, nil, 1))
        specs.append(int("flameTrail.maxSegments", "Flame Trail", "max segments", \.flameTrail.maxSegments, 1, 0, nil))
        specs.append(double("flameTrail.frozenMeltDelay", "Flame Trail", "frozen melt delay", \.flameTrail.frozenMeltDelay, 0.05, 0, nil, 2))
    }

    private static func appendDecoyBeaconParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(double("decoyBeacon.duration", "Decoy", "duration", \.decoyBeacon.duration, 0.25, 0, nil, 2))
        specs.append(cgFloat("decoyBeacon.attractionRadius", "Decoy", "attraction radius", \.decoyBeacon.attractionRadius, 4, 0, nil, 1))
        specs.append(cgFloat("decoyBeacon.explosionRadius", "Decoy", "explosion radius", \.decoyBeacon.explosionRadius, 2, 0, nil, 1))
    }

    private static func appendFeedbackParameters(to specs: inout [GameTuningParameterSpec]) {
        specs.append(double("feedback.deathReplayDuration", "Feedback", "death replay duration", \.feedback.deathReplayDuration, 0.25, 0, nil, 2))
        specs.append(cgFloat("feedback.deathShakeAmplitude", "Feedback", "death shake amplitude", \.feedback.deathShakeAmplitude, 0.5, 0, nil, 1))
        specs.append(double("feedback.deathShakeDuration", "Feedback", "death shake duration", \.feedback.deathShakeDuration, 0.01, 0, nil, 2))
        specs.append(int("feedback.multiKillShakeThreshold", "Feedback", "multi kill threshold", \.feedback.multiKillShakeThreshold, 1, 1, nil))
        specs.append(cgFloat("feedback.multiKillShakeAmplitude", "Feedback", "multi kill amplitude", \.feedback.multiKillShakeAmplitude, 0.5, 0, nil, 1))
        specs.append(double("feedback.multiKillShakeDuration", "Feedback", "multi kill duration", \.feedback.multiKillShakeDuration, 0.01, 0, nil, 2))
        specs.append(double("feedback.razorShieldWarningLeadTime", "Feedback", "shield warning lead", \.feedback.razorShieldWarningLeadTime, 0.05, 0, nil, 2))
    }

    private static func cgFloat(
        _ sourcePath: String,
        _ group: String,
        _ title: String,
        _ keyPath: WritableKeyPath<GameTuningConfiguration, CGFloat>,
        _ step: CGFloat,
        _ min: CGFloat,
        _ max: CGFloat?,
        _ decimals: Int
    ) -> GameTuningParameterSpec {
        GameTuningParameterSpec(
            id: sourcePath,
            group: group,
            title: title,
            sourcePath: sourcePath,
            value: .cgFloat(keyPath, step: step, min: min, max: max, decimals: decimals)
        )
    }

    private static func double(
        _ sourcePath: String,
        _ group: String,
        _ title: String,
        _ keyPath: WritableKeyPath<GameTuningConfiguration, Double>,
        _ step: Double,
        _ min: Double,
        _ max: Double?,
        _ decimals: Int
    ) -> GameTuningParameterSpec {
        GameTuningParameterSpec(
            id: sourcePath,
            group: group,
            title: title,
            sourcePath: sourcePath,
            value: .double(keyPath, step: step, min: min, max: max, decimals: decimals)
        )
    }

    private static func optionalDouble(
        _ sourcePath: String,
        _ group: String,
        _ title: String,
        _ keyPath: WritableKeyPath<GameTuningConfiguration, Double?>,
        _ step: Double,
        _ min: Double,
        _ max: Double?,
        _ decimals: Int
    ) -> GameTuningParameterSpec {
        GameTuningParameterSpec(
            id: sourcePath,
            group: group,
            title: title,
            sourcePath: sourcePath,
            value: .optionalDouble(keyPath, step: step, min: min, max: max, decimals: decimals)
        )
    }

    private static func int(
        _ sourcePath: String,
        _ group: String,
        _ title: String,
        _ keyPath: WritableKeyPath<GameTuningConfiguration, Int>,
        _ step: Int,
        _ min: Int,
        _ max: Int?
    ) -> GameTuningParameterSpec {
        GameTuningParameterSpec(
            id: sourcePath,
            group: group,
            title: title,
            sourcePath: sourcePath,
            value: .int(keyPath, step: step, min: min, max: max)
        )
    }
}

// swiftlint:enable line_length function_parameter_count
