import CoreGraphics
import Foundation

enum ClassicRunPhase: Equatable {
    case preRun
    case active
    case paused
    case gameOver
}

struct ClassicRunConfiguration: Equatable {
    var playerVisualRadius: CGFloat = 14
    var playerHitRadiusScale: CGFloat = 0.65
    var enemyRadius: CGFloat = 8
    var chaserSpeed: CGFloat = 55
    var spawnInterval: TimeInterval = 1.4
    var maxActiveChasers: Int = 40
    var playerSafetyRadius: CGFloat = 120
    var baseEnemyScore = 10
    var eliteEnemyScore = 25
    var formationBonusScore = 100
    var nearMissScore = 5
    var dangerGrabScore = 25
    var comboWindow: TimeInterval = 1.2
    var killsPerMultiplierStep = 10
    var survivalBonusStartTime: TimeInterval = 60
    var survivalBonusInterval: TimeInterval = 10
    var survivalBonusPointsPerInterval = 10
    var nearMissEdgeGap: CGFloat = 18
    var dangerGrabEnemyDistance: CGFloat = 80

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
}

struct ClassicRunController {
    private static let spawnTimerEpsilon: TimeInterval = 0.000_001

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
    private var timeUntilNextSpawn: TimeInterval = 0
    private var creditedSurvivalBonusIntervals = 0
    private var creditedNearMissEnemyIDs: Set<Int> = []
    private var creditedDangerGrabPickupIDs: Set<Int> = []
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
            timestamp: timestamp
        )
    }

    mutating func restart() {
        resetForActiveRun()
    }

    mutating func update(deltaTime: TimeInterval, activeEnemyCount: Int) -> Int {
        guard phase == .active else {
            return 0
        }

        let clampedDelta = max(0, deltaTime)
        survivalTime += clampedDelta
        updateComboTimer(deltaTime: clampedDelta)
        applySurvivalBonusIfNeeded()

        guard configuration.spawnInterval > 0 else {
            timeUntilNextSpawn = 0
            return 0
        }

        timeUntilNextSpawn -= clampedDelta

        guard activeEnemyCount < configuration.maxActiveChasers else {
            timeUntilNextSpawn = max(timeUntilNextSpawn, configuration.spawnInterval)
            return 0
        }

        var spawnCount = 0
        var projectedEnemyCount = activeEnemyCount

        while timeUntilNextSpawn <= Self.spawnTimerEpsilon, projectedEnemyCount < configuration.maxActiveChasers {
            spawnCount += 1
            projectedEnemyCount += 1
            timeUntilNextSpawn += configuration.spawnInterval
        }

        return spawnCount
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

    mutating func recordEliteKill(weaponKind: WeaponKind?) {
        guard phase == .active else {
            return
        }

        recordKill(scoreValue: configuration.eliteEnemyScore, weaponKind: weaponKind)
    }

    mutating func recordFormationBonus(_ bonus: Int? = nil) {
        guard phase == .active else {
            return
        }

        score += max(0, bonus ?? configuration.formationBonusScore)
    }

    @discardableResult
    mutating func recordNearMiss(enemyID: Int) -> Bool {
        guard phase == .active, !creditedNearMissEnemyIDs.contains(enemyID) else {
            return false
        }

        creditedNearMissEnemyIDs.insert(enemyID)
        score += max(0, configuration.nearMissScore)
        return true
    }

    @discardableResult
    mutating func recordDangerGrab(pickupID: Int) -> Bool {
        guard phase == .active, !creditedDangerGrabPickupIDs.contains(pickupID) else {
            return false
        }

        creditedDangerGrabPickupIDs.insert(pickupID)
        score += max(0, configuration.dangerGrabScore)
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
        timeUntilNextSpawn = 0
        creditedSurvivalBonusIntervals = 0
        creditedNearMissEnemyIDs.removeAll()
        creditedDangerGrabPickupIDs.removeAll()
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
        score += newIntervals * max(0, configuration.survivalBonusPointsPerInterval)
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
