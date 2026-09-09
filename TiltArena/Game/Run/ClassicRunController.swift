import CoreGraphics
import Foundation

enum ClassicRunPhase: Equatable {
    case preRun
    case active
    case paused
    case gameOver
}

struct ClassicRunConfiguration: Equatable {
    var playerVisualRadius: CGFloat = 12
    var playerHitRadiusScale: CGFloat = 0.40
    var baseEnemyScore = 10
    var itemPickupScore = 50
    var comboWindow: TimeInterval = 1.2
    var killsPerMultiplierStep = 10
    var survivalBonusStartTime: TimeInterval = 60
    var survivalBonusInterval: TimeInterval = 1
    var survivalBonusEnemySqrtDivisor: Double = 10
    var weaponComboWindow: TimeInterval = 6
    var weaponComboMinimumKillCount = 2

    var playerHitRadius: CGFloat {
        playerVisualRadius * playerHitRadiusScale
    }
}

struct ArenaRunContext: Codable, Equatable {
    static let currentRulesVersion = 1

    let mode: ArenaModeKind
    let sequenceSeed: Int
    let startedAt: Date
    let rulesVersion: Int

    init(mode: ArenaModeKind = .classic, sequenceSeed: Int = 0, startedAt: Date = Date()) {
        self.mode = mode
        self.sequenceSeed = sequenceSeed
        self.startedAt = startedAt
        rulesVersion = Self.currentRulesVersion
    }
}

struct RunSummary: Codable, Equatable {
    let score: Int
    let survivalTime: TimeInterval
    let maxCombo: Int
    let enemiesDestroyed: Int
    let bestWeapon: WeaponKind?
    let timestamp: Date
    let mode: ArenaModeKind

    let sequenceSeed: Int
    let startedAt: Date
    let rulesVersion: Int

    init(
        score: Int,
        survivalTime: TimeInterval,
        maxCombo: Int,
        enemiesDestroyed: Int,
        bestWeapon: WeaponKind?,
        timestamp: Date,
        mode: ArenaModeKind = .classic,
        sequenceSeed: Int = 0,
        startedAt: Date? = nil,
        rulesVersion: Int = ArenaRunContext.currentRulesVersion
    ) {
        self.score = score
        self.survivalTime = survivalTime
        self.maxCombo = maxCombo
        self.enemiesDestroyed = enemiesDestroyed
        self.bestWeapon = bestWeapon
        self.timestamp = timestamp
        self.mode = mode
        self.sequenceSeed = sequenceSeed
        self.startedAt = startedAt ?? timestamp.addingTimeInterval(-max(0, survivalTime))
        self.rulesVersion = rulesVersion
    }
}

struct ClassicRunController {
    var configuration = ClassicRunConfiguration()
    private(set) var phase: ClassicRunPhase = .preRun
    private(set) var context = ArenaRunContext()
    private(set) var survivalTime: TimeInterval = 0
    private(set) var enemiesDestroyed = 0
    private(set) var score = 0
    private(set) var scoreBreakdown = RunScoreBreakdown()
    private(set) var currentCombo = 0
    private(set) var maxCombo = 0
    private(set) var comboTimeRemaining: TimeInterval = 0
    private(set) var bestWeapon: WeaponKind?
    private(set) var finalizedSummary: RunSummary?
    private var creditedSurvivalBonusIntervals = 0
    private var survivalBonusRemainder: Double = 0
    private var creditedItemPickupIDs: Set<Int> = []
    private var weaponKillCounts: [WeaponKind: Int] = [:]
    private var weaponComboState = WeaponComboState()

    init(configuration: ClassicRunConfiguration = ClassicRunConfiguration()) {
        self.configuration = configuration
    }

    mutating func start(context: ArenaRunContext = ArenaRunContext()) {
        self.context = context
        resetForActiveRun()
    }

    mutating func pause() {
        guard phase == .active else {
            return
        }

        phase = .paused
    }

    mutating func resume() {
        guard phase == .paused else {
            return
        }

        phase = .active
    }

    mutating func endRun(at timestamp: Date = Date()) {
        guard phase == .active || phase == .paused else {
            return
        }

        phase = .gameOver
        finalizedSummary = RunSummary(
            score: score,
            survivalTime: survivalTime,
            maxCombo: maxCombo,
            enemiesDestroyed: enemiesDestroyed,
            bestWeapon: bestWeapon,
            timestamp: timestamp,
            mode: context.mode,
            sequenceSeed: context.sequenceSeed,
            startedAt: context.startedAt,
            rulesVersion: context.rulesVersion
        )
    }

    mutating func restart(context: ArenaRunContext = ArenaRunContext()) {
        start(context: context)
    }

    mutating func update(deltaTime: TimeInterval) {
        guard phase == .active, deltaTime.isFinite else {
            return
        }

        let clampedDelta = max(0, deltaTime)
        survivalTime = RunProfile.normalizedPersistedSurvivalTime(
            survivalTime + clampedDelta
        )
        updateComboTimer(deltaTime: clampedDelta)
        weaponComboState.update(deltaTime: clampedDelta)
        applySurvivalBonusIfNeeded()
    }

    @discardableResult
    mutating func recordEnemyKills(
        count: Int,
        weaponKind: WeaponKind?,
        activation: WeaponActivation? = nil
    ) -> WeaponComboEvent? {
        guard phase == .active else {
            return nil
        }

        let killCount = max(0, count)
        guard killCount > 0 else {
            return nil
        }

        for _ in 0..<killCount {
            recordKill(scoreValue: configuration.baseEnemyScore, weaponKind: weaponKind)
        }

        if let activation {
            guard activation.recordKills(killCount, minimum: configuration.weaponComboMinimumKillCount) else { return nil }
            return recordWeaponCombo(killCount: activation.killCount, weaponKind: activation.kind)
        }
        return recordWeaponCombo(killCount: killCount, weaponKind: weaponKind)
    }

    @discardableResult
    mutating func recordItemPickup(pickupID: Int) -> Bool {
        guard phase == .active, !creditedItemPickupIDs.contains(pickupID) else {
            return false
        }

        creditedItemPickupIDs.insert(pickupID)
        awardScore(max(0, configuration.itemPickupScore), category: \.pickups)
        return true
    }

    var comboMultiplier: Int {
        guard currentCombo > 0 else {
            return 1
        }

        return multiplier(forComboCount: currentCombo)
    }

    var weaponComboPrimer: WeaponComboPrimer? {
        weaponComboState.activePrimer
    }

    private mutating func resetForActiveRun() {
        phase = .active
        survivalTime = 0
        enemiesDestroyed = 0
        score = 0
        scoreBreakdown = RunScoreBreakdown()
        currentCombo = 0
        maxCombo = 0
        comboTimeRemaining = 0
        bestWeapon = nil
        finalizedSummary = nil
        creditedSurvivalBonusIntervals = 0
        survivalBonusRemainder = 0
        creditedItemPickupIDs.removeAll()
        weaponKillCounts.removeAll()
        weaponComboState.reset()
    }

    private mutating func updateComboTimer(deltaTime: TimeInterval) {
        guard currentCombo > 0 else {
            comboTimeRemaining = 0
            return
        }

        comboTimeRemaining = max(0, comboTimeRemaining - deltaTime)

        if comboTimeRemaining == 0 {
            currentCombo = 0
        }
    }

    private mutating func applySurvivalBonusIfNeeded() {
        guard configuration.survivalBonusInterval > 0 else {
            return
        }

        guard survivalTime >= configuration.survivalBonusStartTime else {
            return
        }

        let elapsedBonusTime = survivalTime - configuration.survivalBonusStartTime
        let eligibleIntervalQuotient = elapsedBonusTime / configuration.survivalBonusInterval
        guard
            eligibleIntervalQuotient.isFinite,
            eligibleIntervalQuotient >= 0,
            eligibleIntervalQuotient < Double(Int.max)
        else {
            return
        }
        let eligibleIntervals = Int(eligibleIntervalQuotient)
        guard eligibleIntervals > creditedSurvivalBonusIntervals else {
            return
        }

        let newIntervals = eligibleIntervals - creditedSurvivalBonusIntervals
        let bonusIncrement = Double(newIntervals) * survivalBonusScorePerInterval()
        let updatedRemainder = survivalBonusRemainder + bonusIncrement
        guard updatedRemainder.isFinite, updatedRemainder < Double(Int.max) else {
            awardScore(Int.max, category: \.survival)
            survivalBonusRemainder = 0
            creditedSurvivalBonusIntervals = eligibleIntervals
            return
        }

        survivalBonusRemainder = max(0, updatedRemainder)
        let wholePoints = Int(survivalBonusRemainder)
        if wholePoints > 0 {
            awardScore(wholePoints, category: \.survival)
            survivalBonusRemainder -= Double(wholePoints)
        }
        creditedSurvivalBonusIntervals = eligibleIntervals
    }

    private func survivalBonusScorePerInterval() -> Double {
        let divisor = max(0.1, configuration.survivalBonusEnemySqrtDivisor)
        return 1 + sqrt(Double(max(0, enemiesDestroyed))) / divisor
    }

    private mutating func recordKill(scoreValue: Int, weaponKind: WeaponKind?) {
        let nextCombo = saturatedSum(currentCombo, 1)
        let (scoreIncrement, multiplicationOverflow) = max(0, scoreValue)
            .multipliedReportingOverflow(by: multiplier(forComboCount: nextCombo))
        awardScore(multiplicationOverflow ? Int.max : scoreIncrement, category: \.kills)
        currentCombo = nextCombo
        maxCombo = max(maxCombo, currentCombo)
        comboTimeRemaining = configuration.comboWindow
        enemiesDestroyed = saturatedSum(enemiesDestroyed, 1)
        recordWeaponKills(1, weaponKind: weaponKind)
    }

    private mutating func recordWeaponCombo(killCount: Int, weaponKind: WeaponKind?) -> WeaponComboEvent? {
        guard let weaponKind else {
            return nil
        }

        return weaponComboState.recordWeaponClear(
            kind: weaponKind,
            killCount: killCount,
            configuration: configuration
        )
    }

    private mutating func recordWeaponKills(_ killCount: Int, weaponKind: WeaponKind?) {
        guard let weaponKind else {
            return
        }

        let updatedCount = saturatedSum(weaponKillCounts[weaponKind, default: 0], killCount)
        weaponKillCounts[weaponKind] = updatedCount

        guard let currentBestWeapon = bestWeapon else {
            bestWeapon = weaponKind
            return
        }

        if updatedCount > weaponKillCounts[currentBestWeapon, default: 0] {
            bestWeapon = weaponKind
        }
    }

    private func multiplier(forComboCount comboCount: Int) -> Int {
        let step = max(1, configuration.killsPerMultiplierStep)
        return saturatedSum(1, max(0, comboCount) / step)
    }

    private func saturatedSum(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }

    private mutating func awardScore(_ increment: Int, category: WritableKeyPath<RunScoreBreakdown, Int>) {
        let previousScore = score
        score = saturatedSum(score, max(0, increment))
        // Credit only points actually awarded, including the final partial award at saturation.
        scoreBreakdown[keyPath: category] += score - previousScore
    }
}

struct RunScoreBreakdown: Equatable {
    var kills = 0
    var pickups = 0
    var survival = 0

    var total: Int { kills + pickups + survival }
}
