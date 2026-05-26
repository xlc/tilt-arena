import CoreGraphics
import Foundation

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

    struct SpawnContext {
        let deltaTime: TimeInterval
        let tuning: EnemyPhaseTuning
        let playableRect: CGRect
        let playerPosition: CGPoint
        let pickupCircles: [CollisionCircle]
        let activeEnemies: [ArenaEnemy]
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
    var nextPaddleTrapCandidateIndex = 0
    var nextPaddleTrapOrientationIndex = 0
    var nextPaddleTrapID = 1
    private var timeUntilNextChaser: TimeInterval = 0
    private var timeUntilNextFormation: TimeInterval = 0
    var timeUntilNextArrowRush: TimeInterval = 0
    var timeUntilNextMineDot: TimeInterval = 0
    var timeUntilNextHunterDot: TimeInterval = 0
    var timeUntilNextPaddleTrap: TimeInterval = 0
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

    var pendingPaddleTrapCount: Int {
        let trapIDs = pendingSpawns.values.flatMap { pendingSpawn in
            pendingSpawn.enemies.compactMap(\.paddleTrapID)
        }
        return Set(trapIDs).count
    }

    init(
        configuration: EnemySpawnConfiguration = EnemySpawnConfiguration(),
        sequenceSeed: Int? = nil
    ) {
        self.configuration = configuration
        applySequenceSeed(sequenceSeed)
    }

    mutating func reset(sequenceSeed: Int? = nil) {
        nextEnemyID = 1
        nextFormationID = 1
        nextTelegraphID = 1
        nextChaserCandidateIndex = 0
        nextFormationDirectionIndex = 0
        nextArrowRushDirectionIndex = 0
        nextMineDotCandidateIndex = 0
        nextHunterDotCandidateIndex = 0
        nextPaddleTrapCandidateIndex = 0
        nextPaddleTrapOrientationIndex = 0
        nextPaddleTrapID = 1
        timeUntilNextChaser = 0
        timeUntilNextFormation = 0
        timeUntilNextArrowRush = 0
        timeUntilNextMineDot = 0
        timeUntilNextHunterDot = 0
        timeUntilNextPaddleTrap = 0
        pendingSpawns.removeAll()
        applySequenceSeed(sequenceSeed)
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
        let context = SpawnContext(
            deltaTime: clampedDelta,
            tuning: tuning,
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            activeEnemies: activeEnemies
        )

        advancePendingEnemySpawns(
            deltaTime: clampedDelta,
            activeEnemyCount: activeEnemyCount,
            maxActiveEnemies: tuning.maxActiveEnemies,
            frame: &frame
        )

        spawnChasersIfNeeded(
            projectedEnemyCount: activeEnemyCount + frame.newEnemies.count + pendingEnemyCount,
            context: context,
            frame: &frame
        )

        spawnFormationTelegraphIfNeeded(
            projectedEnemyCount: activeEnemyCount + frame.newEnemies.count + pendingEnemyCount,
            context: context,
            frame: &frame
        )

        spawnArrowRushTelegraphIfNeeded(
            projectedEnemyCount: activeEnemyCount + frame.newEnemies.count + pendingEnemyCount,
            context: context,
            frame: &frame
        )

        spawnMineDotTelegraphIfNeeded(
            context: context,
            frame: &frame
        )

        spawnHunterDotTelegraphIfNeeded(
            context: context,
            frame: &frame
        )

        spawnPaddleTrapTelegraphIfNeeded(
            context: context,
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
        guard ArenaGeometry.squaredDistance(from: position, to: playerPosition) >= playerClearance * playerClearance else {
            return false
        }

        return pickupCircles.allSatisfy { pickupCircle in
            let clearance = pickupCircle.radius + configuration.enemyRadius + configuration.pickupClearance
            return ArenaGeometry.squaredDistance(from: position, to: pickupCircle.center) >= clearance * clearance
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
        projectedEnemyCount: Int,
        context: SpawnContext,
        frame: inout EnemySpawnFrame
    ) {
        guard context.deltaTime > 0, context.tuning.chaserSpawnInterval > 0 else {
            return
        }

        guard projectedEnemyCount < context.tuning.maxActiveEnemies else {
            timeUntilNextChaser = max(timeUntilNextChaser, context.tuning.chaserSpawnInterval)
            return
        }

        timeUntilNextChaser -= context.deltaTime
        var projectedEnemyCount = projectedEnemyCount

        while timeUntilNextChaser <= 0, projectedEnemyCount < context.tuning.maxActiveEnemies {
            guard let enemy = spawnChaser(
                in: context.playableRect,
                avoiding: context.playerPosition,
                pickupCircles: context.pickupCircles,
                tuning: context.tuning
            ) else {
                timeUntilNextChaser = context.tuning.chaserSpawnInterval
                return
            }

            frame.newEnemies.append(enemy)
            projectedEnemyCount += 1
            timeUntilNextChaser += context.tuning.chaserSpawnInterval
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

            let enemy = movingEnemy(
                id: nextEnemyID,
                position: position,
                speed: tuning.chaserSpeed
            )
            nextEnemyID += 1
            return enemy
        }

        return nil
    }

    private mutating func applySequenceSeed(_ seed: Int?) {
        guard let seed else {
            return
        }

        nextChaserCandidateIndex = positiveModulo(seed, Self.candidateSideCount * Self.candidateLaneCount)
        nextFormationDirectionIndex = positiveModulo(seed / 3, EdgeDirection.allCases.count)
        nextArrowRushDirectionIndex = positiveModulo(seed / 5, EdgeDirection.allCases.count)
        nextMineDotCandidateIndex = positiveModulo(seed / 7, Self.candidateSideCount * Self.candidateLaneCount)
        nextHunterDotCandidateIndex = positiveModulo(seed / 11, Self.candidateSideCount * Self.candidateLaneCount)
        nextPaddleTrapCandidateIndex = positiveModulo(seed / 13, Self.candidateSideCount * Self.candidateLaneCount)
        nextPaddleTrapOrientationIndex = positiveModulo(seed / 17, 2)
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private mutating func spawnFormationTelegraphIfNeeded(
        projectedEnemyCount: Int,
        context: SpawnContext,
        frame: inout EnemySpawnFrame
    ) {
        guard context.deltaTime > 0, let formationSpawnInterval = context.tuning.formationSpawnInterval else {
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

        guard projectedEnemyCount + requiredFormationEnemyCount <= context.tuning.maxActiveEnemies else {
            timeUntilNextFormation = max(timeUntilNextFormation, formationSpawnInterval)
            return
        }

        timeUntilNextFormation -= context.deltaTime

        guard timeUntilNextFormation <= 0 else {
            return
        }

        let availableSlots = context.tuning.maxActiveEnemies - projectedEnemyCount
        guard let formation = makePendingFormation(
            in: context.playableRect,
            playerPosition: context.playerPosition,
            pickupCircles: context.pickupCircles,
            tuning: context.tuning,
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
                defer { nextID += 1 }
                return makeFormationEnemy(
                    at: position,
                    id: nextID,
                    formationID: formationID,
                    velocity: velocity,
                    speed: tuning.formationSpeed
                )
            }

        guard enemies.count >= requiredFormationEnemyCount else {
            return nil
        }

        nextEnemyID += enemies.count
        nextFormationID += 1
        nextTelegraphID += 1
        let telegraph = formationTelegraph(
            id: telegraphID,
            direction: direction,
            laneCount: laneCount,
            gapLaneIndex: gapLaneIndex,
            playableRect: playableRect
        )

        return PendingEnemySpawn(
            timeRemaining: configuration.formationTelegraphDuration,
            requiredEnemyCount: requiredFormationEnemyCount,
            enemies: enemies,
            telegraph: telegraph
        )
    }

    private func formationTelegraph(
        id: Int,
        direction: EdgeDirection,
        laneCount: Int,
        gapLaneIndex: Int,
        playableRect: CGRect
    ) -> EnemyTelegraph {
        EnemyTelegraph(
            id: id,
            segments: formationTelegraphSegments(
                direction: direction,
                laneCount: laneCount,
                gapLaneIndex: gapLaneIndex,
                playableRect: playableRect
            )
        )
    }

    private func makeFormationEnemy(
        at position: CGPoint,
        id: Int,
        formationID: Int,
        velocity: CGVector,
        speed: CGFloat
    ) -> ArenaEnemy {
        movingEnemy(
            id: id,
            position: position,
            speed: speed,
            behavior: .formationLine(velocity: velocity, formationID: formationID)
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

    private var requiredFormationEnemyCount: Int {
        max(1, configuration.minimumFormationEnemyCount)
    }

}

extension EnemySpawnDirector {
    func movingEnemy(
        id: Int,
        position: CGPoint,
        speed: CGFloat,
        behavior: EnemyBehavior = .chaser
    ) -> ArenaEnemy {
        ArenaEnemy(
            id: id,
            position: position,
            radius: configuration.enemyRadius,
            speed: speed,
            speedRampPerSecond: configuration.enemySpeedRampPerSecond,
            maximumSpeedMultiplier: configuration.maximumEnemySpeedMultiplier,
            behavior: behavior
        )
    }
}
