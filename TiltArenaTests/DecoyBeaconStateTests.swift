import XCTest
@testable import TiltArena

final class DecoyBeaconStateTests: XCTestCase {
    func testActivateStoresCenterAndCountsDownBeforeExplosion() {
        var state = DecoyBeaconState(
            configuration: DecoyBeaconConfiguration(
                duration: 2,
                attractionRadius: 100,
                explosionRadius: 40
            )
        )

        state.activate(at: CGPoint(x: 10, y: 20))
        let frame = state.update(deltaTime: 0.75, enemies: [
            enemy(id: 1, position: CGPoint(x: 10, y: 20))
        ])

        XCTAssertEqual(state.center, CGPoint(x: 10, y: 20))
        XCTAssertEqual(state.timeRemaining, 1.25, accuracy: 0.0001)
        XCTAssertTrue(state.isActive)
        XCTAssertNil(frame.explosionCenter)
        XCTAssertEqual(frame.destroyedEnemyIDs, [])
    }

    func testTargetPositionRedirectsOnlyNearbyTargetSeekingEnemies() {
        var state = DecoyBeaconState(
            configuration: DecoyBeaconConfiguration(
                duration: 2,
                attractionRadius: 100,
                explosionRadius: 40
            )
        )
        state.activate(at: .zero)
        let fallback = CGPoint(x: 200, y: 0)

        XCTAssertEqual(
            state.targetPosition(for: enemy(id: 1, position: CGPoint(x: 80, y: 0)), fallback: fallback),
            .zero
        )
        XCTAssertEqual(
            state.targetPosition(
                for: enemy(
                    id: 2,
                    position: CGPoint(x: 80, y: 0),
                    behavior: .hunterDot(predictionLead: 0.2, previousTarget: nil)
                ),
                fallback: fallback
            ),
            .zero
        )
        XCTAssertEqual(
            state.targetPosition(for: enemy(id: 3, position: CGPoint(x: 140, y: 0)), fallback: fallback),
            fallback
        )
        XCTAssertEqual(
            state.targetPosition(
                for: enemy(
                    id: 4,
                    position: CGPoint(x: 40, y: 0),
                    behavior: .formationLine(velocity: .zero, formationID: 1)
                ),
                fallback: fallback
            ),
            fallback
        )
        XCTAssertEqual(
            state.targetPosition(
                for: enemy(id: 5, position: CGPoint(x: 40, y: 0), behavior: .arrowRush(velocity: .zero)),
                fallback: fallback
            ),
            fallback
        )
        XCTAssertEqual(
            state.targetPosition(
                for: enemy(id: 6, position: CGPoint(x: 40, y: 0), behavior: .mineDot),
                fallback: fallback
            ),
            fallback
        )
        XCTAssertEqual(
            state.targetPosition(
                for: enemy(
                    id: 7,
                    position: CGPoint(x: 40, y: 0),
                    behavior: .paddleTrapBar(trapID: 1, remainingLifetime: 1)
                ),
                fallback: fallback
            ),
            fallback
        )
        XCTAssertEqual(
            state.targetPosition(
                for: enemy(
                    id: 8,
                    position: CGPoint(x: 40, y: 0),
                    behavior: .paddleTrapDot(
                        trapID: 1,
                        velocity: .zero,
                        bounds: CGRect(x: -100, y: -100, width: 200, height: 200),
                        remainingLifetime: 1
                    )
                ),
                fallback: fallback
            ),
            fallback
        )
    }

    func testFrozenTargetSeekingEnemyIsNotRedirected() {
        var state = DecoyBeaconState(
            configuration: DecoyBeaconConfiguration(
                duration: 2,
                attractionRadius: 100,
                explosionRadius: 40
            )
        )
        state.activate(at: .zero)
        var frozenEnemy = enemy(id: 1, position: CGPoint(x: 40, y: 0))
        frozenEnemy.freeze(duration: 1)
        let fallback = CGPoint(x: 200, y: 0)

        XCTAssertEqual(state.targetPosition(for: frozenEnemy, fallback: fallback), fallback)
    }

    func testExpiryExplodesAndClearsEnemiesInsideRadius() {
        var state = DecoyBeaconState(
            configuration: DecoyBeaconConfiguration(
                duration: 2,
                attractionRadius: 100,
                explosionRadius: 40
            )
        )
        state.activate(at: CGPoint(x: 10, y: 0))

        let frame = state.update(deltaTime: 2, enemies: [
            enemy(id: 1, position: CGPoint(x: 42, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ])

        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.center)
        XCTAssertEqual(frame.explosionCenter, CGPoint(x: 10, y: 0))
        XCTAssertEqual(frame.destroyedEnemyIDs, [1])
    }

    func testZeroDurationActivationLeavesBeaconInactive() {
        var state = DecoyBeaconState(
            configuration: DecoyBeaconConfiguration(
                duration: 0,
                attractionRadius: 100,
                explosionRadius: 40
            )
        )

        state.activate(at: CGPoint(x: 10, y: 20))

        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.center)
        XCTAssertEqual(state.timeRemaining, 0)
    }

    func testResetClearsActiveBeacon() {
        var state = DecoyBeaconState()
        state.activate(at: CGPoint(x: 10, y: 20))

        state.reset()

        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.center)
        XCTAssertEqual(state.timeRemaining, 0)
    }

    private func enemy(
        id: Int,
        position: CGPoint,
        behavior: EnemyBehavior = .chaser
    ) -> ArenaEnemy {
        ArenaEnemy(
            id: id,
            position: position,
            radius: 8,
            speed: 0,
            behavior: behavior
        )
    }
}
