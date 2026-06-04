import XCTest
@testable import TiltArena

final class GameTuningConfigurationTests: XCTestCase {
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
        XCTAssertTrue(weaponSubgroups.contains("Shockwave"))
        XCTAssertFalse(weaponSubgroups.contains("Nova Bomb"))
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
}
