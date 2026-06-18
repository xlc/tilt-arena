import CoreGraphics
import Foundation

extension EnemySpawnDirector {
    mutating func spawnChasersIfNeeded(
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

        let maxPendingSpawnWarnings = max(0, configuration.maxPendingSpawnWarnings)
        let usesSpawnWarning = configuration.spawnWarningDuration > 0 && maxPendingSpawnWarnings > 0
        guard !usesSpawnWarning || pendingSpawnWarningCount < maxPendingSpawnWarnings else {
            timeUntilNextChaser = max(timeUntilNextChaser, context.tuning.chaserSpawnInterval)
            return
        }

        timeUntilNextChaser -= context.deltaTime
        var projectedEnemyCount = projectedEnemyCount
        var projectedSpawnWarningCount = pendingSpawnWarningCount

        while timeUntilNextChaser <= 0,
              projectedEnemyCount < context.tuning.maxActiveEnemies,
              !usesSpawnWarning || projectedSpawnWarningCount < maxPendingSpawnWarnings {
            guard let enemy = spawnChaser(
                in: context.playableRect,
                avoiding: context.playerPosition,
                pickupCircles: context.pickupCircles,
                tuning: context.tuning
            ) else {
                timeUntilNextChaser = context.tuning.chaserSpawnInterval
                return
            }

            if appendSpawnCandidate(enemy, usesWarning: usesSpawnWarning, frame: &frame) {
                projectedSpawnWarningCount += 1
            }
            projectedEnemyCount += 1
            timeUntilNextChaser += context.tuning.chaserSpawnInterval
        }

        if usesSpawnWarning, projectedSpawnWarningCount >= maxPendingSpawnWarnings {
            timeUntilNextChaser = max(timeUntilNextChaser, context.tuning.chaserSpawnInterval)
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
}
