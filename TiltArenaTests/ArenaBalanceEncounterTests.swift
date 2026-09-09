import Metal
import SpriteKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaBalanceEncounterTests: XCTestCase {
    func testInjectedEnemiesReserveIDsForProductionSplitterChildren() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        harness.scene.prepareBalanceRunForTesting(tuning: ArenaBalanceVariant.baseline.tuning, seed: 91)
        let center = harness.scene.playerPositionForTesting
        harness.scene.seedBalanceEnemiesForTesting([
            ArenaEnemy(id: 100, position: CGPoint(x: center.x + 100, y: center.y), radius: 8, speed: 0, behavior: .splitter),
            ArenaEnemy(id: 101, position: CGPoint(x: center.x - 100, y: center.y), radius: 8, speed: 0),
            ArenaEnemy(id: 102, position: CGPoint(x: center.x, y: center.y + 100), radius: 8, speed: 0)
        ])
        harness.scene.destroyEnemiesForTesting(ids: [100], weaponKind: .shockwave)
        XCTAssertEqual(harness.scene.enemyIDsForTesting, [101, 102, 103, 104])
    }

    func testMatchedEncounterReproducesKillsMovementAndProtection() throws {
        let spec = ArenaBalanceCase(encounter: .densePack, weapon: .seekerSwarm, tier: .overcharged, duration: 3)
        let first = try run(spec)
        let second = try run(spec)
        XCTAssertEqual(first.kills, second.kills)
        XCTAssertEqual(first.score, second.score)
        XCTAssertEqual(first.collision, second.collision)
        XCTAssertEqual(first.distanceTravelled, second.distanceTravelled, accuracy: 0.001)
        XCTAssertEqual(first.protectedSeconds, second.protectedSeconds, accuracy: 0.001)
        XCTAssertGreaterThan(first.kills, 0)
    }

    func testAllWeaponsAndTiersHaveFiniteAccountedOutcomes() throws {
        for weapon in WeaponKind.allCases {
            for tier in [WeaponPickupChargeTier.base, .charged, .overcharged] {
                let result = try run(ArenaBalanceCase(weapon: weapon, tier: tier, duration: 2))
                XCTAssertTrue(result.observedSeconds.isFinite)
                XCTAssertGreaterThanOrEqual(result.kills, 0)
                XCTAssertLessThanOrEqual(result.protectedSeconds, result.observedSeconds + 0.001)
                XCTAssertTrue((0...1).contains(result.openRouteFraction))
            }
        }
    }

    func testExportMatchedWeaponComparisons() throws {
        guard ProcessInfo.processInfo.environment["TILT_WEAPON_SWEEP"] == "1" else {
            throw XCTSkip("Set TILT_WEAPON_SWEEP=1 to export the matched encounter matrix.")
        }
        var results: [ArenaBalanceResult] = []
        for encounter in ArenaBalanceEncounter.matrixCases {
            for route in ArenaBalanceRoute.matrixCases {
                for seed in [91, 20_260_726] {
                    results.append(try run(ArenaBalanceCase(encounter: encounter, route: route, weapon: nil, seed: seed)))
                    for weapon in WeaponKind.allCases {
                        for tier in [WeaponPickupChargeTier.base, .charged, .overcharged] {
                            for variant in ArenaBalanceVariant.initialMatrixCases where variant.applies(to: weapon) {
                                results.append(try run(ArenaBalanceCase(
                                    encounter: encounter, route: route, weapon: weapon, tier: tier, variant: variant, seed: seed
                                )))
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(results.count, 1_032)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let attachment = XCTAttachment(data: try encoder.encode(results), uniformTypeIdentifier: "public.json")
        attachment.name = "weapon-encounters.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExpandingDefensiveWavesResolveBeforeThePlayerOutrunsThem() throws {
        for (weapon, candidate) in [(WeaponKind.shockwave, ArenaBalanceVariant.responsiveShockwave), (.freezeBurst, .responsiveFreeze)] {
            let baseline = try run(ArenaBalanceCase(encounter: .approachingThreat, weapon: weapon, duration: 2))
            let changed = try run(ArenaBalanceCase(encounter: .approachingThreat, weapon: weapon, variant: candidate, duration: 2))
            XCTAssertTrue(baseline.collision, "The old wave should reproduce the closing-enemy collision")
            XCTAssertFalse(changed.collision, "The candidate must create the intended breathing room")
            XCTAssertGreaterThan(changed.kills, baseline.kills)
        }
    }

    func testPowerRemainsAnAimedClearWithShorterCharge() throws {
        for framesPerSecond in [30, 60, 120] {
            let baseline = try run(ArenaBalanceCase(encounter: .aimingLane, route: .steadyAim, weapon: .powerWave,
                                                   framesPerSecond: framesPerSecond, duration: 2))
            let changed = try run(ArenaBalanceCase(encounter: .aimingLane, route: .steadyAim, weapon: .powerWave,
                                                  variant: .quickPower, framesPerSecond: framesPerSecond, duration: 2))
            XCTAssertGreaterThan(baseline.kills, 0)
            XCTAssertGreaterThanOrEqual(changed.kills, baseline.kills)
            XCTAssertFalse(changed.collision)
        }
    }

    func testExportResponseTimeComparisons() throws {
        guard ProcessInfo.processInfo.environment["TILT_RESPONSE_SWEEP"] == "1" else {
            throw XCTSkip("Set TILT_RESPONSE_SWEEP=1 for defensive-wave and aimed-charge comparisons.")
        }
        var results: [ArenaBalanceResult] = []
        for encounter in ArenaBalanceEncounter.allCases {
            for route in ArenaBalanceRoute.allCases {
                for seed in [91, 20_260_726] {
                    for tier in [WeaponPickupChargeTier.base, .charged, .overcharged] {
                        for (weapon, candidate) in [(WeaponKind.shockwave, ArenaBalanceVariant.responsiveShockwave),
                                                    (.freezeBurst, .responsiveFreeze), (.powerWave, .quickPower)] {
                            for variant in [ArenaBalanceVariant.baseline, candidate] {
                                results.append(try run(ArenaBalanceCase(encounter: encounter, route: route, weapon: weapon,
                                                                        tier: tier, variant: variant, seed: seed)))
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(results.count, 864)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let attachment = XCTAttachment(data: try encoder.encode(results), uniformTypeIdentifier: "public.json")
        attachment.name = "wavefront-encounters.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRendererAdvancesRealProjectileImpactsAndSceneClock() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        var tuning = GameTuningConfiguration.defaults
        tuning.classic.pickupSpawnConfiguration.maxActivePickups = 0
        tuning.classic.enemySpawnConfiguration.warmup.chaserSpawnInterval = 0
        tuning.classic.enemySpawnConfiguration.pressure.chaserSpawnInterval = 0
        harness.scene.prepareBalanceRunForTesting(tuning: tuning, seed: 91)
        let center = harness.scene.playerPositionForTesting
        harness.scene.addEnemyForTesting(ArenaEnemy(
            id: 100, position: CGPoint(x: center.x + 100, y: center.y), radius: 8, speed: 0
        ))
        harness.step(at: 0)
        harness.scene.collectWeaponForTesting(.seekerSwarm)
        XCTAssertEqual(harness.scene.enemiesForTesting.count, 1)
        for frame in 1...120 { harness.step(at: Double(frame) / 60) }
        XCTAssertEqual(harness.scene.runSurvivalTimeForTesting, 2, accuracy: 0.001)
        XCTAssertTrue(harness.scene.enemiesForTesting.isEmpty)
        XCTAssertEqual(harness.scene.balanceForTesting.weapons[.seekerSwarm]?.kills, [1, 0, 0])
    }

    private func run(_ spec: ArenaBalanceCase) throws -> ArenaBalanceResult {
        try autoreleasepool {
            let harness = try ArenaBalanceHarness()
            defer { harness.close() }
            return harness.run(spec)
        }
    }
}

@MainActor
final class ArenaBalanceHarness {
    let scene: ArenaScene
    let renderer: SKRenderer
    private let suite: String
    private let defaults: UserDefaults
    private let timeOrigin = ceil(ProcessInfo.processInfo.systemUptime) + 1

    init() throws {
        suite = "ArenaBalanceEncounter.\(UUID())"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        scene = ArenaScene(
            size: CGSize(width: 718, height: 377),
            tiltSettingsStore: TiltSettingsStore(defaults: defaults),
            runProfileStore: RunProfileStore(defaults: defaults),
            localOptionsStore: ArenaLocalOptionsStore(defaults: defaults),
            gameTuningStore: GameTuningStore(defaults: defaults),
            gameCenterReporter: NoopGameCenterClient()
        )
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        renderer = SKRenderer(device: device)
        renderer.scene = scene
        scene.inputOverrideForTesting = .zero
    }

    func step(at time: TimeInterval) {
        renderer.update(atTime: timeOrigin + time)
    }

    func run(_ spec: ArenaBalanceCase) -> ArenaBalanceResult {
        scene.prepareBalanceRunForTesting(tuning: spec.variant.tuning, seed: spec.seed)
        let start = scene.playerPositionForTesting
        let initial = spec.encounter.enemies(center: start, seed: spec.seed)
        scene.seedBalanceEnemiesForTesting(initial)
        scene.inputOverrideForTesting = spec.route.input(at: 0)
        step(at: 0)
        // Prime the same initial aim for every weapon through the production movement path.
        step(at: 1 / Double(spec.framesPerSecond))
        if let weapon = spec.weapon { scene.collectWeaponForTesting(weapon, tier: spec.tier) }
        var samples = ArenaBalanceMotionSamples()
        for frame in 2...Int(spec.duration * Double(spec.framesPerSecond)) {
            let time = Double(frame) / Double(spec.framesPerSecond)
            let previous = scene.playerPositionForTesting
            scene.inputOverrideForTesting = spec.route.input(at: time)
            step(at: time)
            samples.sample(scene: scene, previousPosition: previous, start: start, time: time)
            if scene.isRunGameOverForTesting { break }
        }
        let totals = scene.balanceForTesting
        return ArenaBalanceResult(
            encounter: spec.encounter.rawValue, route: spec.route.rawValue, seed: spec.seed,
            weapon: spec.weapon?.rawValue ?? "none", tier: spec.tier.rawValue, variant: spec.variant.rawValue,
            framesPerSecond: spec.framesPerSecond, durationLimit: spec.duration, observedSeconds: scene.runSurvivalTimeForTesting,
            collision: scene.isRunGameOverForTesting, deathRole: totals.deathRole?.rawValue ?? "none",
            score: scene.scoreForTesting, kills: totals.weapons.values.reduce(0) { $0 + $1.kills.reduce(0, +) },
            initialEnemies: initial.count, remainingEnemies: scene.enemiesForTesting.count,
            protectedSeconds: totals.protectedSeconds, shieldSeconds: totals.shieldSeconds,
            freezeSeconds: totals.freezeSeconds, gravitySeconds: totals.gravitySeconds, slowSeconds: totals.slowSeconds,
            openRouteFraction: Double(samples.openRays) / Double(max(1, samples.rayCount)),
            distanceTravelled: samples.distance, earlyDisplacement: samples.earlyDisplacement
        )
    }

    func close() {
        renderer.scene = nil
        defaults.removePersistentDomain(forName: suite)
    }
}
