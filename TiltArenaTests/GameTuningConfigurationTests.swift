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
}
