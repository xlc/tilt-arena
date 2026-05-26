import XCTest
@testable import TiltArena

final class WeaponApplicationCoordinatorTests: XCTestCase {
    func testSeekerSwarmPlansTargetedEffectAndLog() {
        let coordinator = WeaponApplicationCoordinator(
            resolver: StartingWeaponResolver(
                configuration: StartingWeaponConfiguration(seekerTargetLimit: 2)
            )
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 200, y: 0)),
            enemy(id: 2, position: CGPoint(x: 20, y: 0)),
            enemy(id: 3, position: CGPoint(x: 60, y: 0))
        ]
        var rng = SeededGenerator(seed: 1)

        let application = coordinator.application(
            kind: .seekerSwarm,
            playerPosition: .zero,
            enemies: enemies,
            using: &rng
        )

        XCTAssertEqual(application.effect, .seekerSwarm(enemyIDs: [2, 3]))
        XCTAssertEqual(application.log.destroyedCount, 2)
        XCTAssertEqual(application.log.frozenCount, 0)
        XCTAssertEqual(application.log.gravityTargetCount, 0)
    }

    func testShockwavePlansWaveWithoutImmediateDestroyedLog() {
        let coordinator = WeaponApplicationCoordinator(
            resolver: StartingWeaponResolver(
                configuration: StartingWeaponConfiguration(shockwaveRadius: 50)
            )
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ]
        var rng = SeededGenerator(seed: 1)

        let application = coordinator.application(
            kind: .shockwave,
            playerPosition: .zero,
            enemies: enemies,
            using: &rng
        )

        XCTAssertEqual(application.effect, .shockwaveWave)
        XCTAssertEqual(application.log.destroyedCount, 0)
    }

    func testGravityWellPlansTargetIDsAndLog() {
        let coordinator = WeaponApplicationCoordinator(
            resolver: StartingWeaponResolver(
                configuration: StartingWeaponConfiguration(gravityWellRadius: 50)
            )
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ]
        var rng = SeededGenerator(seed: 1)

        let application = coordinator.application(
            kind: .gravityWell,
            playerPosition: .zero,
            enemies: enemies,
            using: &rng
        )

        XCTAssertEqual(application.effect, .gravityWell(enemyIDs: [1]))
        XCTAssertEqual(application.log.destroyedCount, 0)
        XCTAssertEqual(application.log.gravityTargetCount, 1)
    }

    func testNovaBombUsesInjectedGeneratorForPlanAndLog() {
        let coordinator = WeaponApplicationCoordinator()
        let enemies = (1...12).map { enemy(id: $0, position: .zero) }
        var firstGenerator = SeededGenerator(seed: 7)
        var secondGenerator = SeededGenerator(seed: 7)

        let firstApplication = coordinator.application(
            kind: .novaBomb,
            playerPosition: .zero,
            enemies: enemies,
            using: &firstGenerator
        )
        let secondApplication = coordinator.application(
            kind: .novaBomb,
            playerPosition: .zero,
            enemies: enemies,
            using: &secondGenerator
        )

        XCTAssertEqual(firstApplication, secondApplication)
        XCTAssertEqual(firstApplication.log.destroyedCount, 12)
        if case .novaBomb(let enemyIDs) = firstApplication.effect {
            XCTAssertEqual(enemyIDs.count, 12)
            XCTAssertTrue(enemyIDs.isSubset(of: Set(enemies.map(\.id))))
        } else {
            XCTFail("Expected nova bomb application")
        }
    }

    func testDirectionalWeaponsDeferSceneSpecificResolution() {
        let coordinator = WeaponApplicationCoordinator()
        let enemies = [enemy(id: 1, position: CGPoint(x: 10, y: 0))]
        var rng = SeededGenerator(seed: 1)

        let application = coordinator.application(
            kind: .warpDash,
            playerPosition: .zero,
            enemies: enemies,
            using: &rng
        )

        XCTAssertEqual(application.effect, .directional(.warpDash))
        XCTAssertEqual(application.log.destroyedCount, 0)
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 8, speed: 0)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
