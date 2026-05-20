import CoreGraphics
import Foundation

extension EnemySpawnDirector {
    private enum MineDotLayout {
        static let interiorColumnCount = 4
        static let interiorRowCount = 4
        static let telegraphSegmentCount = 18
    }

    mutating func spawnMineDotTelegraphIfNeeded(
        deltaTime: TimeInterval,
        tuning: EnemyPhaseTuning,
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        frame: inout EnemySpawnFrame
    ) {
        guard deltaTime > 0, let mineDotSpawnInterval = tuning.mineDotSpawnInterval else {
            timeUntilNextMineDot = 0
            return
        }

        guard mineDotSpawnInterval > 0, tuning.maxActiveMineDots > 0 else {
            return
        }

        guard pendingSpawns.count < configuration.maxPendingEnemyTelegraphs else {
            timeUntilNextMineDot = max(timeUntilNextMineDot, mineDotSpawnInterval)
            return
        }

        let activeAndNewEnemies = activeEnemies + frame.newEnemies
        let projectedEnemyCount = activeAndNewEnemies.count + pendingEnemyCount
        let projectedMineDotCount = activeAndNewEnemies.filter(\.isMineDot).count + pendingMineDotCount

        guard projectedEnemyCount + 1 <= tuning.maxActiveEnemies,
              projectedMineDotCount < tuning.maxActiveMineDots else {
            timeUntilNextMineDot = max(timeUntilNextMineDot, mineDotSpawnInterval)
            return
        }

        timeUntilNextMineDot -= deltaTime

        guard timeUntilNextMineDot <= 0 else {
            return
        }

        guard let mineDot = makePendingMineDot(
            in: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            activeEnemies: activeAndNewEnemies
        ) else {
            timeUntilNextMineDot = mineDotSpawnInterval
            return
        }

        pendingSpawns[mineDot.telegraph.id] = mineDot
        frame.telegraphsToShow.append(mineDot.telegraph)
        timeUntilNextMineDot += mineDotSpawnInterval
    }

    private mutating func makePendingMineDot(
        in playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy]
    ) -> PendingEnemySpawn? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        let pendingMinePositions = pendingSpawns.values.flatMap { pendingSpawn in
            pendingSpawn.enemies.compactMap { enemy in
                enemy.isMineDot ? enemy.position : nil
            }
        }

        let pickupCandidates = pickupAdjacentMineDotCandidates(in: playableRect, pickupCircles: pickupCircles)
        let interiorCandidates = interiorMineDotCandidates(in: playableRect)
        var selectedPosition: CGPoint?

        for position in pickupCandidates where isSafeMineDotSpawn(
            position,
            avoiding: playerPosition,
            pickupCircles: pickupCircles,
            activeEnemies: activeEnemies,
            pendingMinePositions: pendingMinePositions
        ) {
            selectedPosition = position
            break
        }

        if selectedPosition == nil {
            selectedPosition = nextSafeInteriorMineDotPosition(
                candidates: interiorCandidates,
                playerPosition: playerPosition,
                pickupCircles: pickupCircles,
                activeEnemies: activeEnemies,
                pendingMinePositions: pendingMinePositions
            )
        }

        guard let position = selectedPosition else {
            return nil
        }

        let enemy = ArenaEnemy(
            id: nextEnemyID,
            position: position,
            radius: configuration.enemyRadius,
            speed: 0,
            behavior: .mineDot
        )
        let telegraph = EnemyTelegraph(
            id: nextTelegraphID,
            segments: mineDotTelegraphSegments(center: position)
        )

        nextEnemyID += 1
        nextTelegraphID += 1

        return PendingEnemySpawn(
            timeRemaining: configuration.mineDotTelegraphDuration,
            requiredEnemyCount: 1,
            enemies: [enemy],
            telegraph: telegraph
        )
    }

    private mutating func nextSafeInteriorMineDotPosition(
        candidates: [CGPoint],
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        pendingMinePositions: [CGPoint]
    ) -> CGPoint? {
        for offset in 0..<candidates.count {
            let index = (nextMineDotCandidateIndex + offset) % candidates.count
            let position = candidates[index]

            guard isSafeMineDotSpawn(
                position,
                avoiding: playerPosition,
                pickupCircles: pickupCircles,
                activeEnemies: activeEnemies,
                pendingMinePositions: pendingMinePositions
            ) else {
                continue
            }

            nextMineDotCandidateIndex = (index + 1) % candidates.count
            return position
        }

        return nil
    }

    private func pickupAdjacentMineDotCandidates(
        in playableRect: CGRect,
        pickupCircles: [CollisionCircle]
    ) -> [CGPoint] {
        let diagonal = CGFloat(1) / sqrt(CGFloat(2))
        let directions = [
            CGVector(dx: 1, dy: 0),
            CGVector(dx: -1, dy: 0),
            CGVector(dx: 0, dy: 1),
            CGVector(dx: 0, dy: -1),
            CGVector(dx: diagonal, dy: diagonal),
            CGVector(dx: -diagonal, dy: diagonal),
            CGVector(dx: diagonal, dy: -diagonal),
            CGVector(dx: -diagonal, dy: -diagonal)
        ]
        let spawnRect = playableRect.insetBy(dx: configuration.enemyRadius, dy: configuration.enemyRadius)

        return pickupCircles.flatMap { pickupCircle in
            let distance = pickupCircle.radius
                + configuration.enemyRadius
                + configuration.pickupClearance
                + configuration.mineDotPickupGuardDistance

            return directions
                .map { direction in
                    CGPoint(
                        x: pickupCircle.center.x + direction.dx * distance,
                        y: pickupCircle.center.y + direction.dy * distance
                    )
                }
                .filter { spawnRect.contains($0) }
        }
    }

    private func interiorMineDotCandidates(in playableRect: CGRect) -> [CGPoint] {
        let requestedInset = max(
            configuration.mineDotCandidateInset,
            configuration.enemyRadius + configuration.mineDotTelegraphRadius
        )
        let maxInset = max(0, min(playableRect.width, playableRect.height) / 2 - configuration.enemyRadius)
        let inset = min(requestedInset, maxInset)
        let spawnRect = playableRect.insetBy(dx: inset, dy: inset)

        return (0..<MineDotLayout.interiorRowCount).flatMap { row in
            (0..<MineDotLayout.interiorColumnCount).map { column in
                CGPoint(
                    x: spawnRect.minX + spawnRect.width * CGFloat(column + 1) / CGFloat(MineDotLayout.interiorColumnCount + 1),
                    y: spawnRect.minY + spawnRect.height * CGFloat(row + 1) / CGFloat(MineDotLayout.interiorRowCount + 1)
                )
            }
        }
    }

    private func isSafeMineDotSpawn(
        _ position: CGPoint,
        avoiding playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        pendingMinePositions: [CGPoint]
    ) -> Bool {
        guard isSafeSpawn(position, avoiding: playerPosition, pickupCircles: pickupCircles) else {
            return false
        }

        guard activeEnemies.allSatisfy({ activeEnemy in
            let baseClearance = activeEnemy.radius + configuration.enemyRadius + configuration.pickupClearance
            let clearance = activeEnemy.isMineDot ? max(baseClearance, configuration.mineDotMinimumSpacing) : baseClearance
            return squaredDistance(from: position, to: activeEnemy.position) >= clearance * clearance
        }) else {
            return false
        }

        return pendingMinePositions.allSatisfy { pendingPosition in
            let clearance = configuration.mineDotMinimumSpacing
            return squaredDistance(from: position, to: pendingPosition) >= clearance * clearance
        }
    }

    private func mineDotTelegraphSegments(center: CGPoint) -> [EnemyTelegraphSegment] {
        let radius = max(configuration.enemyRadius * 2, configuration.mineDotTelegraphRadius)
        let segmentCount = max(8, MineDotLayout.telegraphSegmentCount)
        let angleStep = CGFloat.pi * 2 / CGFloat(segmentCount)
        let segmentCoverage: CGFloat = 0.58

        return (0..<segmentCount).map { index in
            let startAngle = CGFloat(index) * angleStep
            let endAngle = startAngle + angleStep * segmentCoverage

            return EnemyTelegraphSegment(
                start: CGPoint(
                    x: center.x + cos(startAngle) * radius,
                    y: center.y + sin(startAngle) * radius
                ),
                end: CGPoint(
                    x: center.x + cos(endAngle) * radius,
                    y: center.y + sin(endAngle) * radius
                )
            )
        }
    }
}
