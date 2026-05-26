import CoreGraphics
import Foundation

struct PowerWaveRelease: Equatable {
    let center: CGPoint
    let direction: CGVector
    let travelDistance: CGFloat
}

struct PowerWaveFrame: Equatable {
    var destroyedEnemyIDs: Set<Int> = []
    var release: PowerWaveRelease?
    var radius: CGFloat = 0
    var isCharging = false
    var isComplete = false
}

struct PowerWaveState: Equatable {
    private(set) var isCharging = false
    private(set) var chargeTimeRemaining: TimeInterval = 0
    private var waveState: PowerWaveWaveState?

    var isActive: Bool {
        isCharging || waveState != nil
    }

    mutating func activate(configuration: StartingWeaponConfiguration) {
        isCharging = true
        chargeTimeRemaining = max(0, configuration.powerWaveChargeDuration)
        waveState = nil
    }

    mutating func reset() {
        isCharging = false
        chargeTimeRemaining = 0
        waveState = nil
    }

    mutating func update(
        deltaTime: TimeInterval,
        playerPosition: CGPoint,
        direction: CGVector,
        playableRect: CGRect,
        enemies: [ArenaEnemy],
        configuration: StartingWeaponConfiguration
    ) -> PowerWaveFrame {
        var remainingDelta = max(0, deltaTime)
        var release: PowerWaveRelease?

        if isCharging {
            if chargeTimeRemaining > remainingDelta {
                chargeTimeRemaining -= remainingDelta
                return PowerWaveFrame(isCharging: true)
            }

            remainingDelta -= chargeTimeRemaining
            isCharging = false
            chargeTimeRemaining = 0

            let wave = PowerWaveWaveState(
                center: playerPosition,
                direction: direction,
                maximumRange: configuration.powerWaveRange,
                fanAngleDegrees: configuration.powerWaveFanAngleDegrees,
                expansionDuration: configuration.powerWaveExpansionDuration,
                playableRect: playableRect
            )
            waveState = wave
            release = PowerWaveRelease(
                center: wave.center,
                direction: wave.direction,
                travelDistance: wave.travelDistance
            )
        }

        guard var activeWaveState = waveState else {
            return PowerWaveFrame(release: release, isComplete: !isActive)
        }

        let waveFrame = activeWaveState.update(deltaTime: remainingDelta, enemies: enemies)
        waveState = waveFrame.isComplete ? nil : activeWaveState

        return PowerWaveFrame(
            destroyedEnemyIDs: waveFrame.destroyedEnemyIDs,
            release: release,
            radius: waveFrame.radius,
            isCharging: false,
            isComplete: !isActive
        )
    }
}

struct PowerWaveWaveFrame: Equatable {
    let destroyedEnemyIDs: Set<Int>
    let radius: CGFloat
    let isComplete: Bool
}

struct PowerWaveWaveState: Equatable {
    let center: CGPoint
    let direction: CGVector
    let maximumRange: CGFloat
    let fanAngleRadians: CGFloat
    let travelSpeed: CGFloat
    let travelDistance: CGFloat
    private(set) var elapsedTime: TimeInterval = 0
    private var destroyedEnemyIDs: Set<Int> = []

    init(
        center: CGPoint,
        direction: CGVector,
        maximumRange: CGFloat,
        fanAngleDegrees: CGFloat,
        expansionDuration: TimeInterval,
        playableRect: CGRect
    ) {
        self.center = center
        self.direction = direction.length > 0 ? direction.normalized : CGVector(dx: 0, dy: 1)
        self.maximumRange = max(0, maximumRange)
        self.fanAngleRadians = min(360, max(0, fanAngleDegrees)) * .pi / 180
        let clampedDuration = max(0.001, expansionDuration)
        travelSpeed = max(0, maximumRange) / CGFloat(clampedDuration)
        travelDistance = Self.resolvedTravelDistance(
            from: center,
            direction: self.direction,
            playableRect: playableRect,
            waveDepth: max(0, maximumRange)
        )
    }

    var isComplete: Bool {
        currentRadius >= travelDistance && elapsedTime > 0
    }

    mutating func update(deltaTime: TimeInterval, enemies: [ArenaEnemy]) -> PowerWaveWaveFrame {
        guard !isComplete else {
            return PowerWaveWaveFrame(
                destroyedEnemyIDs: [],
                radius: currentRadius,
                isComplete: true
            )
        }

        elapsedTime += max(0, deltaTime)

        let radius = currentRadius
        let newlyDestroyedEnemyIDs = Set(
            enemies
                .filter { !destroyedEnemyIDs.contains($0.id) && intersectsFan($0, radius: radius) }
                .map(\.id)
        )
        destroyedEnemyIDs.formUnion(newlyDestroyedEnemyIDs)

        return PowerWaveWaveFrame(
            destroyedEnemyIDs: newlyDestroyedEnemyIDs,
            radius: radius,
            isComplete: isComplete
        )
    }

    private var currentRadius: CGFloat {
        guard travelSpeed > 0 else {
            return travelDistance
        }

        return min(travelDistance, travelSpeed * CGFloat(max(0, elapsedTime)))
    }

    private func intersectsFan(_ enemy: ArenaEnemy, radius: CGFloat) -> Bool {
        guard radius > 0 else {
            return false
        }

        let toEnemy = CGVector(
            dx: enemy.position.x - center.x,
            dy: enemy.position.y - center.y
        )
        let distanceToCenter = toEnemy.length
        let enemyRadius = max(0, enemy.radius)
        let projection = toEnemy.dx * direction.dx + toEnemy.dy * direction.dy
        let trailingDistance = max(0, radius - maximumRange)

        guard projection + enemyRadius >= trailingDistance, projection - enemyRadius <= radius else {
            return false
        }

        guard distanceToCenter > enemyRadius else {
            return true
        }

        let normalizedTarget = toEnemy.normalized
        let dotProduct = max(
            -1,
            min(1, normalizedTarget.dx * direction.dx + normalizedTarget.dy * direction.dy)
        )
        let angleToCenter = acos(dotProduct)
        let radiusAngleAllowance = asin(min(1, enemyRadius / max(distanceToCenter, enemyRadius)))

        return angleToCenter <= fanAngleRadians / 2 + radiusAngleAllowance
    }

    private static func resolvedTravelDistance(
        from center: CGPoint,
        direction: CGVector,
        playableRect: CGRect,
        waveDepth: CGFloat
    ) -> CGFloat {
        guard playableRect.width > 0, playableRect.height > 0 else {
            return max(0, waveDepth)
        }

        let corners = [
            CGPoint(x: playableRect.minX, y: playableRect.minY),
            CGPoint(x: playableRect.minX, y: playableRect.maxY),
            CGPoint(x: playableRect.maxX, y: playableRect.minY),
            CGPoint(x: playableRect.maxX, y: playableRect.maxY)
        ]
        let farthestProjection = corners
            .map { point in
                let offset = CGVector(dx: point.x - center.x, dy: point.y - center.y)
                return offset.dx * direction.dx + offset.dy * direction.dy
            }
            .max() ?? 0

        return max(0, farthestProjection) + max(0, waveDepth)
    }
}
