import CoreGraphics

struct ChaserSpawnPlanner {
    private static let candidateSideCount = 4
    private static let candidateLaneCount = 7

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

        for _ in 0..<(Self.candidateSideCount * Self.candidateLaneCount) {
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
}
