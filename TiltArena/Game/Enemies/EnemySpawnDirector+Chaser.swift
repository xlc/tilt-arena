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
}
