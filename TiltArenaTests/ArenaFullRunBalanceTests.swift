import XCTest
@testable import TiltArena

enum BalanceProfile: String, CaseIterable {
    case fresh, partial, complete

    var profile: RunProfile {
        var profile = RunProfile()
        switch self {
        case .fresh: break
        case .partial:
            profile.totalEnemiesDestroyed = 200
            profile.lifetimeBestScore = 2_000
            profile.lifetimeHighestCombo = 22
        case .complete:
            profile.totalEnemiesDestroyed = 400
            profile.lifetimeBestScore = 10_000
            profile.lifetimeHighestCombo = 35
        }
        profile.unlockedWeapons = Set(ArenaProgressionRules.unlockedWeapons(for: profile))
        return profile
    }
}

enum BalancePickupPolicy: String, CaseIterable {
    case cycle, bankNova, parkTwo

    func target(pickups: [WeaponPickup], player: CGPoint, parkedIDs: inout Set<Int>) -> WeaponPickup? {
        parkedIDs.formIntersection(pickups.map(\.id))
        if self == .parkTwo, pickups.count >= 3, parkedIDs.count < 2 {
            let unwanted = pickups.sorted { priority($0.kind) > priority($1.kind) }
            for pickup in unwanted where parkedIDs.count < 2 { parkedIDs.insert(pickup.id) }
        }
        let eligible = pickups.filter { pickup in
            !parkedIDs.contains(pickup.id)
                && (self != .bankNova || pickup.kind != .novaBomb || pickup.chargeTier == .overcharged)
        }
        return eligible.min { first, second in
            return ArenaGeometry.squaredDistance(from: player, to: first.position)
                < ArenaGeometry.squaredDistance(from: player, to: second.position)
        }
    }

    private func priority(_ kind: WeaponKind) -> Int {
        switch kind {
        case .razorShield: return 0
        case .seekerSwarm: return 1
        case .shockwave: return 2
        case .freezeBurst: return 3
        case .novaBomb: return 4
        default: return 5
        }
    }
}

enum BalanceRunVariant: String, CaseIterable {
    case reference, shorterFreeze, shorterFlame, widerCombo, earlierClassic, shorterSafety, clearingScore

    var tuning: GameTuningConfiguration {
        var tuning = GameTuningConfiguration.defaults
        tuning.startingWeapons.waveExpansionExponent = 3
        tuning.startingWeapons.powerWaveChargeDuration = 0.4
        tuning.startingWeapons.freezeDuration = 12
        tuning.flameTrail.duration = 0.3
        tuning.flameTrail.speedMultiplier = 5
        tuning.run.comboWindow = 1.2
        tuning.run.itemPickupScore = 50
        tuning.feedback.postWeaponSafetyDuration = 0.5
        tuning.classic.enemySpawnConfiguration.formationMinimumSurvivalTime = 30
        tuning.classic.enemySpawnConfiguration.splitterMinimumSurvivalTime = 50
        tuning.classic.enemySpawnConfiguration.mineDotMinimumSurvivalTime = 70
        tuning.classic.enemySpawnConfiguration.arrowRushMinimumSurvivalTime = 95
        tuning.classic.enemySpawnConfiguration.hunterDotMinimumSurvivalTime = 120
        tuning.classic.enemySpawnConfiguration.paddleTrapMinimumSurvivalTime = 150
        switch self {
        case .reference: break
        case .clearingScore:
            tuning.feedback.postWeaponSafetyDuration = 0.3
            tuning.run.itemPickupScore = 10
        case .shorterSafety: tuning.feedback.postWeaponSafetyDuration = 0.3
        case .shorterFreeze: tuning.startingWeapons.freezeDuration = 8
        case .shorterFlame:
            tuning.flameTrail.duration = 0.22
            tuning.flameTrail.speedMultiplier = 4
        case .widerCombo: tuning.run.comboWindow = 1.6
        case .earlierClassic:
            // A minimum-time gate alone cannot enable a role absent from that phase.
            tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval = 10
            tuning.classic.enemySpawnConfiguration.pressure.arrowRushSpawnInterval = 10
            tuning.classic.enemySpawnConfiguration.pressure.arrowRushSpeed = 150
            tuning.classic.enemySpawnConfiguration.pressure.arrowRushEnemyCount = 2
            tuning.classic.enemySpawnConfiguration.formationMinimumSurvivalTime = 20
            tuning.classic.enemySpawnConfiguration.splitterMinimumSurvivalTime = 40
            tuning.classic.enemySpawnConfiguration.mineDotMinimumSurvivalTime = 60
            tuning.classic.enemySpawnConfiguration.arrowRushMinimumSurvivalTime = 80
            tuning.classic.enemySpawnConfiguration.hunterDotMinimumSurvivalTime = 100
            tuning.classic.enemySpawnConfiguration.paddleTrapMinimumSurvivalTime = 120
        }
        return tuning
    }
}

struct BalanceRunResult: Codable, Equatable {
    let mode: String
    let profile: String
    let policy: String
    let variant: String
    let seed: Int
    let durationLimit: Double
    let observedSeconds: Double
    let collision: Bool
    let deathRole: String
    let score: Int
    let killScore: Int
    let pickupScore: Int
    let survivalScore: Int
    let maxCombo: Int
    let kills: Int
    let pickups: [String: Int]
    let tiers: [Int]
    let novaTiers: [Int]
    let pickupAgeSum: Double
    let parkedPickupsCollected: Int
    let protectedSeconds: Double
    let shieldSeconds: Double
    let synergies: Int
    let cascades: Int
    let spawned: [String: Int]
    let peakPopulation: Int
    let capacityGateSeconds: Double
    let warningGateSeconds: Double
}

@MainActor
final class ArenaFullRunBalanceTests: XCTestCase {
    func testEarlierPacingCandidateEnablesEachRoleAtItsAdvertisedGate() {
        let configuration = BalanceRunVariant.earlierClassic.tuning.classic.enemySpawnConfiguration
        let gates: [(TimeInterval, KeyPath<EnemyPhaseTuning, TimeInterval?>)] = [
            (20, \.formationSpawnInterval), (40, \.splitterSpawnInterval), (60, \.mineDotSpawnInterval),
            (80, \.arrowRushSpawnInterval), (100, \.hunterDotSpawnInterval), (120, \.paddleTrapSpawnInterval)
        ]
        for (time, interval) in gates {
            XCTAssertNil(configuration.tuning(at: time - 0.01)[keyPath: interval])
            XCTAssertNotNil(configuration.tuning(at: time)[keyPath: interval])
        }
        XCTAssertGreaterThan(configuration.tuning(at: 80).arrowRushSpeed, 0)
        XCTAssertGreaterThan(configuration.tuning(at: 80).arrowRushEnemyCount, 0)
    }

    func testParkingKeepsTwoOrbsWhenTheCyclingSlotIsEmpty() {
        let pickups = [WeaponKind.razorShield, .gravityWell, .powerWave].enumerated().map { index, kind in
            WeaponPickup(id: index, kind: kind, position: CGPoint(x: index * 30, y: 0), radius: 8)
        }
        var parked: Set<Int> = []
        XCTAssertEqual(BalancePickupPolicy.parkTwo.target(pickups: pickups, player: .zero, parkedIDs: &parked)?.id, 0)
        XCTAssertEqual(parked, [1, 2])
        XCTAssertNil(BalancePickupPolicy.parkTwo.target(pickups: Array(pickups.dropFirst()), player: .zero, parkedIDs: &parked))
    }
    func testDailyRunRemainsIndependentOfPersonalUnlocks() throws {
        let fresh = try run(profile: .fresh, mode: .daily, duration: 12)
        let complete = try run(profile: .complete, mode: .daily, duration: 12)
        XCTAssertEqual(fresh.pickups, complete.pickups)
        XCTAssertEqual(fresh.score, complete.score)
        XCTAssertEqual(fresh.kills, complete.kills)
        XCTAssertEqual(fresh.observedSeconds, complete.observedSeconds, accuracy: 0.001)
        XCTAssertEqual(fresh.spawned, complete.spawned)
    }

    func testAutoplayUsesReconciledProductionScoring() throws {
        let result = try run(duration: 20)
        XCTAssertEqual(result.score, result.killScore + result.pickupScore + result.survivalScore)
        XCTAssertGreaterThan(result.pickups.values.reduce(0, +), 0)
        XCTAssertLessThanOrEqual(result.protectedSeconds, result.observedSeconds + 0.001)
    }

    func testExportFullRunComparisons() throws {
        guard ProcessInfo.processInfo.environment["TILT_FULL_RUN_SWEEP"] == "1" else {
            throw XCTSkip("Set TILT_FULL_RUN_SWEEP=1 for full-run policy and tuning comparisons.")
        }
        var results: [BalanceRunResult] = []
        for seed in [7, 91, 20_260_726] {
            for policy in BalancePickupPolicy.allCases {
                for profile in BalanceProfile.allCases {
                    for variant in BalanceRunVariant.allCases {
                        results.append(try run(profile: profile, policy: policy, variant: variant, seed: seed))
                    }
                }
                for variant in [BalanceRunVariant.reference, .shorterSafety, .clearingScore] {
                    if policy != .parkTwo {
                        results.append(try run(profile: .complete, mode: .redline, policy: policy, variant: variant, seed: seed))
                    }
                    for profile in [BalanceProfile.fresh, .complete] {
                        results.append(try run(profile: profile, mode: .daily, policy: policy, variant: variant, seed: seed))
                    }
                }
            }
        }
        XCTAssertEqual(results.count, 261)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let attachment = XCTAttachment(data: try encoder.encode(results), uniformTypeIdentifier: "public.json")
        attachment.name = "full-run-comparisons.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func run(
        profile: BalanceProfile = .complete, mode: ArenaModeKind = .classic,
        policy: BalancePickupPolicy = .cycle, variant: BalanceRunVariant = .reference,
        seed: Int = 91, duration: TimeInterval = 180
    ) throws -> BalanceRunResult {
        try autoreleasepool {
            let harness = try ArenaBalanceHarness()
            defer { harness.close() }
            let scene = harness.scene
            scene.prepareBalanceRunForTesting(tuning: variant.tuning, seed: seed, profile: profile.profile, mode: mode)
            harness.step(at: 0)
            var parkedIDs: Set<Int> = []
            var parkedPickupsCollected = 0
            for frame in 1...Int(duration * 60) {
                scene.inputOverrideForTesting = steering(scene: scene, policy: policy, parkedIDs: &parkedIDs, time: Double(frame) / 60)
                let parkedBefore = parkedIDs
                harness.step(at: Double(frame) / 60)
                parkedPickupsCollected += parkedBefore.subtracting(scene.pickupsForTesting.map(\.id)).count
                if scene.isRunGameOverForTesting { break }
            }
            return result(scene: scene, profile: profile, mode: mode, policy: policy, variant: variant,
                          seed: seed, duration: duration, parkedPickupsCollected: parkedPickupsCollected)
        }
    }

    // This deterministic, deliberately simple controller is a comparison instrument, not a model of human skill.
    private func steering(scene: ArenaScene, policy: BalancePickupPolicy, parkedIDs: inout Set<Int>, time: Double) -> CGVector {
        let player = scene.playerPositionForTesting
        let bounds = scene.currentPlayableRect
        let target = policy.target(pickups: scene.pickupsForTesting, player: player, parkedIDs: &parkedIDs)?.position
            ?? CGPoint(x: bounds.midX + cos(time) * 80, y: bounds.midY + sin(time) * 50)
        var vector = CGVector(dx: target.x - player.x, dy: target.y - player.y).normalized(or: .zero)
        for enemy in scene.enemiesForTesting where enemy.canDamagePlayer {
            let distance = hypot(player.x - enemy.position.x, player.y - enemy.position.y)
            guard distance < 105, distance > 0 else { continue }
            let strength = pow((105 - distance) / 105, 2) * 3
            vector.dx += (player.x - enemy.position.x) / distance * strength
            vector.dy += (player.y - enemy.position.y) / distance * strength
        }
        vector.dx += max(0, 30 - (player.x - bounds.minX)) / 30 - max(0, 30 - (bounds.maxX - player.x)) / 30
        vector.dy += max(0, 30 - (player.y - bounds.minY)) / 30 - max(0, 30 - (bounds.maxY - player.y)) / 30
        return vector.normalized(or: .zero)
    }

    // swiftlint:disable:next function_parameter_count
    private func result(scene: ArenaScene, profile: BalanceProfile, mode: ArenaModeKind, policy: BalancePickupPolicy,
                        variant: BalanceRunVariant, seed: Int, duration: TimeInterval, parkedPickupsCollected: Int) -> BalanceRunResult {
        let totals = scene.balanceForTesting
        let scores = scene.scoreBreakdownForTesting
        return BalanceRunResult(
            mode: mode.rawValue, profile: profile.rawValue, policy: policy.rawValue, variant: variant.rawValue, seed: seed,
            durationLimit: duration, observedSeconds: scene.runSurvivalTimeForTesting, collision: scene.isRunGameOverForTesting,
            deathRole: totals.deathRole?.rawValue ?? "none",
            score: scene.scoreForTesting, killScore: scores.kills, pickupScore: scores.pickups, survivalScore: scores.survival,
            maxCombo: scene.maxComboForTesting, kills: scene.enemiesDestroyedForTesting,
            pickups: Dictionary(uniqueKeysWithValues: totals.weapons.map { ($0.key.rawValue, $0.value.pickups.reduce(0, +)) }),
            tiers: (0..<3).map { tier in totals.weapons.values.reduce(0) { $0 + $1.pickups[tier] } },
            novaTiers: totals.weapons[.novaBomb]?.pickups ?? [0, 0, 0],
            pickupAgeSum: totals.weapons.values.reduce(0) { $0 + $1.ageSeconds }, parkedPickupsCollected: parkedPickupsCollected,
            protectedSeconds: totals.protectedSeconds, shieldSeconds: totals.shieldSeconds,
            synergies: totals.synergies, cascades: totals.cascades,
            spawned: Dictionary(uniqueKeysWithValues: totals.spawned.map { ($0.key.rawValue, $0.value) }),
            peakPopulation: totals.peakReservedEnemies, capacityGateSeconds: totals.capacityGateSeconds,
            warningGateSeconds: totals.warningGateSeconds
        )
    }
}
