import CoreGraphics
import Foundation

extension EnemySpawnDirector {
    mutating func spawnArrowRushTelegraphIfNeeded(
        projectedEnemyCount: Int,
        context: SpawnContext,
        frame: inout EnemySpawnFrame
    ) {
        guard context.deltaTime > 0, let arrowRushSpawnInterval = context.tuning.arrowRushSpawnInterval else {
            timeUntilNextArrowRush = 0
            return
        }

        let configuredEnemyCount = max(0, context.tuning.arrowRushEnemyCount)
        guard arrowRushSpawnInterval > 0, configuredEnemyCount > 0 else {
            return
        }

        let requiredEnemyCount = requiredArrowRushEnemyCount(configuredEnemyCount: configuredEnemyCount)

        guard pendingSpawns.count < configuration.maxPendingEnemyTelegraphs else {
            timeUntilNextArrowRush = max(timeUntilNextArrowRush, arrowRushSpawnInterval)
            return
        }

        guard projectedEnemyCount + requiredEnemyCount <= context.tuning.maxActiveEnemies else {
            timeUntilNextArrowRush = max(timeUntilNextArrowRush, arrowRushSpawnInterval)
            return
        }

        timeUntilNextArrowRush -= context.deltaTime

        guard timeUntilNextArrowRush <= 0 else {
            return
        }

        let availableSlots = context.tuning.maxActiveEnemies - projectedEnemyCount
        guard let arrowRush = makePendingArrowRush(
            in: context.playableRect,
            playerPosition: context.playerPosition,
            pickupCircles: context.pickupCircles,
            tuning: context.tuning,
            enemyCount: min(configuredEnemyCount, availableSlots),
            requiredEnemyCount: requiredEnemyCount
        ) else {
            timeUntilNextArrowRush = arrowRushSpawnInterval
            return
        }

        pendingSpawns[arrowRush.telegraph.id] = arrowRush
        frame.telegraphsToShow.append(arrowRush.telegraph)
        timeUntilNextArrowRush += arrowRushSpawnInterval
    }

    private mutating func makePendingArrowRush(
        in playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        tuning: EnemyPhaseTuning,
        enemyCount: Int,
        requiredEnemyCount: Int
    ) -> PendingEnemySpawn? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        let direction = nextArrowRushDirection()
        let telegraphID = nextTelegraphID
        var nextID = nextEnemyID
        var enemies: [ArenaEnemy] = []
        var segments: [EnemyTelegraphSegment] = []

        for position in arrowRushSpawnPositions(
            direction: direction,
            enemyCount: enemyCount,
            playableRect: playableRect,
            targetPosition: playerPosition
        ) where isSafeSpawn(position, avoiding: playerPosition, pickupCircles: pickupCircles) {
            guard let velocity = normalizedVelocity(
                from: position,
                to: playerPosition,
                speed: tuning.arrowRushSpeed
            ) else {
                continue
            }

            enemies.append(ArenaEnemy(
                id: nextID,
                position: position,
                radius: configuration.enemyRadius,
                speed: tuning.arrowRushSpeed,
                behavior: .arrowRush(velocity: velocity)
            ))
            segments.append(EnemyTelegraphSegment(
                start: position,
                end: arrowRushTelegraphEnd(from: position, velocity: velocity, playableRect: playableRect)
            ))
            nextID += 1
        }

        guard enemies.count >= requiredEnemyCount else {
            return nil
        }

        nextEnemyID += enemies.count
        nextTelegraphID += 1

        return PendingEnemySpawn(
            timeRemaining: configuration.arrowRushTelegraphDuration,
            requiredEnemyCount: requiredEnemyCount,
            enemies: enemies,
            telegraph: EnemyTelegraph(id: telegraphID, segments: segments)
        )
    }

    private mutating func nextArrowRushDirection() -> EdgeDirection {
        let directions = EdgeDirection.allCases
        let direction = directions[nextArrowRushDirectionIndex % directions.count]
        nextArrowRushDirectionIndex += 1
        return direction
    }

    private func arrowRushSpawnPositions(
        direction: EdgeDirection,
        enemyCount: Int,
        playableRect: CGRect,
        targetPosition: CGPoint
    ) -> [CGPoint] {
        guard enemyCount > 0 else {
            return []
        }

        let targetX = min(playableRect.maxX, max(playableRect.minX, targetPosition.x))
        let targetY = min(playableRect.maxY, max(playableRect.minY, targetPosition.y))
        let spawnOffset = configuration.enemyRadius + configuration.arrowRushSpawnOffset
        let basePosition: CGPoint
        let perpendicular: CGVector

        switch direction {
        case .leftToRight:
            basePosition = CGPoint(x: playableRect.minX - spawnOffset, y: targetY)
            perpendicular = CGVector(dx: 0, dy: 1)
        case .rightToLeft:
            basePosition = CGPoint(x: playableRect.maxX + spawnOffset, y: targetY)
            perpendicular = CGVector(dx: 0, dy: 1)
        case .bottomToTop:
            basePosition = CGPoint(x: targetX, y: playableRect.minY - spawnOffset)
            perpendicular = CGVector(dx: 1, dy: 0)
        case .topToBottom:
            basePosition = CGPoint(x: targetX, y: playableRect.maxY + spawnOffset)
            perpendicular = CGVector(dx: 1, dy: 0)
        }

        return (0..<enemyCount).map { index in
            let offset = (CGFloat(index) - CGFloat(enemyCount - 1) / 2) * configuration.arrowRushEnemySpacing
            return CGPoint(
                x: basePosition.x + perpendicular.dx * offset,
                y: basePosition.y + perpendicular.dy * offset
            )
        }
    }

    private func arrowRushTelegraphEnd(
        from start: CGPoint,
        velocity: CGVector,
        playableRect: CGRect
    ) -> CGPoint {
        let speed = max(1, hypot(velocity.dx, velocity.dy))
        let cullingRect = playableRect.insetBy(
            dx: -configuration.cullingOutset,
            dy: -configuration.cullingOutset
        )
        let travelDistance = hypot(cullingRect.width, cullingRect.height)

        return CGPoint(
            x: start.x + velocity.dx / speed * travelDistance,
            y: start.y + velocity.dy / speed * travelDistance
        )
    }

    private func normalizedVelocity(from start: CGPoint, to target: CGPoint, speed: CGFloat) -> CGVector? {
        let dx = target.x - start.x
        let dy = target.y - start.y
        let distance = hypot(dx, dy)
        let clampedSpeed = max(0, speed)

        guard distance > 0, clampedSpeed > 0 else {
            return nil
        }

        return CGVector(dx: dx / distance * clampedSpeed, dy: dy / distance * clampedSpeed)
    }

    private func requiredArrowRushEnemyCount(configuredEnemyCount: Int) -> Int {
        min(max(1, configuration.minimumArrowRushEnemyCount), configuredEnemyCount)
    }
}
