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
    var survivalBonusInterval: TimeInterval = 10
    var survivalBonusBaseScore = 10
    var survivalBonusScorePerEnemyDestroyed = 1

    var playerHitRadius: CGFloat {
        playerVisualRadius * playerHitRadiusScale
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

    private enum CodingKeys: String, CodingKey {
        case score
        case survivalTime
        case maxCombo
        case enemiesDestroyed
        case bestWeapon
        case timestamp
        case mode
    }

    init(
        score: Int,
        survivalTime: TimeInterval,
        maxCombo: Int,
        enemiesDestroyed: Int,
        bestWeapon: WeaponKind?,
        timestamp: Date,
        mode: ArenaModeKind = .classic
    ) {
        self.score = score
        self.survivalTime = survivalTime
        self.maxCombo = maxCombo
        self.enemiesDestroyed = enemiesDestroyed
        self.bestWeapon = bestWeapon
        self.timestamp = timestamp
        self.mode = mode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Int.self, forKey: .score)
        survivalTime = try container.decode(TimeInterval.self, forKey: .survivalTime)
        maxCombo = try container.decode(Int.self, forKey: .maxCombo)
        enemiesDestroyed = try container.decode(Int.self, forKey: .enemiesDestroyed)
        bestWeapon = try container.decodeIfPresent(WeaponKind.self, forKey: .bestWeapon)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        mode = try container.decodeIfPresent(ArenaModeKind.self, forKey: .mode) ?? .classic
    }
}

struct ClassicRunController {
    var configuration = ClassicRunConfiguration()
    private(set) var phase: ClassicRunPhase = .preRun
    private(set) var survivalTime: TimeInterval = 0
    private(set) var enemiesDestroyed = 0
    private(set) var score = 0
    private(set) var currentCombo = 0
    private(set) var maxCombo = 0
    private(set) var comboTimeRemaining: TimeInterval = 0
    private(set) var bestWeapon: WeaponKind?
    private(set) var finalizedSummary: RunSummary?
    private var creditedSurvivalBonusIntervals = 0
    private var creditedItemPickupIDs: Set<Int> = []
    private var weaponKillCounts: [WeaponKind: Int] = [:]

    init(configuration: ClassicRunConfiguration = ClassicRunConfiguration()) {
        self.configuration = configuration
    }

    mutating func start() {
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

    mutating func endRun(at timestamp: Date = Date(), mode: ArenaModeKind = .classic) {
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
            mode: mode
        )
    }

    mutating func restart() {
        resetForActiveRun()
    }

    mutating func update(deltaTime: TimeInterval) {
        guard phase == .active else {
            return
        }

        let clampedDelta = max(0, deltaTime)
        survivalTime += clampedDelta
        updateComboTimer(deltaTime: clampedDelta)
        applySurvivalBonusIfNeeded()
    }

    mutating func recordEnemyKills(count: Int, weaponKind: WeaponKind?) {
        guard phase == .active else {
            return
        }

        let killCount = max(0, count)
        guard killCount > 0 else {
            return
        }

        for _ in 0..<killCount {
            recordKill(scoreValue: configuration.baseEnemyScore, weaponKind: weaponKind)
        }
    }

    @discardableResult
    mutating func recordItemPickup(pickupID: Int) -> Bool {
        guard phase == .active, !creditedItemPickupIDs.contains(pickupID) else {
            return false
        }

        creditedItemPickupIDs.insert(pickupID)
        score += max(0, configuration.itemPickupScore)
        return true
    }

    var comboMultiplier: Int {
        guard currentCombo > 0 else {
            return 1
        }

        return multiplier(forComboCount: currentCombo)
    }

    private mutating func resetForActiveRun() {
        phase = .active
        survivalTime = 0
        enemiesDestroyed = 0
        score = 0
        currentCombo = 0
        maxCombo = 0
        comboTimeRemaining = 0
        bestWeapon = nil
        finalizedSummary = nil
        creditedSurvivalBonusIntervals = 0
        creditedItemPickupIDs.removeAll()
        weaponKillCounts.removeAll()
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
        let eligibleIntervals = Int(elapsedBonusTime / configuration.survivalBonusInterval)
        guard eligibleIntervals > creditedSurvivalBonusIntervals else {
            return
        }

        let newIntervals = eligibleIntervals - creditedSurvivalBonusIntervals
        let intervalScore = max(0, configuration.survivalBonusBaseScore)
            + enemiesDestroyed * max(0, configuration.survivalBonusScorePerEnemyDestroyed)
        score += newIntervals * intervalScore
        creditedSurvivalBonusIntervals = eligibleIntervals
    }

    private mutating func recordKill(scoreValue: Int, weaponKind: WeaponKind?) {
        let nextCombo = currentCombo + 1
        score += max(0, scoreValue) * multiplier(forComboCount: nextCombo)
        currentCombo = nextCombo
        maxCombo = max(maxCombo, currentCombo)
        comboTimeRemaining = configuration.comboWindow
        enemiesDestroyed += 1
        recordWeaponKills(1, weaponKind: weaponKind)
    }

    private mutating func recordWeaponKills(_ killCount: Int, weaponKind: WeaponKind?) {
        guard let weaponKind else {
            return
        }

        let updatedCount = weaponKillCounts[weaponKind, default: 0] + killCount
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
        return 1 + max(0, comboCount) / step
    }
}
