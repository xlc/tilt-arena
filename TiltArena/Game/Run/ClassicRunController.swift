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

    var playerHitRadius: CGFloat {
        playerVisualRadius * playerHitRadiusScale
    }
}

struct ClassicRunController {
    var configuration = ClassicRunConfiguration()
    private(set) var phase: ClassicRunPhase = .preRun
    private(set) var survivalTime: TimeInterval = 0
    private var timeUntilNextSpawn: TimeInterval = 0

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

    mutating func endRun() {
        guard phase == .active || phase == .paused else {
            return
        }

        phase = .gameOver
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
        timeUntilNextSpawn -= clampedDelta

        guard activeEnemyCount < configuration.maxActiveChasers else {
            return 0
        }

        guard configuration.spawnInterval > 0 else {
            return 0
        }

        var spawnCount = 0
        var projectedEnemyCount = activeEnemyCount

        while timeUntilNextSpawn <= 0, projectedEnemyCount < configuration.maxActiveChasers {
            spawnCount += 1
            projectedEnemyCount += 1
            timeUntilNextSpawn += configuration.spawnInterval
        }

        return spawnCount
    }

    private mutating func resetForActiveRun() {
        phase = .active
        survivalTime = 0
        timeUntilNextSpawn = 0
    }
}
