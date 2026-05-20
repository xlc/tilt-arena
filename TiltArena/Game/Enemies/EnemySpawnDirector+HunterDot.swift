import CoreGraphics
import Foundation

extension EnemySpawnDirector {
    mutating func spawnHunterDotTelegraphIfNeeded(
        deltaTime: TimeInterval,
        tuning: EnemyPhaseTuning,
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        frame: inout EnemySpawnFrame
    ) {
        guard deltaTime > 0, let hunterDotSpawnInterval = tuning.hunterDotSpawnInterval else {
            timeUntilNextHunterDot = 0
            return
        }

        guard hunterDotSpawnInterval > 0, tuning.maxActiveHunterDots > 0, tuning.hunterDotSpeed > 0 else {
            return
        }

        guard pendingSpawns.count < configuration.maxPendingEnemyTelegraphs else {
            timeUntilNextHunterDot = max(timeUntilNextHunterDot, hunterDotSpawnInterval)
            return
        }

        let activeAndNewEnemies = activeEnemies + frame.newEnemies
        let projectedEnemyCount = activeAndNewEnemies.count + pendingEnemyCount
        let projectedHunterDotCount = activeAndNewEnemies.filter(\.isHunterDot).count + pendingHunterDotCount

        guard projectedEnemyCount + 1 <= tuning.maxActiveEnemies,
              projectedHunterDotCount < tuning.maxActiveHunterDots else {
            timeUntilNextHunterDot = max(timeUntilNextHunterDot, hunterDotSpawnInterval)
            return
        }

        timeUntilNextHunterDot -= deltaTime

        guard timeUntilNextHunterDot <= 0 else {
            return
        }

        guard let hunterDot = makePendingHunterDot(
            in: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            tuning: tuning
        ) else {
            timeUntilNextHunterDot = hunterDotSpawnInterval
            return
        }

        pendingSpawns[hunterDot.telegraph.id] = hunterDot
        frame.telegraphsToShow.append(hunterDot.telegraph)
        timeUntilNextHunterDot += hunterDotSpawnInterval
    }

    private mutating func makePendingHunterDot(
        in playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        tuning: EnemyPhaseTuning
    ) -> PendingEnemySpawn? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        let candidateCount = Self.candidateSideCount * Self.candidateLaneCount

        for _ in 0..<candidateCount {
            let position = candidatePosition(in: playableRect, index: nextHunterDotCandidateIndex)
            nextHunterDotCandidateIndex += 1

            guard isSafeSpawn(position, avoiding: playerPosition, pickupCircles: pickupCircles) else {
                continue
            }

            let enemy = ArenaEnemy(
                id: nextEnemyID,
                position: position,
                radius: configuration.enemyRadius,
                speed: tuning.hunterDotSpeed,
                behavior: .hunterDot(predictionLead: tuning.hunterDotPredictionLead, previousTarget: nil)
            )
            let telegraph = EnemyTelegraph(
                id: nextTelegraphID,
                segments: hunterDotTelegraphSegments(center: position)
            )

            nextEnemyID += 1
            nextTelegraphID += 1

            return PendingEnemySpawn(
                timeRemaining: configuration.hunterDotTelegraphDuration,
                requiredEnemyCount: 1,
                enemies: [enemy],
                telegraph: telegraph
            )
        }

        return nil
    }

    private func hunterDotTelegraphSegments(center: CGPoint) -> [EnemyTelegraphSegment] {
        let radius = configuration.enemyRadius * 2.3
        let horizontalInset = radius * 0.35
        let verticalInset = radius * 0.35

        return [
            EnemyTelegraphSegment(
                start: CGPoint(x: center.x - radius, y: center.y),
                end: CGPoint(x: center.x - horizontalInset, y: center.y)
            ),
            EnemyTelegraphSegment(
                start: CGPoint(x: center.x + horizontalInset, y: center.y),
                end: CGPoint(x: center.x + radius, y: center.y)
            ),
            EnemyTelegraphSegment(
                start: CGPoint(x: center.x, y: center.y - radius),
                end: CGPoint(x: center.x, y: center.y - verticalInset)
            ),
            EnemyTelegraphSegment(
                start: CGPoint(x: center.x, y: center.y + verticalInset),
                end: CGPoint(x: center.x, y: center.y + radius)
            )
        ]
    }
}
