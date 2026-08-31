import CoreGraphics
import Foundation

enum EnemyDifficultyPhase: Equatable {
    case warmup
    case pressure
    case chaos
    case survivalHell

    static func phase(at survivalTime: TimeInterval) -> EnemyDifficultyPhase {
        let time = survivalTime.isFinite ? max(0, survivalTime) : 0

        if time < Self.pressure.startTime {
            return .warmup
        } else if time < Self.chaos.startTime {
            return .pressure
        } else if time < Self.survivalHell.startTime {
            return .chaos
        } else {
            return .survivalHell
        }
    }

    var startTime: TimeInterval {
        switch self {
        case .warmup:
            return 0
        case .pressure:
            return 30
        case .chaos:
            return 90
        case .survivalHell:
            return 180
        }
    }
}

enum EnemySpawnSafetyLimits {
    // These are fail-safe ceilings for corrupted/developer tuning. Defaults remain
    // well below them, while a single frame can never allocate an unbounded pattern.
    static let maximumActiveEnemyCount = 512
    static let maximumFormationLaneCount = 64
    static let maximumArrowRushEnemyCount = 64
    static let maximumPaddleBarEnemyCount = 32
    static let maximumPatternEnemyCount = 64
    static let maximumPendingTelegraphCount = 16
    static let maximumTelegraphDuration: TimeInterval = 10
    static let maximumStatusDuration: TimeInterval = 60
    static let maximumSpeed: CGFloat = 10_000

    static func statusDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else {
            return 0
        }

        return min(maximumStatusDuration, max(0, duration))
    }

    static func telegraphDuration(_ duration: TimeInterval) -> TimeInterval {
        min(maximumTelegraphDuration, statusDuration(duration))
    }
}

struct EnemyPhaseTuning: Equatable {
    var chaserSpawnInterval: TimeInterval
    var chaserSpeed: CGFloat
    var maxActiveEnemies: Int
    var formationSpawnInterval: TimeInterval?
    var formationSpeed: CGFloat
    var formationLaneCount: Int
    var arrowRushSpawnInterval: TimeInterval?
    var arrowRushSpeed: CGFloat = 0
    var arrowRushEnemyCount: Int = 0
    var mineDotSpawnInterval: TimeInterval?
    var maxActiveMineDots: Int = 0
    var hunterDotSpawnInterval: TimeInterval?
    var hunterDotSpeed: CGFloat = 0
    // Seconds of player velocity projected ahead when choosing a pursuit target.
    var hunterDotPredictionLead: CGFloat = 0
    var maxActiveHunterDots: Int = 0
    var paddleTrapSpawnInterval: TimeInterval?
    var maxActivePaddleTraps: Int = 0
    var paddleTrapLifetime: TimeInterval = 0
    var paddleTrapBarEnemyCount: Int = 0
    var paddleTrapDotSpeed: CGFloat = 0
    var splitterSpawnInterval: TimeInterval?
    var splitterSpeed: CGFloat = 0
    var maxActiveSplitters: Int = 0
}

extension EnemyPhaseTuning {
    func interpolated(toward next: EnemyPhaseTuning?, progress: CGFloat) -> EnemyPhaseTuning {
        let progress = progress.isFinite ? min(1, max(0, progress)) : 0
        var tuning = self
        tuning.interpolateChaserAndLinearPatterns(toward: next, progress: progress)
        tuning.interpolatePlacedAndPursuitPatterns(toward: next, progress: progress)
        tuning.interpolatePaddleAndSplitterPatterns(toward: next, progress: progress)
        return tuning
    }

    private mutating func interpolateChaserAndLinearPatterns(
        toward next: EnemyPhaseTuning?,
        progress: CGFloat
    ) {
        chaserSpawnInterval = interpolate(chaserSpawnInterval, next?.chaserSpawnInterval, progress)
        chaserSpeed = interpolateSpeed(chaserSpeed, next?.chaserSpeed, progress)
        maxActiveEnemies = interpolateCount(
            maxActiveEnemies,
            next?.maxActiveEnemies,
            progress,
            maximum: EnemySpawnSafetyLimits.maximumActiveEnemyCount
        )
        formationSpawnInterval = interpolateOptional(formationSpawnInterval, next?.formationSpawnInterval, progress)
        formationSpeed = interpolateSpeed(formationSpeed, next?.formationSpeed, progress)
        formationLaneCount = max(
            3,
            interpolateCount(
                formationLaneCount,
                next?.formationLaneCount,
                progress,
                maximum: EnemySpawnSafetyLimits.maximumFormationLaneCount
            )
        )
        arrowRushSpawnInterval = interpolateOptional(arrowRushSpawnInterval, next?.arrowRushSpawnInterval, progress)
        arrowRushSpeed = interpolateSpeed(arrowRushSpeed, next?.arrowRushSpeed, progress)
        arrowRushEnemyCount = interpolateCount(
            arrowRushEnemyCount,
            next?.arrowRushEnemyCount,
            progress,
            maximum: EnemySpawnSafetyLimits.maximumArrowRushEnemyCount
        )
    }

    private mutating func interpolatePlacedAndPursuitPatterns(
        toward next: EnemyPhaseTuning?,
        progress: CGFloat
    ) {
        mineDotSpawnInterval = interpolateOptional(mineDotSpawnInterval, next?.mineDotSpawnInterval, progress)
        maxActiveMineDots = interpolateCount(maxActiveMineDots, next?.maxActiveMineDots, progress)
        hunterDotSpawnInterval = interpolateOptional(hunterDotSpawnInterval, next?.hunterDotSpawnInterval, progress)
        hunterDotSpeed = interpolateSpeed(hunterDotSpeed, next?.hunterDotSpeed, progress)
        hunterDotPredictionLead = min(
            CGFloat(EnemySpawnSafetyLimits.maximumStatusDuration),
            interpolate(hunterDotPredictionLead, next?.hunterDotPredictionLead, progress)
        )
        maxActiveHunterDots = interpolateCount(maxActiveHunterDots, next?.maxActiveHunterDots, progress)
    }

    private mutating func interpolatePaddleAndSplitterPatterns(
        toward next: EnemyPhaseTuning?,
        progress: CGFloat
    ) {
        paddleTrapSpawnInterval = interpolateOptional(
            paddleTrapSpawnInterval,
            next?.paddleTrapSpawnInterval,
            progress
        )
        maxActivePaddleTraps = interpolateCount(maxActivePaddleTraps, next?.maxActivePaddleTraps, progress)
        paddleTrapLifetime = min(
            EnemySpawnSafetyLimits.maximumStatusDuration,
            interpolate(paddleTrapLifetime, next?.paddleTrapLifetime, progress)
        )
        paddleTrapBarEnemyCount = interpolateCount(
            paddleTrapBarEnemyCount,
            next?.paddleTrapBarEnemyCount,
            progress,
            maximum: EnemySpawnSafetyLimits.maximumPaddleBarEnemyCount
        )
        paddleTrapDotSpeed = interpolateSpeed(paddleTrapDotSpeed, next?.paddleTrapDotSpeed, progress)
        splitterSpawnInterval = interpolateOptional(splitterSpawnInterval, next?.splitterSpawnInterval, progress)
        splitterSpeed = interpolateSpeed(splitterSpeed, next?.splitterSpeed, progress)
        maxActiveSplitters = interpolateCount(maxActiveSplitters, next?.maxActiveSplitters, progress)
    }

    private func interpolate(
        _ start: TimeInterval,
        _ end: TimeInterval?,
        _ progress: CGFloat
    ) -> TimeInterval {
        let start = finiteNonnegative(start)
        let end = finiteNonnegative(end ?? start)
        return start + (end - start) * TimeInterval(progress)
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat?, _ progress: CGFloat) -> CGFloat {
        let start = finiteNonnegative(start)
        let end = finiteNonnegative(end ?? start)
        return start + (end - start) * progress
    }

    private func interpolateOptional(
        _ start: TimeInterval?,
        _ end: TimeInterval?,
        _ progress: CGFloat
    ) -> TimeInterval? {
        guard let start, start.isFinite else {
            return nil
        }

        return interpolate(start, end, progress)
    }

    private func interpolateCount(
        _ start: Int,
        _ end: Int?,
        _ progress: CGFloat,
        maximum: Int = EnemySpawnSafetyLimits.maximumPatternEnemyCount
    ) -> Int {
        let start = min(maximum, max(0, start))
        let end = min(maximum, max(0, end ?? start))
        return min(maximum, max(0, Int(round(interpolate(CGFloat(start), CGFloat(end), progress)))))
    }

    private func interpolateSpeed(_ start: CGFloat, _ end: CGFloat?, _ progress: CGFloat) -> CGFloat {
        min(EnemySpawnSafetyLimits.maximumSpeed, interpolate(start, end, progress))
    }

    private func finiteNonnegative<T: BinaryFloatingPoint>(_ value: T) -> T {
        value.isFinite ? max(0, value) : 0
    }
}

struct EnemySpawnConfiguration: Equatable {
    var enemyRadius: CGFloat = 4
    var enemySurvivalSpeedStartMultiplier: CGFloat = 0.82
    var enemySurvivalSpeedRampDuration: TimeInterval = 120
    var maximumEnemySurvivalSpeedMultiplier: CGFloat = 1.35
    var enemySpeedRampPerSecond: CGFloat = 0.024
    var maximumEnemySpeedMultiplier: CGFloat = 1.9
    // Archetype-specific speed ceilings keep ordinary pursuit threats avoidable while
    // allowing strongly telegraphed, fixed-path threats to briefly outrun the player.
    var chaserPlayerSpeedRatio: CGFloat = 0.78
    var formationPlayerSpeedRatio: CGFloat = 0.95
    var arrowRushPlayerSpeedRatio: CGFloat = 1.2
    var hunterDotPlayerSpeedRatio: CGFloat = 0.9
    var paddleTrapDotPlayerSpeedRatio: CGFloat = 1.05
    var splitterPlayerSpeedRatio: CGFloat = 0.65
    var splitterChildPlayerSpeedRatio: CGFloat = 0.82
    var playerSafetyRadius: CGFloat = 120
    var pickupClearance: CGFloat = 8
    var spawnWarningDuration: TimeInterval = 0.45
    var spawnPlayerCollisionGraceDuration: TimeInterval = 0.5
    var maxPendingSpawnWarnings = 4
    // Staggers the first appearance of newly enabled patterns at phase boundaries.
    var patternIntroductionSpacing: TimeInterval = 1.5
    // Mode rules use these gates to teach one new pattern at a time. They default
    // to zero so isolated/custom spawn configurations retain their existing behavior.
    var formationMinimumSurvivalTime: TimeInterval = 0
    var splitterMinimumSurvivalTime: TimeInterval = 0
    var arrowRushMinimumSurvivalTime: TimeInterval = 0
    var mineDotMinimumSurvivalTime: TimeInterval = 0
    var hunterDotMinimumSurvivalTime: TimeInterval = 0
    var paddleTrapMinimumSurvivalTime: TimeInterval = 0
    var splitterRadiusScale: CGFloat = 1.85
    var splitterChildRadiusScale: CGFloat = 0.85
    var splitterChildSpeedScale: CGFloat = 1.25
    var splitterChildSpawnOffset: CGFloat = 18
    var splitterChildGraceDuration: TimeInterval = 0.75
    var splitterChildPlayerSafetyRadius: CGFloat = 42
    var formationTelegraphDuration: TimeInterval = 1.1
    var formationLineInset: CGFloat = 28
    var formationGapScale: CGFloat = 0.85
    var formationSpawnOffset: CGFloat = 14
    var minimumFormationEnemyCount = 2
    var arrowRushTelegraphDuration: TimeInterval = 0.85
    var arrowRushSpawnOffset: CGFloat = 18
    var arrowRushEnemySpacing: CGFloat = 24
    var minimumArrowRushEnemyCount = 2
    var mineDotTelegraphDuration: TimeInterval = 0.9
    var mineDotTelegraphRadius: CGFloat = 24
    var mineDotPickupGuardDistance: CGFloat = 22
    var mineDotCandidateInset: CGFloat = 48
    var mineDotMinimumSpacing: CGFloat = 52
    var hunterDotTelegraphDuration: TimeInterval = 0.75
    var paddleTrapTelegraphDuration: TimeInterval = 1
    var paddleTrapBarSpacing: CGFloat = 24
    var paddleTrapBarGap: CGFloat = 96
    var paddleTrapCandidateInset: CGFloat = 84
    var paddleTrapMinimumSpacing: CGFloat = 64
    var paddleTrapPlayerSafetyRadius: CGFloat = 64
    var maxPendingEnemyTelegraphs = 2
    var cullingOutset: CGFloat = 72
    var warmup = EnemyPhaseTuning(
        chaserSpawnInterval: 0.92,
        chaserSpeed: 66,
        maxActiveEnemies: 48,
        formationSpawnInterval: nil,
        formationSpeed: 94,
        formationLaneCount: 5
    )
    var pressure = EnemyPhaseTuning(
        chaserSpawnInterval: 0.66,
        chaserSpeed: 88,
        maxActiveEnemies: 82,
        formationSpawnInterval: 8.5,
        formationSpeed: 108,
        formationLaneCount: 5,
        splitterSpawnInterval: 14,
        splitterSpeed: 64,
        maxActiveSplitters: 2
    )
    var chaos = EnemyPhaseTuning(
        chaserSpawnInterval: 0.46,
        chaserSpeed: 112,
        maxActiveEnemies: 140,
        formationSpawnInterval: 5.2,
        formationSpeed: 128,
        formationLaneCount: 7,
        arrowRushSpawnInterval: 7.2,
        arrowRushSpeed: 185,
        arrowRushEnemyCount: 3,
        mineDotSpawnInterval: 9.5,
        maxActiveMineDots: 4,
        hunterDotSpawnInterval: 12.5,
        hunterDotSpeed: 134,
        hunterDotPredictionLead: 0.6,
        maxActiveHunterDots: 2,
        paddleTrapSpawnInterval: 16.5,
        maxActivePaddleTraps: 1,
        paddleTrapLifetime: 7,
        paddleTrapBarEnemyCount: 3,
        paddleTrapDotSpeed: 172,
        splitterSpawnInterval: 10.5,
        splitterSpeed: 82,
        maxActiveSplitters: 3
    )
    var survivalHell = EnemyPhaseTuning(
        chaserSpawnInterval: 0.30,
        chaserSpeed: 140,
        maxActiveEnemies: 210,
        formationSpawnInterval: 3.7,
        formationSpeed: 154,
        formationLaneCount: 9,
        arrowRushSpawnInterval: 4.8,
        arrowRushSpeed: 220,
        arrowRushEnemyCount: 5,
        mineDotSpawnInterval: 6.2,
        maxActiveMineDots: 7,
        hunterDotSpawnInterval: 7.8,
        hunterDotSpeed: 168,
        hunterDotPredictionLead: 0.9,
        maxActiveHunterDots: 3,
        paddleTrapSpawnInterval: 12,
        maxActivePaddleTraps: 2,
        paddleTrapLifetime: 8,
        paddleTrapBarEnemyCount: 4,
        paddleTrapDotSpeed: 214,
        splitterSpawnInterval: 7.8,
        splitterSpeed: 104,
        maxActiveSplitters: 4
    )

    func enemySurvivalSpeedMultiplier(at survivalTime: TimeInterval) -> CGFloat {
        let startMultiplier = finiteNonnegativeMultiplier(enemySurvivalSpeedStartMultiplier)
        let maximumMultiplier = max(
            startMultiplier,
            finiteNonnegativeMultiplier(maximumEnemySurvivalSpeedMultiplier)
        )
        let rampDuration = enemySurvivalSpeedRampDuration.isFinite
            ? max(0.001, enemySurvivalSpeedRampDuration)
            : 0.001
        let survivalTime = survivalTime.isFinite ? max(0, survivalTime) : 0
        let progress = 1 - exp(-survivalTime / rampDuration)
        return startMultiplier + (maximumMultiplier - startMultiplier) * CGFloat(progress)
    }

    func maximumSpeed(for kind: EnemyKind, playerMaximumSpeed: CGFloat) -> CGFloat {
        let ratio: CGFloat

        switch kind {
        case .chaser:
            ratio = chaserPlayerSpeedRatio
        case .formation:
            ratio = formationPlayerSpeedRatio
        case .arrowRush:
            ratio = arrowRushPlayerSpeedRatio
        case .mine, .paddleBar:
            return 0
        case .hunter:
            ratio = hunterDotPlayerSpeedRatio
        case .paddlePuck:
            ratio = paddleTrapDotPlayerSpeedRatio
        case .splitter:
            ratio = splitterPlayerSpeedRatio
        case .splitterChild:
            ratio = splitterChildPlayerSpeedRatio
        }

        let playerMaximumSpeed = playerMaximumSpeed.isFinite ? max(0, playerMaximumSpeed) : 0
        return min(
            EnemySpawnSafetyLimits.maximumSpeed,
            playerMaximumSpeed * finiteNonnegativeMultiplier(ratio)
        )
    }

    func tuning(at survivalTime: TimeInterval) -> EnemyPhaseTuning {
        let phase = EnemyDifficultyPhase.phase(at: survivalTime)
        let anchors = phaseAnchors
        let currentIndex = anchors.firstIndex { $0.phase == phase } ?? 0
        let current = anchors[currentIndex]
        let next = currentIndex + 1 < anchors.count ? anchors[currentIndex + 1] : nil
        let progress = interpolationProgress(survivalTime: survivalTime, current: current, next: next)

        var tuning = current.tuning.interpolated(
            toward: next?.tuning,
            progress: progress
        )

        let time = survivalTime.isFinite ? max(0, survivalTime) : 0
        if time < finiteThreshold(formationMinimumSurvivalTime) {
            tuning.formationSpawnInterval = nil
        }
        if time < finiteThreshold(splitterMinimumSurvivalTime) {
            tuning.splitterSpawnInterval = nil
        }
        if time < finiteThreshold(arrowRushMinimumSurvivalTime) {
            tuning.arrowRushSpawnInterval = nil
        }
        if time < finiteThreshold(mineDotMinimumSurvivalTime) {
            tuning.mineDotSpawnInterval = nil
        }
        if time < finiteThreshold(hunterDotMinimumSurvivalTime) {
            tuning.hunterDotSpawnInterval = nil
        }
        if time < finiteThreshold(paddleTrapMinimumSurvivalTime) {
            tuning.paddleTrapSpawnInterval = nil
        }

        return tuning
    }

    private var phaseAnchors: [(phase: EnemyDifficultyPhase, tuning: EnemyPhaseTuning)] {
        [
            (.warmup, warmup),
            (.pressure, pressure),
            (.chaos, chaos),
            (.survivalHell, survivalHell)
        ]
    }

    private func interpolationProgress(
        survivalTime: TimeInterval,
        current: (phase: EnemyDifficultyPhase, tuning: EnemyPhaseTuning),
        next: (phase: EnemyDifficultyPhase, tuning: EnemyPhaseTuning)?
    ) -> CGFloat {
        guard let next else {
            return 0
        }

        let span = next.phase.startTime - current.phase.startTime
        guard span > 0 else {
            return 0
        }

        let survivalTime = survivalTime.isFinite ? max(0, survivalTime) : 0
        let rawProgress = (survivalTime - current.phase.startTime) / span
        return CGFloat(min(1, max(0, rawProgress)))
    }

    private func finiteThreshold(_ value: TimeInterval) -> TimeInterval {
        value.isFinite ? max(0, value) : 0
    }

    private func finiteNonnegativeMultiplier(_ value: CGFloat) -> CGFloat {
        value.isFinite
            ? min(EnemySpawnSafetyLimits.maximumSpeed, max(0, value))
            : 0
    }
}

struct EnemyTelegraphSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
}

struct EnemyTelegraph: Equatable, Identifiable {
    let id: Int
    let segments: [EnemyTelegraphSegment]
}

struct EnemySpawnFrame: Equatable {
    var newEnemies: [ArenaEnemy] = []
    var telegraphsToShow: [EnemyTelegraph] = []
    var telegraphIDsToRemove: Set<Int> = []
    var runtimeCorrectionCount = 0
}
