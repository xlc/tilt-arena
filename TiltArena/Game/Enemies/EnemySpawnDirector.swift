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
}

struct EnemySpawnConfiguration: Equatable {
    var enemyRadius: CGFloat = 8
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
    var maxPendingEnemyTelegraphs = 2
    var cullingOutset: CGFloat = 72
    var warmup = EnemyPhaseTuning(
        chaserSpawnInterval: 1.4,
        chaserSpeed: 55,
        maxActiveEnemies: 40,
        formationSpawnInterval: nil,
        formationSpeed: 86,
        formationLaneCount: 5,
        arrowRushSpawnInterval: nil,
        arrowRushSpeed: 0,
        arrowRushEnemyCount: 0,
        mineDotSpawnInterval: nil,
        maxActiveMineDots: 0,
        hunterDotSpawnInterval: nil,
        hunterDotSpeed: 0,
        hunterDotPredictionLead: 0,
        maxActiveHunterDots: 0
    )
    var pressure = EnemyPhaseTuning(
        chaserSpawnInterval: 1.05,
        chaserSpeed: 70,
        maxActiveEnemies: 70,
        formationSpawnInterval: 12,
        formationSpeed: 98,
        formationLaneCount: 5,
        arrowRushSpawnInterval: nil,
        arrowRushSpeed: 0,
        arrowRushEnemyCount: 0,
        mineDotSpawnInterval: nil,
        maxActiveMineDots: 0,
        hunterDotSpawnInterval: nil,
        hunterDotSpeed: 0,
        hunterDotPredictionLead: 0,
        maxActiveHunterDots: 0
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
        maxActiveHunterDots: 2
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
        maxActiveHunterDots: 3
    )

    func tuning(at survivalTime: TimeInterval) -> EnemyPhaseTuning {
        let phase = EnemyDifficultyPhase.phase(at: survivalTime)
        let anchors = phaseAnchors
        let currentIndex = anchors.firstIndex { $0.phase == phase } ?? 0
        let current = anchors[currentIndex]
        let next = currentIndex + 1 < anchors.count ? anchors[currentIndex + 1] : nil
        let progress = interpolationProgress(survivalTime: survivalTime, current: current, next: next)

        return EnemyPhaseTuning(
            chaserSpawnInterval: interpolate(
                from: current.tuning.chaserSpawnInterval,
                to: next?.tuning.chaserSpawnInterval ?? current.tuning.chaserSpawnInterval,
                progress: progress
            ),
            chaserSpeed: interpolate(
                from: current.tuning.chaserSpeed,
                to: next?.tuning.chaserSpeed ?? current.tuning.chaserSpeed,
                progress: progress
            ),
            maxActiveEnemies: Int(
                round(interpolate(
                    from: CGFloat(current.tuning.maxActiveEnemies),
                    to: CGFloat(next?.tuning.maxActiveEnemies ?? current.tuning.maxActiveEnemies),
                    progress: progress
                ))
            ),
            formationSpawnInterval: current.tuning.formationSpawnInterval,
            formationSpeed: interpolate(
                from: current.tuning.formationSpeed,
                to: next?.tuning.formationSpeed ?? current.tuning.formationSpeed,
                progress: progress
            ),
            formationLaneCount: max(3, current.tuning.formationLaneCount),
            arrowRushSpawnInterval: current.tuning.arrowRushSpawnInterval,
            arrowRushSpeed: interpolate(
                from: current.tuning.arrowRushSpeed,
                to: next?.tuning.arrowRushSpeed ?? current.tuning.arrowRushSpeed,
                progress: progress
            ),
            arrowRushEnemyCount: max(0, Int(
                round(interpolate(
                    from: CGFloat(current.tuning.arrowRushEnemyCount),
                    to: CGFloat(next?.tuning.arrowRushEnemyCount ?? current.tuning.arrowRushEnemyCount),
                    progress: progress
                ))
            )),
            mineDotSpawnInterval: current.tuning.mineDotSpawnInterval,
            maxActiveMineDots: max(0, Int(
                round(interpolate(
                    from: CGFloat(current.tuning.maxActiveMineDots),
                    to: CGFloat(next?.tuning.maxActiveMineDots ?? current.tuning.maxActiveMineDots),
                    progress: progress
                ))
            )),
            hunterDotSpawnInterval: current.tuning.hunterDotSpawnInterval,
            hunterDotSpeed: interpolate(
                from: current.tuning.hunterDotSpeed,
                to: next?.tuning.hunterDotSpeed ?? current.tuning.hunterDotSpeed,
                progress: progress
            ),
            hunterDotPredictionLead: interpolate(
                from: current.tuning.hunterDotPredictionLead,
                to: next?.tuning.hunterDotPredictionLead ?? current.tuning.hunterDotPredictionLead,
                progress: progress
            ),
            maxActiveHunterDots: max(0, Int(
                round(interpolate(
                    from: CGFloat(current.tuning.maxActiveHunterDots),
                    to: CGFloat(next?.tuning.maxActiveHunterDots ?? current.tuning.maxActiveHunterDots),
                    progress: progress
                ))
            ))
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

    private func interpolate(from start: TimeInterval, to end: TimeInterval, progress: CGFloat) -> TimeInterval {
        start + (end - start) * TimeInterval(progress)
    }

    private func interpolate(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
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

struct EnemySpawnDirector {
    enum EdgeDirection: CaseIterable {
        case leftToRight
        case rightToLeft
        case bottomToTop
        case topToBottom

        var travelsHorizontally: Bool {
            switch self {
            case .leftToRight, .rightToLeft:
                return true
            case .bottomToTop, .topToBottom:
                return false
            }
        }
    }

    struct PendingEnemySpawn {
        var timeRemaining: TimeInterval
        let requiredEnemyCount: Int
        let enemies: [ArenaEnemy]
        let telegraph: EnemyTelegraph
    }

    static let candidateSideCount = 4
    static let candidateLaneCount = 7

    var configuration: EnemySpawnConfiguration
    var nextEnemyID = 1
    private(set) var nextFormationID = 1
    var nextTelegraphID = 1
    private var nextChaserCandidateIndex = 0
    private var nextFormationDirectionIndex = 0
    var nextArrowRushDirectionIndex = 0
    var nextMineDotCandidateIndex = 0
    var nextHunterDotCandidateIndex = 0
    private var timeUntilNextChaser: TimeInterval = 0
    private var timeUntilNextFormation: TimeInterval = 0
    var timeUntilNextArrowRush: TimeInterval = 0
    var timeUntilNextMineDot: TimeInterval = 0
    var timeUntilNextHunterDot: TimeInterval = 0
    var pendingSpawns: [Int: PendingEnemySpawn] = [:]

    var pendingEnemyCount: Int {
        pendingSpawns.values.reduce(0) { $0 + $1.enemies.count }
    }

    var pendingMineDotCount: Int {
        pendingSpawns.values.reduce(0) { count, pendingSpawn in
            count + pendingSpawn.enemies.filter(\.isMineDot).count
        }
    }

    var pendingHunterDotCount: Int {
        pendingSpawns.values.reduce(0) { count, pendingSpawn in
            count + pendingSpawn.enemies.filter(\.isHunterDot).count
        }
    }

    init(configuration: EnemySpawnConfiguration = EnemySpawnConfiguration()) {
        self.configuration = configuration
    }

    mutating func reset() {
        nextEnemyID = 1
        nextFormationID = 1
        nextTelegraphID = 1
        nextChaserCandidateIndex = 0
        nextFormationDirectionIndex = 0
        nextArrowRushDirectionIndex = 0
        nextMineDotCandidateIndex = 0
        nextHunterDotCandidateIndex = 0
        timeUntilNextChaser = 0
        timeUntilNextFormation = 0
        timeUntilNextArrowRush = 0
        timeUntilNextMineDot = 0
        timeUntilNextHunterDot = 0
        pendingSpawns.removeAll()
    }

    mutating func update(
        deltaTime: TimeInterval,
        survivalTime: TimeInterval,
        activeEnemies: [ArenaEnemy],
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle]
    ) -> EnemySpawnFrame {
        let clampedDelta = max(0, deltaTime)
        let tuning = configuration.tuning(at: survivalTime)
        let activeEnemyCount = activeEnemies.count
        var frame = EnemySpawnFrame()

        advancePendingEnemySpawns(
            deltaTime: clampedDelta,
            activeEnemyCount: activeEnemyCount,
            maxActiveEnemies: tuning.maxActiveEnemies,
            frame: &frame
        )

        spawnChasersIfNeeded(
            deltaTime: clampedDelta,
            projectedEnemyCount: activeEnemyCount + frame.newEnemies.count + pendingEnemyCount,
            tuning: tuning,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            frame: &frame
        )

        spawnFormationTelegraphIfNeeded(
            deltaTime: clampedDelta,
            projectedEnemyCount: activeEnemyCount + frame.newEnemies.count + pendingEnemyCount,
            tuning: tuning,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            frame: &frame
        )

        spawnArrowRushTelegraphIfNeeded(
            deltaTime: clampedDelta,
            projectedEnemyCount: activeEnemyCount + frame.newEnemies.count + pendingEnemyCount,
            tuning: tuning,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            frame: &frame
        )

        spawnMineDotTelegraphIfNeeded(
            deltaTime: clampedDelta,
            tuning: tuning,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            activeEnemies: activeEnemies,
            frame: &frame
        )

        spawnHunterDotTelegraphIfNeeded(
            deltaTime: clampedDelta,
            tuning: tuning,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            activeEnemies: activeEnemies,
            frame: &frame
        )

        return frame
    }

    func isSafeSpawn(
        _ position: CGPoint,
        avoiding playerPosition: CGPoint,
        pickupCircles: [CollisionCircle] = []
    ) -> Bool {
        let playerClearance = configuration.playerSafetyRadius + configuration.enemyRadius
        guard squaredDistance(from: position, to: playerPosition) >= playerClearance * playerClearance else {
            return false
        }

        return pickupCircles.allSatisfy { pickupCircle in
            let clearance = pickupCircle.radius + configuration.enemyRadius + configuration.pickupClearance
            return squaredDistance(from: position, to: pickupCircle.center) >= clearance * clearance
        }
    }

    private mutating func advancePendingEnemySpawns(
        deltaTime: TimeInterval,
        activeEnemyCount: Int,
        maxActiveEnemies: Int,
        frame: inout EnemySpawnFrame
    ) {
        guard deltaTime > 0 else {
            return
        }

        for telegraphID in pendingSpawns.keys.sorted() {
            guard var pendingSpawn = pendingSpawns[telegraphID] else {
                continue
            }

            pendingSpawn.timeRemaining -= deltaTime

            if pendingSpawn.timeRemaining <= 0 {
                let availableSlots = max(0, maxActiveEnemies - activeEnemyCount - frame.newEnemies.count)
                let enemiesToSpawn = Array(pendingSpawn.enemies.prefix(availableSlots))

                if enemiesToSpawn.count >= pendingSpawn.requiredEnemyCount {
                    frame.newEnemies.append(contentsOf: enemiesToSpawn)
                }

                frame.telegraphIDsToRemove.insert(telegraphID)
                pendingSpawns.removeValue(forKey: telegraphID)
            } else {
                pendingSpawns[telegraphID] = pendingSpawn
            }
        }
    }

    private mutating func spawnChasersIfNeeded(
        deltaTime: TimeInterval,
        projectedEnemyCount: Int,
        tuning: EnemyPhaseTuning,
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        frame: inout EnemySpawnFrame
    ) {
        guard deltaTime > 0, tuning.chaserSpawnInterval > 0 else {
            return
        }

        guard projectedEnemyCount < tuning.maxActiveEnemies else {
            timeUntilNextChaser = max(timeUntilNextChaser, tuning.chaserSpawnInterval)
            return
        }

        timeUntilNextChaser -= deltaTime
        var projectedEnemyCount = projectedEnemyCount

        while timeUntilNextChaser <= 0, projectedEnemyCount < tuning.maxActiveEnemies {
            guard let enemy = spawnChaser(
                in: playableRect,
                avoiding: playerPosition,
                pickupCircles: pickupCircles,
                tuning: tuning
            ) else {
                timeUntilNextChaser = tuning.chaserSpawnInterval
                return
            }

            frame.newEnemies.append(enemy)
            projectedEnemyCount += 1
            timeUntilNextChaser += tuning.chaserSpawnInterval
        }
    }

    private mutating func spawnChaser(
        in playableRect: CGRect,
        avoiding playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        tuning: EnemyPhaseTuning
    ) -> ArenaEnemy? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        for _ in 0..<(Self.candidateSideCount * Self.candidateLaneCount) {
            let position = candidatePosition(in: playableRect, index: nextChaserCandidateIndex)
            nextChaserCandidateIndex += 1

            guard isSafeSpawn(position, avoiding: playerPosition, pickupCircles: pickupCircles) else {
                continue
            }

            let enemy = ArenaEnemy(
                id: nextEnemyID,
                position: position,
                radius: configuration.enemyRadius,
                speed: tuning.chaserSpeed
            )
            nextEnemyID += 1
            return enemy
        }

        return nil
    }

    private mutating func spawnFormationTelegraphIfNeeded(
        deltaTime: TimeInterval,
        projectedEnemyCount: Int,
        tuning: EnemyPhaseTuning,
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        frame: inout EnemySpawnFrame
    ) {
        guard deltaTime > 0, let formationSpawnInterval = tuning.formationSpawnInterval else {
            timeUntilNextFormation = 0
            return
        }

        guard formationSpawnInterval > 0 else {
            return
        }

        guard pendingSpawns.count < configuration.maxPendingEnemyTelegraphs else {
            timeUntilNextFormation = max(timeUntilNextFormation, formationSpawnInterval)
            return
        }

        guard projectedEnemyCount + requiredFormationEnemyCount <= tuning.maxActiveEnemies else {
            timeUntilNextFormation = max(timeUntilNextFormation, formationSpawnInterval)
            return
        }

        timeUntilNextFormation -= deltaTime

        guard timeUntilNextFormation <= 0 else {
            return
        }

        let availableSlots = tuning.maxActiveEnemies - projectedEnemyCount
        guard let formation = makePendingFormation(
            in: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            tuning: tuning,
            availableSlots: availableSlots
        ) else {
            timeUntilNextFormation = formationSpawnInterval
            return
        }

        pendingSpawns[formation.telegraph.id] = formation
        frame.telegraphsToShow.append(formation.telegraph)
        timeUntilNextFormation += formationSpawnInterval
    }

    private mutating func makePendingFormation(
        in playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        tuning: EnemyPhaseTuning,
        availableSlots: Int
    ) -> PendingEnemySpawn? {
        let direction = nextFormationDirection()
        let laneCount = max(3, tuning.formationLaneCount)
        let gapLaneIndex = escapeLaneIndex(
            for: playerPosition,
            direction: direction,
            laneCount: laneCount,
            playableRect: playableRect
        )
        let enemyPositions = formationEnemyPositions(
            direction: direction,
            laneCount: laneCount,
            gapLaneIndex: gapLaneIndex,
            playableRect: playableRect
        )
        let formationID = nextFormationID
        let telegraphID = nextTelegraphID
        let velocity = formationVelocity(direction: direction, speed: tuning.formationSpeed)
        var nextID = nextEnemyID
        let enemies = enemyPositions
            .filter { isSafeSpawn($0, avoiding: playerPosition, pickupCircles: pickupCircles) }
            .prefix(max(0, availableSlots))
            .map { position in
                defer {
                    nextID += 1
                }

                return ArenaEnemy(
                    id: nextID,
                    position: position,
                    radius: configuration.enemyRadius,
                    speed: tuning.formationSpeed,
                    behavior: .formationLine(velocity: velocity, formationID: formationID)
                )
            }

        guard enemies.count >= requiredFormationEnemyCount else {
            return nil
        }

        nextEnemyID += enemies.count
        nextFormationID += 1
        nextTelegraphID += 1

        return PendingEnemySpawn(
            timeRemaining: configuration.formationTelegraphDuration,
            requiredEnemyCount: requiredFormationEnemyCount,
            enemies: Array(enemies),
            telegraph: EnemyTelegraph(
                id: telegraphID,
                segments: formationTelegraphSegments(
                    direction: direction,
                    laneCount: laneCount,
                    gapLaneIndex: gapLaneIndex,
                    playableRect: playableRect
                )
            )
        )
    }

    private mutating func nextFormationDirection() -> EdgeDirection {
        let directions = EdgeDirection.allCases
        let direction = directions[nextFormationDirectionIndex % directions.count]
        nextFormationDirectionIndex += 1
        return direction
    }

    func candidatePosition(in rect: CGRect, index: Int) -> CGPoint {
        let side = index % Self.candidateSideCount
        let lane = CGFloat(((index / Self.candidateSideCount) % Self.candidateLaneCount) + 1)
            / CGFloat(Self.candidateLaneCount + 1)

        switch side {
        case 0:
            return CGPoint(x: rect.minX, y: rect.minY + rect.height * lane)
        case 1:
            return CGPoint(x: rect.maxX, y: rect.minY + rect.height * lane)
        case 2:
            return CGPoint(x: rect.minX + rect.width * lane, y: rect.minY)
        default:
            return CGPoint(x: rect.minX + rect.width * lane, y: rect.maxY)
        }
    }

    private func escapeLaneIndex(
        for playerPosition: CGPoint,
        direction: EdgeDirection,
        laneCount: Int,
        playableRect: CGRect
    ) -> Int {
        let coordinate = direction.travelsHorizontally ? playerPosition.y : playerPosition.x
        let start = direction.travelsHorizontally ? playableRect.minY : playableRect.minX
        let length = direction.travelsHorizontally ? playableRect.height : playableRect.width
        guard length > 0 else {
            return laneCount / 2
        }

        let normalized = min(1, max(0, (coordinate - start) / length))
        let lane = Int(round(normalized * CGFloat(laneCount - 1)))
        return min(laneCount - 1, max(0, lane))
    }

    private func formationEnemyPositions(
        direction: EdgeDirection,
        laneCount: Int,
        gapLaneIndex: Int,
        playableRect: CGRect
    ) -> [CGPoint] {
        (0..<laneCount).compactMap { laneIndex in
            guard laneIndex != gapLaneIndex else {
                return nil
            }

            let coordinate = laneCoordinate(laneIndex: laneIndex, laneCount: laneCount, direction: direction, rect: playableRect)
            switch direction {
            case .leftToRight:
                return CGPoint(x: playableRect.minX - configuration.enemyRadius - configuration.formationSpawnOffset, y: coordinate)
            case .rightToLeft:
                return CGPoint(x: playableRect.maxX + configuration.enemyRadius + configuration.formationSpawnOffset, y: coordinate)
            case .bottomToTop:
                return CGPoint(x: coordinate, y: playableRect.minY - configuration.enemyRadius - configuration.formationSpawnOffset)
            case .topToBottom:
                return CGPoint(x: coordinate, y: playableRect.maxY + configuration.enemyRadius + configuration.formationSpawnOffset)
            }
        }
    }

    private func formationTelegraphSegments(
        direction: EdgeDirection,
        laneCount: Int,
        gapLaneIndex: Int,
        playableRect: CGRect
    ) -> [EnemyTelegraphSegment] {
        let axisStart = direction.travelsHorizontally ? playableRect.minY : playableRect.minX
        let axisEnd = direction.travelsHorizontally ? playableRect.maxY : playableRect.maxX
        let axisLength = max(1, axisEnd - axisStart)
        let inset = min(configuration.formationLineInset, axisLength / 4)
        let laneSpacing = axisLength / CGFloat(max(1, laneCount - 1))
        let gapCenter = laneCoordinate(
            laneIndex: gapLaneIndex,
            laneCount: laneCount,
            direction: direction,
            rect: playableRect
        )
        let gapHalfWidth = laneSpacing * configuration.formationGapScale / 2
        let firstStart = axisStart + inset
        let firstEnd = max(firstStart, gapCenter - gapHalfWidth)
        let secondStart = min(axisEnd - inset, gapCenter + gapHalfWidth)
        let secondEnd = axisEnd - inset
        let crossAxis = formationTelegraphCrossAxis(direction: direction, playableRect: playableRect)
        var segments: [EnemyTelegraphSegment] = []

        if firstEnd > firstStart {
            segments.append(formationTelegraphSegment(direction: direction, crossAxis: crossAxis, start: firstStart, end: firstEnd))
        }

        if secondEnd > secondStart {
            segments.append(formationTelegraphSegment(direction: direction, crossAxis: crossAxis, start: secondStart, end: secondEnd))
        }

        return segments
    }

    private func formationTelegraphCrossAxis(direction: EdgeDirection, playableRect: CGRect) -> CGFloat {
        switch direction {
        case .leftToRight:
            return playableRect.minX + configuration.enemyRadius
        case .rightToLeft:
            return playableRect.maxX - configuration.enemyRadius
        case .bottomToTop:
            return playableRect.minY + configuration.enemyRadius
        case .topToBottom:
            return playableRect.maxY - configuration.enemyRadius
        }
    }

    private func formationTelegraphSegment(
        direction: EdgeDirection,
        crossAxis: CGFloat,
        start: CGFloat,
        end: CGFloat
    ) -> EnemyTelegraphSegment {
        switch direction {
        case .leftToRight, .rightToLeft:
            return EnemyTelegraphSegment(
                start: CGPoint(x: crossAxis, y: start),
                end: CGPoint(x: crossAxis, y: end)
            )
        case .bottomToTop, .topToBottom:
            return EnemyTelegraphSegment(
                start: CGPoint(x: start, y: crossAxis),
                end: CGPoint(x: end, y: crossAxis)
            )
        }
    }

    private func laneCoordinate(
        laneIndex: Int,
        laneCount: Int,
        direction: EdgeDirection,
        rect: CGRect
    ) -> CGFloat {
        let start = direction.travelsHorizontally ? rect.minY : rect.minX
        let length = direction.travelsHorizontally ? rect.height : rect.width

        guard laneCount > 1 else {
            return start + length / 2
        }

        return start + length * CGFloat(laneIndex) / CGFloat(laneCount - 1)
    }

    private func formationVelocity(direction: EdgeDirection, speed: CGFloat) -> CGVector {
        switch direction {
        case .leftToRight:
            return CGVector(dx: speed, dy: 0)
        case .rightToLeft:
            return CGVector(dx: -speed, dy: 0)
        case .bottomToTop:
            return CGVector(dx: 0, dy: speed)
        case .topToBottom:
            return CGVector(dx: 0, dy: -speed)
        }
    }

    func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private var requiredFormationEnemyCount: Int {
        max(1, configuration.minimumFormationEnemyCount)
    }

}
