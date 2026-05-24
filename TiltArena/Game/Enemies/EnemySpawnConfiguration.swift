import CoreGraphics
import Foundation

enum EnemyDifficultyPhase: Equatable {
    case warmup
    case pressure
    case chaos
    case survivalHell

    static func phase(at survivalTime: TimeInterval) -> EnemyDifficultyPhase {
        let time = max(0, survivalTime)

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
    var hunterDotPredictionLead: CGFloat = 0
    var maxActiveHunterDots: Int = 0
    var paddleTrapSpawnInterval: TimeInterval?
    var maxActivePaddleTraps: Int = 0
    var paddleTrapLifetime: TimeInterval = 0
    var paddleTrapBarEnemyCount: Int = 0
    var paddleTrapDotSpeed: CGFloat = 0
}

struct EnemySpawnConfiguration: Equatable {
    var enemyRadius: CGFloat = 5
    var playerSafetyRadius: CGFloat = 120
    var pickupClearance: CGFloat = 8
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
    var mineDotPickupGuardDistance: CGFloat = 44
    var mineDotCandidateInset: CGFloat = 48
    var mineDotMinimumSpacing: CGFloat = 52
    var hunterDotTelegraphDuration: TimeInterval = 0.75
    var paddleTrapTelegraphDuration: TimeInterval = 1
    var paddleTrapBarSpacing: CGFloat = 24
    var paddleTrapBarGap: CGFloat = 96
    var paddleTrapCandidateInset: CGFloat = 84
    var paddleTrapMinimumSpacing: CGFloat = 64
    var maxPendingEnemyTelegraphs = 2
    var cullingOutset: CGFloat = 72
    var warmup = EnemyPhaseTuning(
        chaserSpawnInterval: 1.4,
        chaserSpeed: 55,
        maxActiveEnemies: 40,
        formationSpawnInterval: nil,
        formationSpeed: 86,
        formationLaneCount: 5
    )
    var pressure = EnemyPhaseTuning(
        chaserSpawnInterval: 1.05,
        chaserSpeed: 70,
        maxActiveEnemies: 70,
        formationSpawnInterval: 12,
        formationSpeed: 98,
        formationLaneCount: 5
    )
    var chaos = EnemyPhaseTuning(
        chaserSpawnInterval: 0.75,
        chaserSpeed: 88,
        maxActiveEnemies: 120,
        formationSpawnInterval: 8,
        formationSpeed: 116,
        formationLaneCount: 7,
        arrowRushSpawnInterval: 10,
        arrowRushSpeed: 150,
        arrowRushEnemyCount: 3,
        mineDotSpawnInterval: 14,
        maxActiveMineDots: 4,
        hunterDotSpawnInterval: 18,
        hunterDotSpeed: 108,
        hunterDotPredictionLead: 0.6,
        maxActiveHunterDots: 2,
        paddleTrapSpawnInterval: 24,
        maxActivePaddleTraps: 1,
        paddleTrapLifetime: 7,
        paddleTrapBarEnemyCount: 4,
        paddleTrapDotSpeed: 145
    )
    var survivalHell = EnemyPhaseTuning(
        chaserSpawnInterval: 0.5,
        chaserSpeed: 108,
        maxActiveEnemies: 180,
        formationSpawnInterval: 5.5,
        formationSpeed: 136,
        formationLaneCount: 9,
        arrowRushSpawnInterval: 7,
        arrowRushSpeed: 175,
        arrowRushEnemyCount: 5,
        mineDotSpawnInterval: 10,
        maxActiveMineDots: 7,
        hunterDotSpawnInterval: 13,
        hunterDotSpeed: 132,
        hunterDotPredictionLead: 0.9,
        maxActiveHunterDots: 3,
        paddleTrapSpawnInterval: 18,
        maxActivePaddleTraps: 2,
        paddleTrapLifetime: 8,
        paddleTrapBarEnemyCount: 5,
        paddleTrapDotSpeed: 170
    )

    func tuning(at survivalTime: TimeInterval) -> EnemyPhaseTuning {
        let phase = EnemyDifficultyPhase.phase(at: survivalTime)
        let anchors = phaseAnchors
        let currentIndex = anchors.firstIndex { $0.phase == phase } ?? 0
        let current = anchors[currentIndex]
        let next = currentIndex + 1 < anchors.count ? anchors[currentIndex + 1] : nil
        let progress = interpolationProgress(survivalTime: survivalTime, current: current, next: next)

        return EnemyPhaseTuning(
            chaserSpawnInterval: interpolate(current.tuning.chaserSpawnInterval, next?.tuning.chaserSpawnInterval, progress),
            chaserSpeed: interpolate(current.tuning.chaserSpeed, next?.tuning.chaserSpeed, progress),
            maxActiveEnemies: interpolateCount(current.tuning.maxActiveEnemies, next?.tuning.maxActiveEnemies, progress),
            formationSpawnInterval: current.tuning.formationSpawnInterval,
            formationSpeed: interpolate(current.tuning.formationSpeed, next?.tuning.formationSpeed, progress),
            formationLaneCount: max(3, current.tuning.formationLaneCount),
            arrowRushSpawnInterval: current.tuning.arrowRushSpawnInterval,
            arrowRushSpeed: interpolate(current.tuning.arrowRushSpeed, next?.tuning.arrowRushSpeed, progress),
            arrowRushEnemyCount: interpolateCount(current.tuning.arrowRushEnemyCount, next?.tuning.arrowRushEnemyCount, progress),
            mineDotSpawnInterval: current.tuning.mineDotSpawnInterval,
            maxActiveMineDots: interpolateCount(current.tuning.maxActiveMineDots, next?.tuning.maxActiveMineDots, progress),
            hunterDotSpawnInterval: current.tuning.hunterDotSpawnInterval,
            hunterDotSpeed: interpolate(current.tuning.hunterDotSpeed, next?.tuning.hunterDotSpeed, progress),
            hunterDotPredictionLead: interpolate(
                current.tuning.hunterDotPredictionLead,
                next?.tuning.hunterDotPredictionLead,
                progress
            ),
            maxActiveHunterDots: interpolateCount(
                current.tuning.maxActiveHunterDots,
                next?.tuning.maxActiveHunterDots,
                progress
            ),
            paddleTrapSpawnInterval: current.tuning.paddleTrapSpawnInterval,
            maxActivePaddleTraps: interpolateCount(
                current.tuning.maxActivePaddleTraps,
                next?.tuning.maxActivePaddleTraps,
                progress
            ),
            paddleTrapLifetime: interpolate(current.tuning.paddleTrapLifetime, next?.tuning.paddleTrapLifetime, progress),
            paddleTrapBarEnemyCount: interpolateCount(
                current.tuning.paddleTrapBarEnemyCount,
                next?.tuning.paddleTrapBarEnemyCount,
                progress
            ),
            paddleTrapDotSpeed: interpolate(current.tuning.paddleTrapDotSpeed, next?.tuning.paddleTrapDotSpeed, progress)
        )
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

        let rawProgress = (max(0, survivalTime) - current.phase.startTime) / span
        return CGFloat(min(1, max(0, rawProgress)))
    }

    private func interpolate(_ start: TimeInterval, _ end: TimeInterval?, _ progress: CGFloat) -> TimeInterval {
        start + ((end ?? start) - start) * TimeInterval(progress)
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat?, _ progress: CGFloat) -> CGFloat {
        start + ((end ?? start) - start) * progress
    }

    private func interpolateCount(_ start: Int, _ end: Int?, _ progress: CGFloat) -> Int {
        max(0, Int(round(interpolate(CGFloat(start), end.map(CGFloat.init), progress))))
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
}
