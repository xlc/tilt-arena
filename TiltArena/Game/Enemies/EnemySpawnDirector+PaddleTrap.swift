import CoreGraphics
import Foundation

extension EnemySpawnDirector {
    private enum PaddleTrapOrientation {
        case horizontal
        case vertical
    }

    private enum PaddleTrapGrid {
        static let columnCount = 3
        static let rowCount = 3
    }

    private struct PaddleTrapLayout {
        let barPositions: [CGPoint]
        let dotPosition: CGPoint
        let dotVelocity: CGVector
        let dotBounds: CGRect
        let telegraphSegments: [EnemyTelegraphSegment]

        var componentPositions: [CGPoint] {
            barPositions + [dotPosition]
        }
    }

    mutating func spawnPaddleTrapTelegraphIfNeeded(
        deltaTime: TimeInterval,
        tuning: EnemyPhaseTuning,
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        frame: inout EnemySpawnFrame
    ) {
        guard deltaTime > 0, let paddleTrapSpawnInterval = tuning.paddleTrapSpawnInterval else {
            timeUntilNextPaddleTrap = 0
            return
        }

        let componentCount = paddleTrapComponentCount(tuning: tuning)
        guard paddleTrapSpawnInterval > 0,
              tuning.maxActivePaddleTraps > 0,
              tuning.paddleTrapLifetime > 0,
              componentCount > 0,
              tuning.paddleTrapDotSpeed > 0 else {
            return
        }

        guard pendingSpawns.count < configuration.maxPendingEnemyTelegraphs else {
            timeUntilNextPaddleTrap = max(timeUntilNextPaddleTrap, paddleTrapSpawnInterval)
            return
        }

        let activeAndNewEnemies = activeEnemies + frame.newEnemies
        let projectedEnemyCount = activeAndNewEnemies.count + pendingEnemyCount
        let projectedTrapCount = Set(activeAndNewEnemies.compactMap(\.paddleTrapID)).count + pendingPaddleTrapCount

        guard projectedEnemyCount + componentCount <= tuning.maxActiveEnemies,
              projectedTrapCount < tuning.maxActivePaddleTraps else {
            timeUntilNextPaddleTrap = max(timeUntilNextPaddleTrap, paddleTrapSpawnInterval)
            return
        }

        timeUntilNextPaddleTrap -= deltaTime

        guard timeUntilNextPaddleTrap <= 0 else {
            return
        }

        guard let paddleTrap = makePendingPaddleTrap(
            in: playableRect,
            playerPosition: playerPosition,
            pickupCircles: pickupCircles,
            activeEnemies: activeAndNewEnemies,
            tuning: tuning
        ) else {
            timeUntilNextPaddleTrap = paddleTrapSpawnInterval
            return
        }

        pendingSpawns[paddleTrap.telegraph.id] = paddleTrap
        frame.telegraphsToShow.append(paddleTrap.telegraph)
        timeUntilNextPaddleTrap += paddleTrapSpawnInterval
    }

    private mutating func makePendingPaddleTrap(
        in playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        tuning: EnemyPhaseTuning
    ) -> PendingEnemySpawn? {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return nil
        }

        let barEnemyCount = max(1, tuning.paddleTrapBarEnemyCount)
        let pendingTrapPositions = pendingSpawns.values.flatMap { pendingSpawn in
            pendingSpawn.enemies.compactMap { enemy in
                enemy.isPaddleTrap ? enemy.position : nil
            }
        }
        let candidateCount = PaddleTrapGrid.columnCount * PaddleTrapGrid.rowCount * 2

        for _ in 0..<candidateCount {
            let orientation = nextPaddleTrapOrientation()
            let center = paddleTrapCandidateCenter(
                in: playableRect,
                index: nextPaddleTrapCandidateIndex,
                orientation: orientation,
                barEnemyCount: barEnemyCount
            )
            nextPaddleTrapCandidateIndex += 1

            let layout = paddleTrapLayout(
                center: center,
                orientation: orientation,
                barEnemyCount: barEnemyCount,
                dotSpeed: tuning.paddleTrapDotSpeed
            )

            guard isSafePaddleTrapLayout(
                layout,
                playableRect: playableRect,
                playerPosition: playerPosition,
                pickupCircles: pickupCircles,
                activeEnemies: activeEnemies,
                pendingTrapPositions: pendingTrapPositions
            ) else {
                continue
            }

            return pendingPaddleTrap(from: layout, tuning: tuning)
        }

        return nil
    }

    private mutating func pendingPaddleTrap(
        from layout: PaddleTrapLayout,
        tuning: EnemyPhaseTuning
    ) -> PendingEnemySpawn {
        let trapID = nextPaddleTrapID
        let telegraphID = nextTelegraphID
        var nextID = nextEnemyID
        var enemies = layout.barPositions.map { position in
            defer {
                nextID += 1
            }

            return ArenaEnemy(
                id: nextID,
                position: position,
                radius: configuration.enemyRadius,
                speed: 0,
                behavior: .paddleTrapBar(trapID: trapID, remainingLifetime: tuning.paddleTrapLifetime)
            )
        }

        enemies.append(ArenaEnemy(
            id: nextID,
            position: layout.dotPosition,
            radius: configuration.enemyRadius,
            speed: tuning.paddleTrapDotSpeed,
            behavior: .paddleTrapDot(
                trapID: trapID,
                velocity: layout.dotVelocity,
                bounds: layout.dotBounds,
                remainingLifetime: tuning.paddleTrapLifetime
            )
        ))

        nextEnemyID += enemies.count
        nextTelegraphID += 1
        nextPaddleTrapID += 1

        return PendingEnemySpawn(
            timeRemaining: configuration.paddleTrapTelegraphDuration,
            requiredEnemyCount: enemies.count,
            enemies: enemies,
            telegraph: EnemyTelegraph(id: telegraphID, segments: layout.telegraphSegments)
        )
    }

    private mutating func nextPaddleTrapOrientation() -> PaddleTrapOrientation {
        let orientation: PaddleTrapOrientation = nextPaddleTrapOrientationIndex.isMultiple(of: 2) ? .horizontal : .vertical
        nextPaddleTrapOrientationIndex += 1
        return orientation
    }

    private func paddleTrapCandidateCenter(
        in playableRect: CGRect,
        index: Int,
        orientation: PaddleTrapOrientation,
        barEnemyCount: Int
    ) -> CGPoint {
        let spawnRect = paddleTrapCandidateRect(
            in: playableRect,
            orientation: orientation,
            barEnemyCount: barEnemyCount
        )
        let column = index % PaddleTrapGrid.columnCount
        let row = (index / PaddleTrapGrid.columnCount) % PaddleTrapGrid.rowCount

        return CGPoint(
            x: spawnRect.minX + spawnRect.width * CGFloat(column + 1) / CGFloat(PaddleTrapGrid.columnCount + 1),
            y: spawnRect.minY + spawnRect.height * CGFloat(row + 1) / CGFloat(PaddleTrapGrid.rowCount + 1)
        )
    }

    private func paddleTrapCandidateRect(
        in playableRect: CGRect,
        orientation: PaddleTrapOrientation,
        barEnemyCount: Int
    ) -> CGRect {
        let halfSpan = paddleTrapBarHalfSpan(barEnemyCount: barEnemyCount)
        let halfGap = paddleTrapBarHalfGap
        let requestedXInset: CGFloat
        let requestedYInset: CGFloat

        switch orientation {
        case .horizontal:
            requestedXInset = max(configuration.paddleTrapCandidateInset, halfSpan + configuration.enemyRadius)
            requestedYInset = max(configuration.paddleTrapCandidateInset, halfGap + configuration.enemyRadius)
        case .vertical:
            requestedXInset = max(configuration.paddleTrapCandidateInset, halfGap + configuration.enemyRadius)
            requestedYInset = max(configuration.paddleTrapCandidateInset, halfSpan + configuration.enemyRadius)
        }

        let maxXInset = max(0, playableRect.width / 2 - configuration.enemyRadius)
        let maxYInset = max(0, playableRect.height / 2 - configuration.enemyRadius)
        return playableRect.insetBy(dx: min(requestedXInset, maxXInset), dy: min(requestedYInset, maxYInset))
    }

    private func paddleTrapLayout(
        center: CGPoint,
        orientation: PaddleTrapOrientation,
        barEnemyCount: Int,
        dotSpeed: CGFloat
    ) -> PaddleTrapLayout {
        let halfSpan = paddleTrapBarHalfSpan(barEnemyCount: barEnemyCount)
        let halfGap = paddleTrapBarHalfGap
        let innerHalfGap = max(configuration.enemyRadius, halfGap - configuration.enemyRadius * 2.2)
        let speed = max(0, dotSpeed) / sqrt(CGFloat(2))
        let bars = paddleTrapBars(
            center: center,
            orientation: orientation,
            barEnemyCount: barEnemyCount,
            halfSpan: halfSpan,
            halfGap: halfGap
        )

        switch orientation {
        case .horizontal:
            let dotBounds = CGRect(
                x: center.x - halfSpan,
                y: center.y - innerHalfGap,
                width: halfSpan * 2,
                height: innerHalfGap * 2
            )
            let bounceSegment = EnemyTelegraphSegment(
                start: CGPoint(x: center.x, y: dotBounds.minY),
                end: CGPoint(x: center.x, y: dotBounds.maxY)
            )
            return PaddleTrapLayout(
                barPositions: bars.first + bars.second,
                dotPosition: center,
                dotVelocity: CGVector(dx: speed, dy: speed),
                dotBounds: dotBounds,
                telegraphSegments: paddleTrapTelegraphSegments(bars: bars, bounceSegment: bounceSegment)
            )
        case .vertical:
            let dotBounds = CGRect(
                x: center.x - innerHalfGap,
                y: center.y - halfSpan,
                width: innerHalfGap * 2,
                height: halfSpan * 2
            )
            let bounceSegment = EnemyTelegraphSegment(
                start: CGPoint(x: dotBounds.minX, y: center.y),
                end: CGPoint(x: dotBounds.maxX, y: center.y)
            )
            return PaddleTrapLayout(
                barPositions: bars.first + bars.second,
                dotPosition: center,
                dotVelocity: CGVector(dx: speed, dy: -speed),
                dotBounds: dotBounds,
                telegraphSegments: paddleTrapTelegraphSegments(bars: bars, bounceSegment: bounceSegment)
            )
        }
    }

    private func paddleTrapBars(
        center: CGPoint,
        orientation: PaddleTrapOrientation,
        barEnemyCount: Int,
        halfSpan: CGFloat,
        halfGap: CGFloat
    ) -> (first: [CGPoint], second: [CGPoint]) {
        var firstBar: [CGPoint] = []
        var secondBar: [CGPoint] = []

        for index in 0..<barEnemyCount {
            let offset = CGFloat(index) * configuration.paddleTrapBarSpacing - halfSpan

            switch orientation {
            case .horizontal:
                firstBar.append(CGPoint(x: center.x + offset, y: center.y - halfGap))
                secondBar.append(CGPoint(x: center.x + offset, y: center.y + halfGap))
            case .vertical:
                firstBar.append(CGPoint(x: center.x - halfGap, y: center.y + offset))
                secondBar.append(CGPoint(x: center.x + halfGap, y: center.y + offset))
            }
        }

        return (firstBar, secondBar)
    }

    private func paddleTrapTelegraphSegments(
        bars: (first: [CGPoint], second: [CGPoint]),
        bounceSegment: EnemyTelegraphSegment
    ) -> [EnemyTelegraphSegment] {
        [
            EnemyTelegraphSegment(start: bars.first[0], end: bars.first[bars.first.count - 1]),
            EnemyTelegraphSegment(start: bars.second[0], end: bars.second[bars.second.count - 1]),
            bounceSegment
        ]
    }

    private func isSafePaddleTrapLayout(
        _ layout: PaddleTrapLayout,
        playableRect: CGRect,
        playerPosition: CGPoint,
        pickupCircles: [CollisionCircle],
        activeEnemies: [ArenaEnemy],
        pendingTrapPositions: [CGPoint]
    ) -> Bool {
        let spawnRect = playableRect.insetBy(dx: configuration.enemyRadius, dy: configuration.enemyRadius)

        for position in layout.componentPositions {
            guard spawnRect.contains(position),
                  isSafeSpawn(position, avoiding: playerPosition, pickupCircles: pickupCircles),
                  isClearOfActiveEnemies(position, activeEnemies: activeEnemies),
                  isClearOfPendingPaddleTraps(position, pendingTrapPositions: pendingTrapPositions) else {
                return false
            }
        }

        return true
    }

    private func isClearOfActiveEnemies(
        _ position: CGPoint,
        activeEnemies: [ArenaEnemy]
    ) -> Bool {
        activeEnemies.allSatisfy { activeEnemy in
            let baseClearance = activeEnemy.radius + configuration.enemyRadius + configuration.pickupClearance
            let clearance = activeEnemy.isPaddleTrap ? max(baseClearance, configuration.paddleTrapMinimumSpacing) : baseClearance
            return squaredDistance(from: position, to: activeEnemy.position) >= clearance * clearance
        }
    }

    private func isClearOfPendingPaddleTraps(
        _ position: CGPoint,
        pendingTrapPositions: [CGPoint]
    ) -> Bool {
        pendingTrapPositions.allSatisfy { pendingPosition in
            let clearance = configuration.paddleTrapMinimumSpacing
            return squaredDistance(from: position, to: pendingPosition) >= clearance * clearance
        }
    }

    private func paddleTrapComponentCount(tuning: EnemyPhaseTuning) -> Int {
        let barEnemyCount = max(0, tuning.paddleTrapBarEnemyCount)
        guard barEnemyCount > 0 else {
            return 0
        }

        return barEnemyCount * 2 + 1
    }

    private func paddleTrapBarHalfSpan(barEnemyCount: Int) -> CGFloat {
        CGFloat(max(0, barEnemyCount - 1)) * configuration.paddleTrapBarSpacing / 2
    }

    private var paddleTrapBarHalfGap: CGFloat {
        max(configuration.enemyRadius * 4, configuration.paddleTrapBarGap / 2)
    }
}
