import CoreGraphics
import Foundation

struct PowerWaveRelease: Equatable {
    let center: CGPoint
    let direction: CGVector
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
                expansionDuration: configuration.powerWaveExpansionDuration
            )
            waveState = wave
            release = PowerWaveRelease(center: wave.center, direction: wave.direction)
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
    let expansionDuration: TimeInterval
    private(set) var elapsedTime: TimeInterval = 0
    private var destroyedEnemyIDs: Set<Int> = []

    init(
        center: CGPoint,
        direction: CGVector,
        maximumRange: CGFloat,
        fanAngleDegrees: CGFloat,
        expansionDuration: TimeInterval
    ) {
        self.center = center
        self.direction = direction.length > 0 ? direction.normalized : CGVector(dx: 0, dy: 1)
        self.maximumRange = maximumRange
        self.fanAngleRadians = min(360, max(0, fanAngleDegrees)) * .pi / 180
        self.expansionDuration = expansionDuration
    }

    var isComplete: Bool {
        let clampedDuration = max(0, expansionDuration)
        return clampedDuration == 0 ? elapsedTime > 0 : elapsedTime >= clampedDuration
    }

    mutating func update(deltaTime: TimeInterval, enemies: [ArenaEnemy]) -> PowerWaveWaveFrame {
        guard !isComplete else {
            return PowerWaveWaveFrame(
                destroyedEnemyIDs: [],
                radius: currentRadius,
                isComplete: true
            )
        }

        let clampedDuration = max(0, expansionDuration)
        if clampedDuration == 0 {
            elapsedTime = 1
        } else {
            elapsedTime = min(clampedDuration, elapsedTime + max(0, deltaTime))
        }

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
        let clampedMaximumRange = max(0, maximumRange)
        let clampedDuration = max(0, expansionDuration)

        guard clampedDuration > 0 else {
            return clampedMaximumRange
        }

        let progress = min(1, max(0, elapsedTime / clampedDuration))
        return clampedMaximumRange * CGFloat(progress)
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

        guard distanceToCenter > enemyRadius else {
            return true
        }

        guard distanceToCenter - enemyRadius <= radius else {
            return false
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
}
