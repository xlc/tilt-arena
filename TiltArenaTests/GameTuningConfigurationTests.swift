import XCTest
@testable import TiltArena

final class GameTuningConfigurationTests: XCTestCase {
    func testAdjustingExtremeIntegerTuningDoesNotOverflow() {
        var tuning = GameTuningConfiguration.defaults
        tuning.startingWeapons.ricochetLanceMaximumBounces = .max

        tuning.adjustParameter(
            id: "startingWeapons.ricochetLanceMaximumBounces",
            direction: .increase
        )

        XCTAssertEqual(tuning.startingWeapons.ricochetLanceMaximumBounces, .max)
    }

    func testChargeBonusesSaturateOnlyAtIntegerRepresentationLimit() {
        let tuning = StartingWeaponConfiguration(seekerTargetLimit: .max, chainLightningTargetLimit: .max,
                                                 ricochetLanceMaximumBounces: .max).applying(chargeTier: .overcharged)
        XCTAssertEqual(tuning.seekerTargetLimit, .max)
        XCTAssertEqual(tuning.chainLightningTargetLimit, .max)
        XCTAssertEqual(tuning.ricochetLanceMaximumBounces, .max)
        XCTAssertEqual(FlameTrailConfiguration(maxSegments: .max).applying(chargeTier: .overcharged).maxSegments, .max)
    }

    func testSeekerCatalogValuesSurvivePersistenceAndResolution() throws {
        for adjustments in [1, 70] {
            let suite = "SeekerTuning.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = GameTuningStore(defaults: defaults)
            var tuning = GameTuningConfiguration.defaults
            let id = "startingWeapons.seekerTargetLimit"
            for _ in 0..<adjustments { tuning.adjustParameter(id: id, direction: .increase) }
            store.tuning = tuning
            let loaded = GameTuningStore(defaults: defaults).tuning
            let expected = 4 + adjustments
            let parameter = try XCTUnwrap(GameTuningParameterCatalog.parameter(id: id))
            XCTAssertEqual(parameter.displayValue(in: loaded), "\(expected)")
            XCTAssertTrue(loaded.sourceSnapshot().contains("tuning.\(id) = \(expected)"))
            let enemies = (0..<100).map {
                ArenaEnemy(id: $0, position: CGPoint(x: $0 + 10, y: 10), radius: 2, speed: 0)
            }
            let resolver = StartingWeaponResolver(configuration: loaded.startingWeapons)
            XCTAssertEqual(resolver.resolve(kind: .seekerSwarm, playerPosition: .zero, enemies: enemies)
                .destroyedEnemyIDs.count, expected)
            XCTAssertEqual(loaded.startingWeapons.applying(chargeTier: .overcharged).seekerTargetLimit, expected + 4)
        }
    }

    func testReadyAndPickupCatalogValuesExecuteBeyondFormerCeilings() throws {
        for adjustments in [1, 40] {
            let suite = "ReadyPickupTuning.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = GameTuningStore(defaults: defaults)
            var tuning = GameTuningConfiguration.defaults
            for _ in 0..<adjustments {
                tuning.adjustParameter(id: "readyStart.requiredDuration", direction: .increase)
                tuning.adjustParameter(id: "classic.pickupSpawnConfiguration.maxActivePickups", direction: .increase)
            }
            store.tuning = tuning
            let loaded = GameTuningStore(defaults: defaults).tuning
            let duration = 3 + Double(adjustments) * 0.25
            var hold = ReadyStartHoldController(configuration: loaded.readyStart)
            XCTAssertFalse(hold.update(playerPosition: .zero, startPoint: .zero, deltaTime: duration - 0.01).didComplete)
            XCTAssertTrue(hold.update(playerPosition: .zero, startPoint: .zero, deltaTime: 0.02).didComplete)
            XCTAssertEqual(hold.requiredDuration, duration)
            var planner = PickupSpawnPlanner(configuration: loaded.classic.pickupSpawnConfiguration)
            let pickups = planner.update(
                deltaTime: 0, phase: .active, activePickupCount: 0,
                playableRect: CGRect(x: 0, y: 0, width: 10_000, height: 10_000),
                playerPosition: .zero, enemyCircles: [], configuration: loaded.classic.pickupSpawnConfiguration
            )
            XCTAssertEqual(pickups.count, 3 + adjustments)
            XCTAssertTrue(loaded.sourceSnapshot().contains("tuning.readyStart.requiredDuration = \(String(format: "%.2f", duration))"))
            XCTAssertEqual(loaded, tuning)
        }
    }

    func testPickupChargingHonorsDeadlinesBeyondSixtySeconds() {
        let configuration = PickupSpawnConfiguration(chargedPickupDelay: 70, overchargedPickupDelay: 80)
        var pickup = WeaponPickup(id: 1, kind: .shockwave, position: .zero, radius: 8)
        pickup.advanceCharge(deltaTime: 69, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .base)
        pickup.advanceCharge(deltaTime: 1, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .charged)
        pickup.advanceCharge(deltaTime: 10, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .overcharged)
        XCTAssertEqual(pickup.timeOnScreen, 80)
    }

    func testParameterCatalogIDsAreUnique() {
        let ids = GameTuningParameterCatalog.parameters.map(\.id)

        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertGreaterThan(ids.count, 250)
        XCTAssertFalse(ids.contains("run.playerVisualRadius"))
    }

    func testAdjustParameterUpdatesNestedGameplayValue() {
        var tuning = GameTuningConfiguration.defaults
        let originalSpeed = tuning.classic.enemySpawnConfiguration.warmup.chaserSpeed

        tuning.adjustParameter(
            id: "classic.enemySpawnConfiguration.warmup.chaserSpeed",
            direction: .increase
        )

        XCTAssertEqual(tuning.classic.enemySpawnConfiguration.warmup.chaserSpeed, originalSpeed + 2)
    }

    func testOptionalSpawnIntervalsCanBeEnabledAndDisabled() {
        var tuning = GameTuningConfiguration.defaults

        XCTAssertNil(tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval)

        tuning.adjustParameter(
            id: "classic.enemySpawnConfiguration.warmup.formationSpawnInterval",
            direction: .increase
        )

        XCTAssertEqual(tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval, 0.5)

        tuning.adjustParameter(
            id: "classic.enemySpawnConfiguration.warmup.formationSpawnInterval",
            direction: .decrease
        )

        XCTAssertNil(tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval)
    }

    func testSourceSnapshotCanBePastedBackIntoDefaultTuning() {
        var tuning = GameTuningConfiguration.defaults
        tuning.playerMovement.visualRadius = 15
        tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval = nil

        let snapshot = tuning.sourceSnapshot()

        XCTAssertTrue(snapshot.contains("var tuning = GameTuningConfiguration.defaults"))
        XCTAssertTrue(snapshot.contains("tuning.playerMovement.visualRadius = 15.0"))
        XCTAssertFalse(snapshot.contains("tuning.run.playerVisualRadius"))
        XCTAssertTrue(snapshot.contains("tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval = nil"))
        XCTAssertTrue(snapshot.contains("tuning.classic.pickupSpawnConfiguration.weaponKindCycle = ["))
        XCTAssertTrue(snapshot.contains("return tuning"))
    }

    func testChangedSourceSnapshotOnlyIncludesChangedParameters() {
        var tuning = GameTuningConfiguration.defaults
        tuning.playerMovement.visualRadius = 15
        tuning.classic.enemySpawnConfiguration.warmup.chaserSpeed += 2

        let snapshot = tuning.sourceSnapshot(changedOnly: true)

        XCTAssertTrue(snapshot.contains("var tuning = GameTuningConfiguration.defaults"))
        XCTAssertTrue(snapshot.contains("tuning.playerMovement.visualRadius = 15.0"))
        XCTAssertTrue(snapshot.contains("tuning.classic.enemySpawnConfiguration.warmup.chaserSpeed = "))
        XCTAssertFalse(snapshot.contains("tuning.playerMovement.borderInset = "))
        XCTAssertFalse(snapshot.contains("tuning.classic.pickupSpawnConfiguration.weaponKindCycle = ["))
        XCTAssertTrue(snapshot.contains("return tuning"))
    }

    func testParameterCatalogProvidesGroupsAndSubgroups() {
        let groups = GameTuningParameterCatalog.groupNames()
        let classicSubgroups = GameTuningParameterCatalog.subgroupNames(in: "Classic")
        let weaponSubgroups = GameTuningParameterCatalog.subgroupNames(in: "Weapons")

        XCTAssertTrue(groups.contains("Classic"))
        XCTAssertFalse(groups.contains("Classic Warmup"))
        XCTAssertTrue(classicSubgroups.contains("Enemies"))
        XCTAssertTrue(classicSubgroups.contains("Warmup"))
        XCTAssertTrue(classicSubgroups.contains("Pickups"))
        XCTAssertEqual(weaponSubgroups, [
            "Shockwave",
            "Waves",
            "Seeker Swarm",
            "Razor Shield",
            "Freeze Burst",
            "Gravity Well",
            "Chain Lightning",
            "Time Dilation",
            "Power Wave",
            "Ricochet Lance",
            "Nova Bomb"
        ])
        XCTAssertEqual(
            GameTuningParameterCatalog.parameters(in: "Weapons", subgroup: "Ricochet Lance").map(\.id),
            [
                "startingWeapons.ricochetLanceBeamWidth",
                "startingWeapons.ricochetLanceMaximumBounces",
                "startingWeapons.ricochetLanceHoldDuration"
            ]
        )
        XCTAssertEqual(
            GameTuningParameterCatalog.parameters(in: "Weapons", subgroup: "Nova Bomb").map(\.id),
            ["startingWeapons.novaBombTargetFraction"]
        )
    }

    func testPrecisionWeaponParametersCanBeAdjustedThroughCatalog() {
        var tuning = GameTuningConfiguration.defaults

        tuning.adjustParameter(id: "startingWeapons.ricochetLanceMaximumBounces", direction: .increase)
        tuning.adjustParameter(id: "startingWeapons.novaBombTargetFraction", direction: .increase)

        XCTAssertEqual(tuning.startingWeapons.ricochetLanceMaximumBounces, 2)
        XCTAssertEqual(tuning.startingWeapons.novaBombTargetFraction, 0.55, accuracy: 0.0001)
    }

    func testChangedOnlyCatalogFiltersToChangedParameters() {
        var tuning = GameTuningConfiguration.defaults
        tuning.classic.enemySpawnConfiguration.warmup.chaserSpeed += 2

        XCTAssertEqual(GameTuningParameterCatalog.groupNames(changedOnly: true, tuning: tuning), ["Classic"])
        XCTAssertEqual(GameTuningParameterCatalog.subgroupNames(in: "Classic", changedOnly: true, tuning: tuning), ["Warmup"])
        XCTAssertEqual(
            GameTuningParameterCatalog.parameters(
                in: "Classic",
                subgroup: "Warmup",
                changedOnly: true,
                tuning: tuning
            ).map(\.id),
            ["classic.enemySpawnConfiguration.warmup.chaserSpeed"]
        )
    }

    func testChangedDetectionUsesExportedValuePrecision() {
        let parameter = GameTuningParameterCatalog.parameter(id: "playerMovement.arenaCrossingDuration")!
        var tuning = GameTuningConfiguration.defaults

        tuning.playerMovement.arenaCrossingDuration += 0.000001

        XCTAssertFalse(tuning.isChanged(parameter))
        XCTAssertTrue(tuning.changedParameters().isEmpty)
    }

    func testTuningStorePersistsChangedParametersAndResetRestoresDefaults() {
        let suiteName = "GameTuningStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = GameTuningStore(defaults: defaults)
        var tuning = GameTuningConfiguration.defaults
        tuning.playerMovement.visualRadius = 15
        tuning.classic.enemySpawnConfiguration.pressure.formationSpawnInterval = nil

        store.tuning = tuning

        let reloaded = GameTuningStore(defaults: defaults).tuning
        XCTAssertEqual(reloaded.playerMovement.visualRadius, 15)
        XCTAssertNil(reloaded.classic.enemySpawnConfiguration.pressure.formationSpawnInterval)
        XCTAssertEqual(reloaded.playerMovement.borderInset, GameTuningConfiguration.defaults.playerMovement.borderInset)

        store.reset()

        XCTAssertEqual(GameTuningStore(defaults: defaults).tuning, .defaults)
    }

    func testTuningStoreClampsPersistedOverridesToCatalogBounds() throws {
        let suiteName = "GameTuningStoreBoundsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let overrides: [String: GameTuningStoredValue] = [
            "playerMovement.visualRadius": .double(-50),
            "startingWeapons.powerWaveFanAngleDegrees": .double(720),
            "classic.enemySpawnConfiguration.warmup.formationLaneCount": .int(0),
            "classic.enemySpawnConfiguration.warmup.formationSpawnInterval": .double(-2)
        ]
        defaults.set(
            try JSONEncoder().encode(overrides),
            forKey: "tiltArena.gameTuningOverrides.v1"
        )

        let tuning = GameTuningStore(defaults: defaults).tuning

        XCTAssertEqual(tuning.playerMovement.visualRadius, 1)
        XCTAssertEqual(tuning.startingWeapons.powerWaveFanAngleDegrees, 360)
        XCTAssertEqual(tuning.classic.enemySpawnConfiguration.warmup.formationLaneCount, 3)
        XCTAssertEqual(tuning.classic.enemySpawnConfiguration.warmup.formationSpawnInterval, 0.1)
    }

    func testTuningStoreDiscardsCorruptOverridesAfterFailedRead() throws {
        let suiteName = "GameTuningStoreCorruptDataTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let overridesKey = "tiltArena.gameTuningOverrides.v1"
        defaults.set(Data("not-json".utf8), forKey: overridesKey)

        XCTAssertEqual(GameTuningStore(defaults: defaults).tuning, .defaults)
        XCTAssertNil(defaults.data(forKey: overridesKey))
    }
}
