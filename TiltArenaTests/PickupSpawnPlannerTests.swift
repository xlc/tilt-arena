import XCTest
@testable import TiltArena

final class PickupSpawnPlannerTests: XCTestCase {
    func testPickupScheduleWaitsForInitialDelayAndRespectsActiveCap() {
        let configuration = PickupSpawnConfiguration(
            initialSpawnDelay: 1,
            spawnInterval: 4.5,
            maxActivePickups: 1
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: 160, y: 320)

        XCTAssertNil(planner.update(
            deltaTime: 0.9,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ))

        let firstPickup = planner.update(
            deltaTime: 0.1,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        )
        XCTAssertNotNil(firstPickup)

        XCTAssertNil(planner.update(
            deltaTime: 10,
            phase: .active,
            activePickupCount: 1,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ))
    }

    func testPickupScheduleDoesNotAdvanceWhilePaused() {
        let configuration = PickupSpawnConfiguration(initialSpawnDelay: 1, spawnInterval: 4.5)
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)

        XCTAssertNil(planner.update(
            deltaTime: 5,
            phase: .paused,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: CGPoint(x: 160, y: 320),
            enemyCircles: [],
            configuration: configuration
        ))

        XCTAssertNil(planner.update(
            deltaTime: 0.9,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: CGPoint(x: 160, y: 320),
            enemyCircles: [],
            configuration: configuration
        ))
    }

    func testPickupPlacementAvoidsPlayerAndEnemiesInsideInsetPlayableRect() {
        let configuration = PickupSpawnConfiguration(
            initialSpawnDelay: 0,
            spawnInterval: 4.5,
            pickupRadius: 10,
            edgeInset: 40,
            playerClearance: 70,
            enemyClearance: 6
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: 160, y: 320)
        let blockingEnemy = CollisionCircle(center: CGPoint(x: 160, y: 207.2), radius: 8)

        let pickup = planner.spawnPickup(
            in: rect,
            avoiding: playerPosition,
            enemyCircles: [blockingEnemy],
            configuration: configuration
        )

        XCTAssertNotNil(pickup)
        XCTAssertGreaterThanOrEqual(pickup?.position.x ?? 0, 40)
        XCTAssertLessThanOrEqual(pickup?.position.x ?? 0, 280)
        XCTAssertGreaterThanOrEqual(pickup?.position.y ?? 0, 40)
        XCTAssertLessThanOrEqual(pickup?.position.y ?? 0, 600)
        XCTAssertNotEqual(pickup?.position, blockingEnemy.center)
        XCTAssertTrue(planner.isSafePickupPosition(
            pickup?.position ?? .zero,
            avoiding: playerPosition,
            enemyCircles: [blockingEnemy],
            configuration: configuration
        ))
    }

    func testResetRestartsPickupIDsAndKindCycle() {
        let configuration = PickupSpawnConfiguration(initialSpawnDelay: 0)
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: 160, y: 320)

        let first = planner.spawnPickup(
            in: rect,
            avoiding: playerPosition,
            enemyCircles: [],
            configuration: configuration
        )
        planner.reset(configuration: configuration)
        let resetFirst = planner.spawnPickup(
            in: rect,
            avoiding: playerPosition,
            enemyCircles: [],
            configuration: configuration
        )

        XCTAssertEqual(first?.id, 1)
        XCTAssertEqual(first?.kind, .shockwave)
        XCTAssertEqual(resetFirst?.id, 1)
        XCTAssertEqual(resetFirst?.kind, .shockwave)
    }
}
