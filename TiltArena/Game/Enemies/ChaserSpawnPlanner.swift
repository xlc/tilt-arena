import CoreGraphics

struct ChaserSpawnPlanner {
    private(set) var nextEnemyID = 1
    private var nextCandidateIndex = 0

    mutating func reset() {
        nextEnemyID = 1
        nextCandidateIndex = 0
    }

    mutating func spawnChaser(
        in playableRect: CGRect,
        avoiding playerPosition: CGPoint,
        configuration: ClassicRunConfiguration
    ) -> ChaserEnemy? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        for _ in 0..<24 {
            let position = candidatePosition(in: playableRect, index: nextCandidateIndex)
            nextCandidateIndex += 1

            if isSafeSpawn(position, avoiding: playerPosition, safetyRadius: configuration.playerSafetyRadius) {
                let enemy = ChaserEnemy(
                    id: nextEnemyID,
                    position: position,
                    radius: configuration.enemyRadius,
                    speed: configuration.chaserSpeed
                )
                nextEnemyID += 1
                return enemy
            }
        }

        return nil
    }

    func isSafeSpawn(_ position: CGPoint, avoiding playerPosition: CGPoint, safetyRadius: CGFloat) -> Bool {
        let dx = position.x - playerPosition.x
        let dy = position.y - playerPosition.y
        return dx * dx + dy * dy >= safetyRadius * safetyRadius
    }

    private func candidatePosition(in rect: CGRect, index: Int) -> CGPoint {
        let side = index % 4
        let lane = CGFloat(((index / 4) % 7) + 1) / 8

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
}
