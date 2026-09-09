import Logging
import XCTest
@testable import TiltArena

final class ArenaBalanceAccumulatorTests: XCTestCase {
    @MainActor
    func testCustomTuningDoesNotSaveRecordsOrReportGameCenterAndResetsForTheNextRun() throws {
        for startsCustom in [false, true] {
            let suite = "ArenaCustomRunTests.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = RunProfileStore(defaults: defaults)
            let tuningStore = GameTuningStore(defaults: defaults)
            if startsCustom {
                var tuning = GameTuningConfiguration.defaults
                tuning.run.itemPickupScore += 1
                tuningStore.tuning = tuning
            }
            let reporter = CustomRunReporter()
            let scene = ArenaScene(
                size: CGSize(width: 718, height: 377),
                tiltSettingsStore: TiltSettingsStore(defaults: defaults),
                runProfileStore: store,
                localOptionsStore: ArenaLocalOptionsStore(defaults: defaults),
                gameTuningStore: tuningStore,
                gameCenterReporter: reporter
            )
            scene.prepareActiveRunForTesting()
            scene.pauseRunForTesting()
            if !startsCustom { scene.adjustTuningParameterForTesting(id: "run.itemPickupScore", direction: .increase) }
            scene.adjustTuningParameterForTesting(id: "run.itemPickupScore", direction: .decrease)
            scene.resumeRunForTesting()
            scene.collectWeaponForTesting(.shockwave)
            scene.finishRunForTesting()

            XCTAssertEqual(store.profile, RunProfile())
            XCTAssertTrue(reporter.scores.isEmpty)
            XCTAssertTrue(reporter.events.isEmpty)
            if !startsCustom {
                let image = try SnapshotImageRenderer.render(scene: scene)
                let attachment = XCTAttachment(image: image)
                attachment.name = "custom-run-not-saved"
                attachment.lifetime = .keepAlways
                add(attachment)
            }

            scene.prepareActiveRunForTesting()
            scene.collectWeaponForTesting(.shockwave)
            scene.finishRunForTesting()
            XCTAssertEqual(store.profile.totalRuns, 1)
            XCTAssertEqual(reporter.scores.count, 1)
            XCTAssertFalse(reporter.events.isEmpty)
        }
    }

    @MainActor
    func testFamilyCountersFollowQualifiedClearsAndResetWithTheRun() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        let scene = harness.scene
        scene.prepareBalanceRunForTesting(tuning: .defaults, seed: 91)
        let first = WeaponActivation(kind: .shockwave)
        for (index, activation) in [first, WeaponActivation(kind: .seekerSwarm), WeaponActivation(kind: .razorShield)].enumerated() {
            let ids = Set([100 + index * 2, 101 + index * 2])
            for id in ids {
                scene.addEnemyForTesting(ArenaEnemy(id: id, position: .zero, radius: 5, speed: 0))
            }
            scene.destroyEnemiesForTesting(ids: ids, weaponKind: activation.kind, activation: activation)
        }
        XCTAssertEqual(scene.balanceForTesting.synergies, 1)
        XCTAssertEqual(scene.balanceForTesting.cascades, 1)
        scene.addEnemyForTesting(ArenaEnemy(id: 106, position: .zero, radius: 5, speed: 0))
        scene.destroyEnemiesForTesting(ids: [106], weaponKind: .shockwave, activation: first)
        XCTAssertEqual(scene.balanceForTesting.synergies, 1, "An old activation cannot earn another family event")
        XCTAssertEqual(scene.balanceForTesting.cascades, 1)
        scene.prepareActiveRunForTesting()
        XCTAssertEqual(scene.balanceForTesting.synergies, 0)
        XCTAssertEqual(scene.balanceForTesting.cascades, 0)
    }

    func testScoreBreakdownReconcilesActualAwardsAtSaturationAndRestart() {
        var configuration = ClassicRunConfiguration()
        configuration.baseEnemyScore = Int.max
        var run = ClassicRunController(configuration: configuration)
        run.start()
        run.recordItemPickup(pickupID: 1)
        run.recordItemPickup(pickupID: 1)
        run.update(deltaTime: 61)
        run.recordEnemyKills(count: 2, weaponKind: .shockwave)
        XCTAssertEqual(run.scoreBreakdown.pickups, 10)
        XCTAssertEqual(run.scoreBreakdown.survival, 1)
        XCTAssertEqual(run.scoreBreakdown.kills, Int.max - 11)
        XCTAssertEqual(run.scoreBreakdown.total, run.score)
        run.restart()
        XCTAssertEqual(run.scoreBreakdown, RunScoreBreakdown())
    }

    func testSurvivalOverflowCreditsOnlyRemainingScore() {
        var configuration = ClassicRunConfiguration()
        configuration.survivalBonusInterval = 1
        var run = ClassicRunController(configuration: configuration)
        run.start()
        run.recordEnemyKills(count: 1_000, weaponKind: .novaBomb)
        run.update(deltaTime: RunProfile.maximumPersistedSurvivalTime)
        XCTAssertEqual(run.scoreBreakdown.total, run.score)
        XCTAssertEqual(run.score, Int.max)
        XCTAssertEqual(run.scoreBreakdown.survival, Int.max - run.scoreBreakdown.kills)
    }

    func testActivationDistributionTracksDelayedKillsWithoutRetainingActivations() {
        var totals = ArenaBalanceAccumulator()
        var pickup = WeaponPickup(id: 1, kind: .shockwave, position: .zero, radius: 8)
        pickup.chargeTier = .overcharged
        pickup.timeOnScreen = 8
        let first = totals.recordPickup(pickup, at: 10)
        let second = totals.recordPickup(pickup, at: 11)
        _ = first.recordKills(1, minimum: 2)
        totals.recordKills(first, previousCount: 0)
        _ = first.recordKills(4, minimum: 2)
        totals.recordKills(first, previousCount: 1)
        _ = second.recordKills(12, minimum: 2)
        totals.recordKills(second, previousCount: 0)
        XCTAssertEqual(totals.weapons[.shockwave]?.pickups, [0, 0, 2])
        XCTAssertEqual(totals.weapons[.shockwave]?.kills, [0, 0, 17])
        XCTAssertEqual(totals.weapons[.shockwave]?.killDistribution, [0, 0, 0, 1, 1])
        XCTAssertEqual(totals.weapons[.shockwave]?.ageSeconds, 16)
        totals = ArenaBalanceAccumulator()
        totals.recordKills(first, previousCount: 1)
        XCTAssertTrue(totals.weapons.isEmpty, "Old-run callbacks cannot contaminate the next run")
    }

    func testExposureUnionsImmunityAndSeparatesShieldAndControl() {
        var totals = ArenaBalanceAccumulator()
        var weapons = ArenaActiveWeaponState()
        weapons.postWeaponSafety.grant(duration: 0.2)
        var flame = FlameTrailConfiguration()
        flame.duration = 0.3
        flame.invulnerabilityDuration = 0.5
        weapons.flameTrailProtection.activate(configuration: flame, postWeaponSafetyDuration: 0)
        var configuration = StartingWeaponConfiguration()
        configuration.razorShieldDuration = 4
        configuration.timeDilationDuration = 6
        _ = weapons.razorShield.activate(with: configuration)
        _ = weapons.timeDilation.activate(with: configuration)
        weapons.gravityWell = GravityWellState(center: .zero, timeRemaining: 3, activationDelayRemaining: 0.5)
        let enemy = ArenaEnemy(id: 1, position: .zero, radius: 8, speed: 0, frozenTimeRemaining: 0.6)
        totals.recordExposure(deltaTime: 1, weapons: weapons, enemies: [enemy, enemy])
        XCTAssertEqual(totals.protectedSeconds, 0.8, accuracy: 0.000_001)
        XCTAssertEqual(totals.shieldSeconds, 1)
        XCTAssertEqual(totals.slowSeconds, 1)
        XCTAssertEqual(totals.freezeSeconds, 0.6)
        XCTAssertEqual(totals.gravitySeconds, 0.5)
    }

    func testAllSummaryFieldsSurviveDiagnosticBounds() throws {
        var totals = ArenaBalanceAccumulator()
        for kind in WeaponKind.allCases {
            _ = totals.recordPickup(WeaponPickup(id: 1, kind: kind, position: .zero, radius: 8), at: 0)
        }
        var run = ClassicRunController()
        run.start()
        run.endRun()
        let events = totals.events(
            summary: try XCTUnwrap(run.finalizedSummary), score: run.scoreBreakdown,
            experimental: false, arenaSize: CGSize(width: 718, height: 377), unlockedWeapons: 11
        )
        XCTAssertEqual(events.count, 14)
        for event in events {
            XCTAssertLessThanOrEqual(event.metadata.count, DiagnosticLogLimits.maxMetadataEntries)
            let sanitized = DiagnosticMetadataSanitizer.sanitized(event.metadata)
            XCTAssertEqual(sanitized.count, event.metadata.count)
            XCTAssertFalse(sanitized.values.contains("<redacted>"))
        }
    }

    func testPopulationAndWarningGatesAreDistinctAndResetEachFrame() {
        var configuration = EnemySpawnConfiguration()
        configuration.warmup.maxActiveEnemies = 1
        var director = EnemySpawnDirector(configuration: configuration, sequenceSeed: 1)
        let rect = CGRect(x: 0, y: 0, width: 658, height: 317)
        let enemy = ArenaEnemy(id: 99, position: .zero, radius: 8, speed: 0)
        let capped = director.update(deltaTime: 0.1, survivalTime: 0, activeEnemies: [enemy],
                                     playableRect: rect, playerPosition: CGPoint(x: 329, y: 158), pickupCircles: [])
        XCTAssertTrue(capped.capacityGates.enemy)
        XCTAssertFalse(capped.capacityGates.warning)
        configuration.warmup.maxActiveEnemies = 100
        configuration.maxPendingSpawnWarnings = 1
        configuration.spawnWarningDuration = 10
        director = EnemySpawnDirector(configuration: configuration, sequenceSeed: 1)
        _ = director.update(deltaTime: 0.1, survivalTime: 0, activeEnemies: [],
                            playableRect: rect, playerPosition: CGPoint(x: 329, y: 158), pickupCircles: [])
        let warned = director.update(deltaTime: 0.1, survivalTime: 0.1, activeEnemies: [],
                                     playableRect: rect, playerPosition: CGPoint(x: 329, y: 158), pickupCircles: [])
        XCTAssertFalse(warned.capacityGates.enemy)
        XCTAssertTrue(warned.capacityGates.warning)
        let stopped = director.update(deltaTime: 0, survivalTime: 0.1, activeEnemies: [],
                                      playableRect: rect, playerPosition: .zero, pickupCircles: [])
        XCTAssertEqual(stopped.capacityGates, EnemySpawnCapacityGates())
        var totals = ArenaBalanceAccumulator()
        totals.recordGates(capped.capacityGates, deltaTime: 0.1)
        totals.recordGates(warned.capacityGates, deltaTime: 0.1)
        totals.recordPopulation(active: 5, pending: 7)
        XCTAssertEqual(totals.capacityGateSeconds, 0.1)
        XCTAssertEqual(totals.warningGateSeconds, 0.1)
        XCTAssertEqual(totals.peakReservedEnemies, 12)
    }

    @MainActor
    func testScenePauseDeathAndRestartKeepMeasurementsInTheirRun() throws {
        let suite = "ArenaBalanceTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let scene = ArenaScene(
            size: CGSize(width: 718, height: 377),
            tiltSettingsStore: TiltSettingsStore(defaults: defaults),
            runProfileStore: RunProfileStore(defaults: defaults),
            localOptionsStore: ArenaLocalOptionsStore(defaults: defaults),
            gameTuningStore: GameTuningStore(defaults: defaults),
            gameCenterReporter: NoopGameCenterClient()
        )
        scene.prepareActiveRunForTesting()
        let runID = scene.balanceForTesting.runID
        let position = scene.playerPositionForTesting
        for index in 0..<2 {
            scene.addEnemyForTesting(ArenaEnemy(
                id: 100 + index, position: CGPoint(x: position.x + 8 + CGFloat(index), y: position.y), radius: 3, speed: 0
            ))
        }
        scene.collectWeaponForTesting(.shockwave)
        scene.pauseRunForTesting()
        scene.updateActiveRunForTesting(deltaTime: 5)
        XCTAssertEqual(scene.balanceForTesting.protectedSeconds, 0)
        scene.resumeRunForTesting()
        scene.updateActiveRunForTesting(deltaTime: 0.1)
        XCTAssertEqual(scene.balanceForTesting.protectedSeconds, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(scene.balanceForTesting.weapons[.shockwave]?.kills, [2, 0, 0])
        scene.finishRunForTesting()
        scene.updateActiveRunForTesting(deltaTime: 5)
        XCTAssertEqual(scene.balanceForTesting.protectedSeconds, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(scene.scoreBreakdownForTesting.total, scene.scoreForTesting)
        scene.prepareActiveRunForTesting()
        XCTAssertNotEqual(scene.balanceForTesting.runID, runID)
        XCTAssertTrue(scene.balanceForTesting.weapons.isEmpty)
        XCTAssertEqual(scene.balanceForTesting.protectedSeconds, 0)
    }
}

@MainActor
private final class CustomRunReporter: GameCenterRunReporting {
    var scores: [RunSummary] = []
    var events: [GameCenterAchievementEvent] = []

    func submitRunScore(_ summary: RunSummary) { scores.append(summary) }
    func reportAchievementEvent(_ event: GameCenterAchievementEvent) { events.append(event) }
}
