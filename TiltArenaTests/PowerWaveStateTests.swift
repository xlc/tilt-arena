import XCTest
@testable import TiltArena

final class PowerWaveStateTests: XCTestCase {
    func testChargeDoesNotDestroyEnemiesBeforeRelease() {
        var state = PowerWaveState()
        let configuration = StartingWeaponConfiguration(powerWaveChargeDuration: 0.35)

        state.activate(configuration: configuration)
        let frame = state.update(
            deltaTime: 0.34,
            playerPosition: .zero,
            direction: CGVector(dx: 1, dy: 0),
            playableRect: playableRect,
            enemies: [enemy(id: 1, position: CGPoint(x: 20, y: 0))],
            configuration: configuration
        )

        XCTAssertTrue(frame.isCharging)
        XCTAssertEqual(frame.destroyedEnemyIDs, [])
        XCTAssertNil(frame.release)
    }

    func testReleaseUsesCurrentPositionAndDirectionAfterCharge() throws {
        var state = PowerWaveState()
        let configuration = StartingWeaponConfiguration(powerWaveChargeDuration: 0.35)

        state.activate(configuration: configuration)
        let frame = state.update(
            deltaTime: 0.35,
            playerPosition: CGPoint(x: 10, y: 20),
            direction: CGVector(dx: 3, dy: 4),
            playableRect: playableRect,
            enemies: [],
            configuration: configuration
        )

        let release = try XCTUnwrap(frame.release)
        XCTAssertEqual(release.center, CGPoint(x: 10, y: 20))
        XCTAssertEqual(release.direction.dx, 0.6, accuracy: 0.0001)
        XCTAssertEqual(release.direction.dy, 0.8, accuracy: 0.0001)
        XCTAssertGreaterThan(release.travelDistance, 180)
    }

    func testWaveHitsEnemiesInFrontWithinMovingFan() {
        var wave = PowerWaveWaveState(
            center: .zero,
            direction: CGVector(dx: 1, dy: 0),
            maximumRange: 100,
            fanAngleDegrees: 70,
            expansionDuration: 1,
            playableRect: playableRect
        )

        let frame = wave.update(deltaTime: 1, enemies: [
            enemy(id: 1, position: CGPoint(x: 80, y: 0)),
            enemy(id: 2, position: CGPoint(x: 120, y: 0))
        ])

        XCTAssertEqual(frame.destroyedEnemyIDs, [1])
    }

    func testWaveExcludesEnemiesBehindOrOutsideFanAngle() {
        var wave = PowerWaveWaveState(
            center: .zero,
            direction: CGVector(dx: 1, dy: 0),
            maximumRange: 100,
            fanAngleDegrees: 70,
            expansionDuration: 1,
            playableRect: playableRect
        )

        let frame = wave.update(deltaTime: 1, enemies: [
            enemy(id: 1, position: CGPoint(x: -20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 60, y: 80))
        ])

        XCTAssertEqual(frame.destroyedEnemyIDs, [])
    }

    func testWaveCountsEnemyRadiusTouchingFanEdge() {
        var wave = PowerWaveWaveState(
            center: .zero,
            direction: CGVector(dx: 1, dy: 0),
            maximumRange: 100,
            fanAngleDegrees: 70,
            expansionDuration: 1,
            playableRect: playableRect
        )
        let angle = CGFloat(40) * .pi / 180
        let position = CGPoint(x: cos(angle) * 80, y: sin(angle) * 80)

        let frame = wave.update(deltaTime: 1, enemies: [
            enemy(id: 1, position: position, radius: 8)
        ])

        XCTAssertEqual(frame.destroyedEnemyIDs, [1])
    }

    func testWaveDoesNotDestroyTheSameEnemyTwice() {
        var wave = PowerWaveWaveState(
            center: .zero,
            direction: CGVector(dx: 1, dy: 0),
            maximumRange: 100,
            fanAngleDegrees: 70,
            expansionDuration: 1,
            playableRect: playableRect
        )
        let enemies = [enemy(id: 1, position: CGPoint(x: 80, y: 0))]

        XCTAssertEqual(wave.update(deltaTime: 1, enemies: enemies).destroyedEnemyIDs, [1])
        XCTAssertEqual(wave.update(deltaTime: 0.1, enemies: enemies).destroyedEnemyIDs, [])
    }

    func testWaveContinuesMovingUntilItLeavesPlayableRect() {
        var wave = PowerWaveWaveState(
            center: .zero,
            direction: CGVector(dx: 1, dy: 0),
            maximumRange: 50,
            fanAngleDegrees: 60,
            expansionDuration: 1,
            playableRect: CGRect(x: 0, y: -50, width: 200, height: 100)
        )

        XCTAssertFalse(wave.update(deltaTime: 1, enemies: []).isComplete)
        XCTAssertFalse(wave.update(deltaTime: 3, enemies: []).isComplete)
        XCTAssertTrue(wave.update(deltaTime: 1, enemies: []).isComplete)
    }

    private func enemy(id: Int, position: CGPoint, radius: CGFloat = 4) -> ArenaEnemy {
        ArenaEnemy(
            id: id,
            position: position,
            radius: radius,
            speed: 0
        )
    }

    private var playableRect: CGRect {
        CGRect(x: 0, y: -100, width: 300, height: 200)
    }
}
