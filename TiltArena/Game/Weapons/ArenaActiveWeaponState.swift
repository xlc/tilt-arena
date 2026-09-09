import CoreGraphics
import Foundation

struct ArenaRazorShieldState: Equatable {
    private(set) var activation: WeaponActivation?
    private(set) var timeRemaining: TimeInterval = 0
    private(set) var configuration: StartingWeaponConfiguration?
    private(set) var hasPlayedWarning = false

    var isActive: Bool {
        configuration != nil || timeRemaining > 0
    }

    mutating func activate(
        with incoming: StartingWeaponConfiguration,
        activation: WeaponActivation = WeaponActivation(kind: .razorShield)
    ) -> StartingWeaponConfiguration {
        self.activation = activation
        let resolved = configuration?.mergingRazorShield(with: incoming) ?? incoming
        configuration = resolved
        timeRemaining = max(timeRemaining, max(0, incoming.razorShieldDuration))
        hasPlayedWarning = false
        return resolved
    }

    func resolvedConfiguration(fallback: StartingWeaponConfiguration) -> StartingWeaponConfiguration {
        configuration ?? fallback
    }

    mutating func advance(by deltaTime: TimeInterval) {
        timeRemaining = max(0, timeRemaining - max(0, deltaTime))
    }

    mutating func claimWarningIfNeeded(leadTime: TimeInterval, isRunActive: Bool) -> Bool {
        guard
            !hasPlayedWarning,
            timeRemaining > 0,
            timeRemaining <= leadTime,
            isRunActive
        else {
            return false
        }

        hasPlayedWarning = true
        return true
    }

    mutating func clear() {
        activation = nil
        timeRemaining = 0
        configuration = nil
        hasPlayedWarning = false
    }
}

struct ArenaTimeDilationState: Equatable {
    private(set) var timeRemaining: TimeInterval = 0
    private(set) var configuration: StartingWeaponConfiguration?

    var isActive: Bool {
        configuration != nil || timeRemaining > 0
    }

    mutating func activate(with incoming: StartingWeaponConfiguration) -> StartingWeaponConfiguration {
        let resolved = configuration?.mergingTimeDilation(with: incoming) ?? incoming
        configuration = resolved
        timeRemaining = max(timeRemaining, max(0, incoming.timeDilationDuration))
        return resolved
    }

    func resolvedConfiguration(fallback: StartingWeaponConfiguration) -> StartingWeaponConfiguration {
        configuration ?? fallback
    }

    mutating func advance(by deltaTime: TimeInterval) -> Bool {
        guard timeRemaining > 0 else {
            return false
        }
        timeRemaining = max(0, timeRemaining - max(0, deltaTime))
        guard timeRemaining == 0 else {
            return false
        }
        clear()
        return true
    }

    func enemySpeedMultiplier(for enemy: ArenaEnemy, playerPosition: CGPoint) -> CGFloat {
        guard timeRemaining > 0, let configuration else {
            return 1
        }

        let radius = max(0, configuration.timeDilationRadius)
        guard radius > 0 else {
            return 1
        }

        let distance = hypot(enemy.position.x - playerPosition.x, enemy.position.y - playerPosition.y)
        guard distance < radius else {
            return 1
        }

        let closeness = 1 - min(1, max(0, distance / radius))
        let maximumSlowFactor = max(1, configuration.timeDilationMaximumSlowFactor)
        return 1 / (1 + closeness * (maximumSlowFactor - 1))
    }

    mutating func clear() {
        timeRemaining = 0
        configuration = nil
    }
}

struct ArenaFlameTrailProtectionState: Equatable {
    private(set) var speedBoostTimeRemaining: TimeInterval = 0
    private(set) var invulnerabilityTimeRemaining: TimeInterval = 0

    var isInvulnerable: Bool {
        speedBoostTimeRemaining > 0 || invulnerabilityTimeRemaining > 0
    }

    mutating func activate(configuration: FlameTrailConfiguration, postWeaponSafetyDuration: TimeInterval) {
        speedBoostTimeRemaining = max(speedBoostTimeRemaining, configuration.duration)
        invulnerabilityTimeRemaining = max(
            WeaponRuntimeSafetyLimits.duration(invulnerabilityTimeRemaining),
            configuration.invulnerabilityDuration,
            WeaponRuntimeSafetyLimits.duration(postWeaponSafetyDuration)
        )
    }

    mutating func advance(by deltaTime: TimeInterval) {
        speedBoostTimeRemaining = WeaponRuntimeSafetyLimits.duration(speedBoostTimeRemaining)
        invulnerabilityTimeRemaining = WeaponRuntimeSafetyLimits.duration(invulnerabilityTimeRemaining)
        let clampedDelta = deltaTime.isFinite ? max(0, deltaTime) : 0
        let boostDelta = min(speedBoostTimeRemaining, clampedDelta)

        speedBoostTimeRemaining -= boostDelta
        invulnerabilityTimeRemaining = max(
            0,
            invulnerabilityTimeRemaining - (clampedDelta - boostDelta)
        )
    }

    mutating func clear() {
        speedBoostTimeRemaining = 0
        invulnerabilityTimeRemaining = 0
    }
}

struct ArenaPostWeaponSafetyState: Equatable {
    private(set) var timeRemaining: TimeInterval = 0

    var isActive: Bool {
        timeRemaining > 0
    }

    mutating func grant(duration: TimeInterval) {
        timeRemaining = max(
            WeaponRuntimeSafetyLimits.duration(timeRemaining),
            WeaponRuntimeSafetyLimits.duration(duration)
        )
    }

    mutating func advance(by deltaTime: TimeInterval) {
        timeRemaining = WeaponRuntimeSafetyLimits.duration(timeRemaining)
        guard timeRemaining > 0 else {
            return
        }
        let deltaTime = deltaTime.isFinite ? max(0, deltaTime) : 0
        timeRemaining = max(0, timeRemaining - deltaTime)
    }

    mutating func clear() {
        timeRemaining = 0
    }
}

struct ArenaPendingNovaBombClear {
    var activation = WeaponActivation(kind: .novaBomb)
    let enemyIDs: Set<Int>
    var timeRemaining: TimeInterval
}

struct ArenaActiveWeaponState {
    var razorShield = ArenaRazorShieldState()
    var shockwaveWaves: [ShockwaveWaveState] = []
    var freezeBurstWaves: [FreezeBurstWaveState] = []
    var flameTrail = FlameTrailState()
    var flameTrailProtection = ArenaFlameTrailProtectionState()
    var postWeaponSafety = ArenaPostWeaponSafetyState()
    var pendingNovaBombClears: [ArenaPendingNovaBombClear] = []
    var gravityWell: GravityWellState?
    var aimDirection = AimDirectionState()
    var timeDilation = ArenaTimeDilationState()
    var powerWave = PowerWaveState()

    mutating func configure(flameTrail configuration: FlameTrailConfiguration) {
        flameTrail.configuration = configuration
    }

    mutating func reset() {
        razorShield.clear()
        shockwaveWaves.removeAll()
        freezeBurstWaves.removeAll()
        flameTrail.reset()
        flameTrailProtection.clear()
        postWeaponSafety.clear()
        pendingNovaBombClears.removeAll()
        gravityWell = nil
        aimDirection.reset()
        timeDilation.clear()
        powerWave.reset()
    }

    mutating func finishRun() {
        shockwaveWaves.removeAll()
        freezeBurstWaves.removeAll()
        powerWave.reset()
        flameTrailProtection.clear()
        postWeaponSafety.clear()
        pendingNovaBombClears.removeAll()
        timeDilation.clear()
    }
}
