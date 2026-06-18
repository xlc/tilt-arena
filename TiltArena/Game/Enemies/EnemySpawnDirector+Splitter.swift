import CoreGraphics
import Foundation

extension EnemySpawnDirector {
    mutating func spawnSplitterIfNeeded(
        projectedEnemyCount: Int,
        context: SpawnContext,
        frame: inout EnemySpawnFrame
    ) {
        guard let splitterSpawnInterval = activeSplitterSpawnInterval(context) else {
            timeUntilNextSplitter = 0
            return
        }

        let activeSplitterCount = context.activeEnemies.filter(\.isSplitter).count
            + frame.newEnemies.filter(\.isSplitter).count
            + pendingSplitterCount
        guard activeSplitterCount < context.tuning.maxActiveSplitters else {
            delayNextSplitter(by: splitterSpawnInterval)
            return
        }

        guard projectedEnemyCount < context.tuning.maxActiveEnemies else {
            delayNextSplitter(by: splitterSpawnInterval)
            return
        }

        let maxPendingSpawnWarnings = max(0, configuration.maxPendingSpawnWarnings)
        let usesSpawnWarning = configuration.spawnWarningDuration > 0 && maxPendingSpawnWarnings > 0
        guard !usesSpawnWarning || pendingSpawnWarningCount < maxPendingSpawnWarnings else {
            delayNextSplitter(by: splitterSpawnInterval)
            return
        }

        timeUntilNextSplitter -= context.deltaTime
        var projectedEnemyCount = projectedEnemyCount
        var projectedSplitterCount = activeSplitterCount
        var projectedSpawnWarningCount = pendingSpawnWarningCount

        while timeUntilNextSplitter <= 0,
              projectedEnemyCount < context.tuning.maxActiveEnemies,
              projectedSplitterCount < context.tuning.maxActiveSplitters,
              !usesSpawnWarning || projectedSpawnWarningCount < maxPendingSpawnWarnings {
            guard let enemy = spawnSplitter(
                in: context.playableRect,
                avoiding: context.playerPosition,
                pickupCircles: context.pickupCircles,
                tuning: context.tuning
            ) else {
                timeUntilNextSplitter = splitterSpawnInterval
                return
            }

            if appendSpawnCandidate(enemy, usesWarning: usesSpawnWarning, frame: &frame) {
                projectedSpawnWarningCount += 1
            }
            projectedEnemyCount += 1
            projectedSplitterCount += 1
            timeUntilNextSplitter += splitterSpawnInterval
        }

        if usesSpawnWarning, projectedSpawnWarningCount >= maxPendingSpawnWarnings {
            delayNextSplitter(by: splitterSpawnInterval)
        }
    }

    private mutating func delayNextSplitter(by interval: TimeInterval) {
        timeUntilNextSplitter = max(timeUntilNextSplitter, interval)
    }

    private func activeSplitterSpawnInterval(_ context: SpawnContext) -> TimeInterval? {
        guard context.deltaTime > 0,
              let splitterSpawnInterval = context.tuning.splitterSpawnInterval,
              splitterSpawnInterval > 0,
              context.tuning.maxActiveSplitters > 0 else {
            return nil
        }

        return splitterSpawnInterval
    }

    mutating func splitChildren(
        for enemy: ArenaEnemy,
        playableRect: CGRect,
        playerPosition: CGPoint
    ) -> [ArenaEnemy] {
        guard enemy.isSplitter, playableRect.width > 0, playableRect.height > 0 else {
            return []
        }

        let childRadius = max(1, configuration.enemyRadius * max(0.1, configuration.splitterChildRadiusScale))
        let splitOffset = max(enemy.radius + childRadius + 2, configuration.splitterChildSpawnOffset)
        let away = unitVector(from: playerPosition, to: enemy.position)
        let perpendicular = CGVector(dx: -away.dy, dy: away.dx)
        let basePosition = CGPoint(
            x: enemy.position.x + away.dx * childRadius * 1.5,
            y: enemy.position.y + away.dy * childRadius * 1.5
        )

        nextEnemyID = max(nextEnemyID, enemy.id + 1)

        return [-1, 1].compactMap { side in
            let candidate = CGPoint(
                x: basePosition.x + perpendicular.dx * splitOffset * CGFloat(side),
                y: basePosition.y + perpendicular.dy * splitOffset * CGFloat(side)
            )

            guard let position = safeSplitterChildPosition(
                candidate,
                childRadius: childRadius,
                playableRect: playableRect,
                playerPosition: playerPosition,
                away: away
            ) else {
                return nil
            }

            var child = movingEnemy(
                id: nextEnemyID,
                position: position,
                radius: childRadius,
                speed: enemy.speed * max(0, configuration.splitterChildSpeedScale),
                behavior: .splitterChild
            )
            nextEnemyID += 1
            child.splitSpawnGraceTimeRemaining = max(0, configuration.splitterChildGraceDuration)
            return child
        }
    }

    private mutating func spawnSplitter(
        in playableRect: CGRect,
        avoiding playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        tuning: EnemyPhaseTuning
    ) -> ArenaEnemy? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        for _ in 0..<(Self.candidateSideCount * Self.candidateLaneCount) {
            let position = candidatePosition(in: playableRect, index: nextSplitterCandidateIndex)
            nextSplitterCandidateIndex += 1

            let radius = configuration.enemyRadius * max(1, configuration.splitterRadiusScale)
            guard isSafeSpawn(position, avoiding: playerPosition, pickupCircles: pickupCircles, enemyRadius: radius) else {
                continue
            }

            let enemy = movingEnemy(
                id: nextEnemyID,
                position: position,
                radius: radius,
                speed: tuning.splitterSpeed,
                behavior: .splitter
            )
            nextEnemyID += 1
            return enemy
        }

        return nil
    }

    private func safeSplitterChildPosition(
        _ candidate: CGPoint,
        childRadius: CGFloat,
        playableRect: CGRect,
        playerPosition: CGPoint,
        away: CGVector
    ) -> CGPoint? {
        let minimumDistance = max(0, configuration.splitterChildPlayerSafetyRadius) + childRadius
        var position = candidate
        var dx = position.x - playerPosition.x
        var dy = position.y - playerPosition.y
        var distance = hypot(dx, dy)

        if distance < minimumDistance {
            if distance <= 0 {
                dx = away.dx
                dy = away.dy
                distance = 1
            }

            position = CGPoint(
                x: playerPosition.x + dx / distance * minimumDistance,
                y: playerPosition.y + dy / distance * minimumDistance
            )
        }

        guard let clampedPosition = clamped(position, inside: playableRect, inset: childRadius) else {
            return nil
        }

        let clampedDistance = hypot(
            clampedPosition.x - playerPosition.x,
            clampedPosition.y - playerPosition.y
        )
        guard clampedDistance + 0.001 >= minimumDistance else {
            return nil
        }

        return clampedPosition
    }

    private func unitVector(from start: CGPoint, to end: CGPoint) -> CGVector {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)

        guard distance > 0 else {
            return CGVector(dx: 1, dy: 0)
        }

        return CGVector(dx: dx / distance, dy: dy / distance)
    }

    private func clamped(_ point: CGPoint, inside rect: CGRect, inset: CGFloat) -> CGPoint? {
        let minX = rect.minX + inset
        let maxX = rect.maxX - inset
        let minY = rect.minY + inset
        let maxY = rect.maxY - inset

        guard minX <= maxX, minY <= maxY else {
            return nil
        }

        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }
}
