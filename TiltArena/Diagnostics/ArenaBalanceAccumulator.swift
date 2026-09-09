import Foundation

/// Fixed-size aggregates: no retained pickup IDs, activations, or movement samples.
struct ArenaBalanceAccumulator {
    struct CollectedPickup {
        let kind: WeaponKind
        let tier: WeaponPickupChargeTier
        let time: TimeInterval
    }
    let runID = UUID()
    private(set) var weapons: [WeaponKind: WeaponBalanceTotals] = [:]
    private(set) var spawned: [EnemyKind: Int] = [:]
    private(set) var peakActiveEnemies = 0
    private(set) var peakReservedEnemies = 0
    private(set) var capacityGateSeconds: TimeInterval = 0
    private(set) var warningGateSeconds: TimeInterval = 0
    private(set) var roleGateSeconds: TimeInterval = 0
    private(set) var protectedSeconds: TimeInterval = 0
    private(set) var shieldSeconds: TimeInterval = 0
    private(set) var freezeSeconds: TimeInterval = 0
    private(set) var gravitySeconds: TimeInterval = 0
    private(set) var slowSeconds: TimeInterval = 0
    private(set) var lastPickup: CollectedPickup?
    var deathRole: EnemyKind?

    mutating func recordPickup(_ pickup: WeaponPickup, at time: TimeInterval) -> WeaponActivation {
        var totals = weapons[pickup.kind, default: WeaponBalanceTotals()]
        totals.pickups[pickup.chargeTier.rawValue] += 1
        totals.ageSeconds += finiteDuration(pickup.timeOnScreen)
        totals.killDistribution[0] += 1
        weapons[pickup.kind] = totals
        lastPickup = CollectedPickup(kind: pickup.kind, tier: pickup.chargeTier, time: finiteDuration(time))
        return WeaponActivation(kind: pickup.kind, chargeTier: pickup.chargeTier, measurementRunID: runID)
    }

    mutating func recordKills(_ activation: WeaponActivation, previousCount: Int) {
        guard activation.measurementRunID == runID, var totals = weapons[activation.kind] else { return }
        let increment = max(0, activation.killCount - previousCount)
        totals.kills[activation.chargeTier.rawValue] += increment
        totals.killDistribution[WeaponBalanceTotals.killBucket(previousCount)] -= 1
        totals.killDistribution[WeaponBalanceTotals.killBucket(activation.killCount)] += 1
        totals.maximumKills = max(totals.maximumKills, activation.killCount)
        weapons[activation.kind] = totals
    }

    mutating func recordSpawns(_ enemies: [ArenaEnemy]) {
        for enemy in enemies {
            spawned[enemy.behavior.kind, default: 0] += 1
        }
    }

    mutating func recordPopulation(active: Int, pending: Int) {
        peakActiveEnemies = max(peakActiveEnemies, active)
        peakReservedEnemies = max(peakReservedEnemies, active + pending)
    }

    mutating func recordGates(_ gates: EnemySpawnCapacityGates, deltaTime: TimeInterval) {
        let duration = finiteDuration(deltaTime)
        if gates.enemy { capacityGateSeconds += duration }
        if gates.warning { warningGateSeconds += duration }
        if gates.role { roleGateSeconds += duration }
    }

    /// Integrate the state at the beginning of the gameplay step. Effects acquired
    /// at its end begin contributing next step. Simultaneous immunity intervals form a union.
    mutating func recordExposure(deltaTime: TimeInterval, weapons: ArenaActiveWeaponState, enemies: [ArenaEnemy]) {
        let duration = finiteDuration(deltaTime)
        let flame = weapons.flameTrailProtection
        protectedSeconds += min(duration, max(
            weapons.postWeaponSafety.timeRemaining,
            flame.speedBoostTimeRemaining + flame.invulnerabilityTimeRemaining
        ))
        shieldSeconds += min(duration, weapons.razorShield.timeRemaining)
        slowSeconds += min(duration, weapons.timeDilation.timeRemaining)
        freezeSeconds += min(duration, enemies.map(\.frozenTimeRemaining).max() ?? 0)
        if var gravity = weapons.gravityWell {
            gravitySeconds += gravity.consumePullDelta(deltaTime: duration)
        }
    }

    private func finiteDuration(_ value: TimeInterval) -> TimeInterval {
        value.isFinite ? max(0, value) : 0
    }
}

struct WeaponBalanceTotals: Equatable {
    // Tier order is base, charged, overcharged. Distribution is 0, 1, 2–4, 5–9, 10+ kills.
    var pickups = [0, 0, 0]
    var kills = [0, 0, 0]
    var killDistribution = [0, 0, 0, 0, 0]
    var maximumKills = 0
    var ageSeconds: TimeInterval = 0

    static func killBucket(_ count: Int) -> Int {
        switch count {
        case ...0: return 0
        case 1: return 1
        case 2...4: return 2
        case 5...9: return 3
        default: return 4
        }
    }
}
