import CoreGraphics
import Foundation
@testable import TiltArena

enum ArenaBalanceEncounter: String, CaseIterable {
    case sparseChasers, densePack, crossingFormation, contestedMines, mixedThreats, latePressure
    case approachingThreat, aimingLane

    static let matrixCases: [Self] = [.sparseChasers, .densePack, .crossingFormation, .contestedMines, .mixedThreats, .latePressure]

    func enemies(center: CGPoint, seed: Int) -> [ArenaEnemy] {
        let phase = Double(seed % 17) / 17 * .pi * 2
        switch self {
        case .approachingThreat:
            return [ArenaEnemy(id: 10_000, position: CGPoint(x: center.x + 60, y: center.y), radius: 7, speed: 70)]
        case .aimingLane:
            return (0..<6).map { index in
                ArenaEnemy(id: 10_000 + index,
                           position: CGPoint(x: center.x + 110 + CGFloat(index % 3) * 25,
                                             y: center.y - 18 + CGFloat(index / 3) * 36), radius: 7, speed: 30)
            }
        case .sparseChasers:
            return ring(count: 6, radius: 135, speed: 55, center: center, phase: phase)
        case .densePack:
            return (0..<40).map { index in
                ArenaEnemy(id: 10_000 + index,
                           position: CGPoint(x: center.x + 48 + CGFloat(index % 8) * 15,
                                             y: center.y - 40 + CGFloat(index / 8) * 20), radius: 7, speed: 65)
            }
        case .crossingFormation:
            return (0..<12).map { index in
                ArenaEnemy(id: 10_000 + index,
                           position: CGPoint(x: center.x + 170, y: center.y - 132 + CGFloat(index) * 24),
                           radius: 8, speed: 95, behavior: .formationLine(velocity: CGVector(dx: -95, dy: 0), formationID: 1))
            }
        case .contestedMines:
            return ring(count: 8, radius: 60, speed: 0, center: center, phase: phase).map { enemy in
                var enemy = enemy
                enemy.behavior = .mineDot
                return enemy
            } + ring(count: 8, radius: 135, speed: 65, center: center, phase: phase + 0.2, firstID: 11_000)
        case .mixedThreats, .latePressure:
            let count = self == .mixedThreats ? 24 : 96
            let speed: CGFloat = self == .mixedThreats ? 70 : 105
            return mixedEnemies(count: count, speed: speed, center: center, phase: phase)
        }
    }

    private func mixedEnemies(count: Int, speed: CGFloat, center: CGPoint, phase: Double) -> [ArenaEnemy] {
        return (0..<count).map { index in
            let angle = phase + Double(index) * 2.399_963
            let radius: CGFloat = 70 + CGFloat(index % 6) * 13
            let position = CGPoint(x: center.x + cos(angle) * radius * 1.5, y: center.y + sin(angle) * radius * 0.85)
            let behavior: EnemyBehavior
            switch index % 8 {
            case 0: behavior = .mineDot
            case 1: behavior = .splitter
            case 2: behavior = .hunterDot(predictionLead: 0.35, previousTarget: nil)
            case 3:
                behavior = .paddleTrapDot(trapID: index, velocity: CGVector(dx: 90, dy: 65),
                                         bounds: CGRect(x: center.x - 260, y: center.y - 125, width: 520, height: 250),
                                         remainingLifetime: 18)
            default: behavior = .chaser
            }
            return ArenaEnemy(id: 10_000 + index, position: position, radius: 7, speed: speed, behavior: behavior)
        }
    }

    private func ring(count: Int, radius: CGFloat, speed: CGFloat, center: CGPoint, phase: Double, firstID: Int = 10_000)
        -> [ArenaEnemy] {
        (0..<count).map { index in
            let angle = phase + Double(index) * .pi * 2 / Double(count)
            return ArenaEnemy(id: firstID + index,
                              position: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius),
                              radius: 7, speed: speed)
        }
    }
}

enum ArenaBalanceRoute: String, CaseIterable {
    case orbit, reverse, steadyAim

    static let matrixCases: [Self] = [.orbit, .reverse]

    func input(at time: TimeInterval) -> CGVector {
        switch self {
        case .steadyAim:
            return time < 2 ? CGVector(dx: 0.25, dy: 0) : CGVector(dx: cos(time), dy: sin(time) * 0.8)
        case .orbit:
            return CGVector(dx: cos(time * 1.3), dy: sin(time * 1.3) * 0.8)
        case .reverse:
            let direction: CGFloat = Int(time / 1.2).isMultiple(of: 2) ? 1 : -1
            return CGVector(dx: direction, dy: sin(time * 2.1) * 0.6)
        }
    }
}

enum ArenaBalanceVariant: String, CaseIterable {
    case baseline, shortFreeze, shortFlame, quickPower, fastShockwave, fastFreeze, responsiveShockwave, responsiveFreeze

    static let initialMatrixCases: [Self] = [.baseline, .shortFreeze, .shortFlame, .quickPower]

    func applies(to weapon: WeaponKind?) -> Bool {
        switch self {
        case .baseline: return true
        case .shortFreeze: return weapon == .freezeBurst
        case .shortFlame: return weapon == .flameTrail
        case .quickPower: return weapon == .powerWave
        case .fastShockwave, .responsiveShockwave: return weapon == .shockwave
        case .fastFreeze, .responsiveFreeze: return weapon == .freezeBurst
        }
    }

    var tuning: GameTuningConfiguration {
        var tuning = GameTuningConfiguration.defaults
        // Preserve the reviewed pre-experiment values when a candidate becomes a default.
        tuning.startingWeapons.waveExpansionExponent = 1
        tuning.startingWeapons.shockwaveExpansionDuration = 0.6
        tuning.startingWeapons.freezeExpansionDuration = 0.8
        tuning.startingWeapons.freezeDuration = 12
        tuning.startingWeapons.powerWaveChargeDuration = 0.6
        tuning.flameTrail.duration = 0.3
        tuning.flameTrail.speedMultiplier = 5
        switch self {
        case .baseline: break
        case .shortFreeze: tuning.startingWeapons.freezeDuration = 8
        case .shortFlame:
            tuning.flameTrail.speedMultiplier = 4
            tuning.flameTrail.duration = 0.22
        case .quickPower: tuning.startingWeapons.powerWaveChargeDuration = 0.4
        case .fastShockwave: tuning.startingWeapons.shockwaveExpansionDuration = 0.24
        case .fastFreeze: tuning.startingWeapons.freezeExpansionDuration = 0.35
        case .responsiveShockwave, .responsiveFreeze: tuning.startingWeapons.waveExpansionExponent = 3
        }
        // Fixed initial populations isolate weapon effects. Keep production movement,
        // collision, splitting, culling and status rules; suppress replenishment in every phase.
        var phase = tuning.classic.enemySpawnConfiguration.warmup
        phase.chaserSpawnInterval = 0
        phase.formationSpawnInterval = nil
        tuning.classic.enemySpawnConfiguration.warmup = phase
        tuning.classic.enemySpawnConfiguration.pressure = phase
        tuning.classic.enemySpawnConfiguration.chaos = phase
        tuning.classic.enemySpawnConfiguration.survivalHell = phase
        tuning.classic.pickupSpawnConfiguration.maxActivePickups = 0
        return tuning
    }
}

struct ArenaBalanceResult: Codable, Equatable {
    let encounter: String
    let route: String
    let seed: Int
    let weapon: String
    let tier: Int
    let variant: String
    let framesPerSecond: Int
    let durationLimit: TimeInterval
    let observedSeconds: TimeInterval
    let collision: Bool
    let deathRole: String
    let score: Int
    let kills: Int
    let initialEnemies: Int
    let remainingEnemies: Int
    let protectedSeconds: TimeInterval
    let shieldSeconds: TimeInterval
    let freezeSeconds: TimeInterval
    let gravitySeconds: TimeInterval
    let slowSeconds: TimeInterval
    let openRouteFraction: Double
    let distanceTravelled: CGFloat
    let earlyDisplacement: CGFloat
}

struct ArenaBalanceMotionSamples {
    var openRays = 0
    var rayCount = 0
    var distance: CGFloat = 0
    var earlyDisplacement: CGFloat = 0

    @MainActor
    mutating func sample(scene: ArenaScene, previousPosition: CGPoint, start: CGPoint, time: TimeInterval) {
        let position = scene.playerPositionForTesting
        distance += hypot(position.x - previousPosition.x, position.y - previousPosition.y)
        if time <= 0.5 { earlyDisplacement = max(earlyDisplacement, hypot(position.x - start.x, position.y - start.y)) }
        let circle = CollisionCircle(center: position, radius: ClassicRunConfiguration().playerHitRadius)
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let end = CGPoint(x: position.x + cos(angle) * 80, y: position.y + sin(angle) * 80)
            rayCount += 1
            guard scene.currentPlayableRect.contains(end) else { continue }
            let obstructed = scene.enemiesForTesting.contains { enemy in
                enemy.canDamagePlayer && circle.firstIntersectionTimeDuringMovement(
                    from: end, with: enemy.collisionCircle, movingFrom: enemy.position
                ) != nil
            }
            if !obstructed { openRays += 1 }
        }
    }
}

struct ArenaBalanceCase {
    var encounter: ArenaBalanceEncounter = .sparseChasers
    var route: ArenaBalanceRoute = .orbit
    var weapon: WeaponKind? = .shockwave
    var tier: WeaponPickupChargeTier = .base
    var variant: ArenaBalanceVariant = .baseline
    var seed = 91
    var framesPerSecond = 60
    var duration: TimeInterval = 18
}
