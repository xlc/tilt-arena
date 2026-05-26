import XCTest
@testable import TiltArena

final class PickupSpawnPlannerTests: XCTestCase {
    func testDefaultPickupRadiusKeepsWeaponOrbsCompact() {
        let configuration = PickupSpawnConfiguration()

        XCTAssertEqual(configuration.pickupRadius, 10)
    }

    func testPickupScheduleRespectsActiveCap() {
        let configuration = PickupSpawnConfiguration(maxActivePickups: 1)
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: 160, y: 320)

        XCTAssertTrue(planner.update(
            deltaTime: 10,
            phase: .active,
            activePickupCount: 1,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).isEmpty)

        planner.reset(configuration: configuration)
        let firstPickup = planner.update(
            deltaTime: 0,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        )
        XCTAssertEqual(firstPickup.count, 1)
    }

    func testPickupScheduleDoesNotSpawnWhilePaused() {
        let configuration = PickupSpawnConfiguration()
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: -1_000, y: -1_000)

        XCTAssertTrue(planner.update(
            deltaTime: 5,
            phase: .paused,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).isEmpty)

        XCTAssertEqual(planner.update(
            deltaTime: 0,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).count, 3)
    }

    func testPickupScheduleFillsMissingSlotsUpToActiveTarget() {
        let configuration = PickupSpawnConfiguration(maxActivePickups: 3)
        var planner = PickupSpawnPlanner(configuration: configuration)

        let pickups = planner.update(
            deltaTime: 0,
            phase: .active,
            activePickupCount: 0,
            playableRect: CGRect(x: 0, y: 0, width: 320, height: 640),
            playerPosition: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [],
            configuration: configuration
        )

        XCTAssertEqual(pickups.count, 3)
        XCTAssertEqual(pickups.map(\.id), [1, 2, 3])
    }

    func testPickupScheduleRefillsUsedPickupAfterDelay() {
        let configuration = PickupSpawnConfiguration(
            refillDelay: 0.5,
            maxActivePickups: 3
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: -1_000, y: -1_000)

        XCTAssertEqual(planner.update(
            deltaTime: 0,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).count, 3)

        XCTAssertTrue(planner.update(
            deltaTime: 0.49,
            phase: .active,
            activePickupCount: 2,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).isEmpty)

        let refill = planner.update(
            deltaTime: 0.01,
            phase: .active,
            activePickupCount: 2,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        )

        XCTAssertEqual(refill.count, 1)
        XCTAssertEqual(refill.first?.id, 4)
    }

    func testPickupRefillDelayDoesNotAdvanceWhilePaused() {
        let configuration = PickupSpawnConfiguration(
            refillDelay: 0.5,
            maxActivePickups: 3
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: -1_000, y: -1_000)

        XCTAssertEqual(planner.update(
            deltaTime: 0,
            phase: .active,
            activePickupCount: 0,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).count, 3)

        XCTAssertTrue(planner.update(
            deltaTime: 5,
            phase: .paused,
            activePickupCount: 2,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).isEmpty)

        XCTAssertTrue(planner.update(
            deltaTime: 0.49,
            phase: .active,
            activePickupCount: 2,
            playableRect: rect,
            playerPosition: playerPosition,
            enemyCircles: [],
            configuration: configuration
        ).isEmpty)
    }

    func testPickupPlacementAvoidsPlayerAndEnemiesInsideInsetPlayableRect() {
        let configuration = PickupSpawnConfiguration(
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

    func testPickupPlacementFallsBackWhenPreferredCandidatesAreBlocked() {
        let configuration = PickupSpawnConfiguration(
            pickupRadius: 6,
            edgeInset: 0,
            playerClearance: 0,
            enemyClearance: 0
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 320)
        let enemyCircles = preferredCandidatePositions(in: rect).map {
            CollisionCircle(center: $0, radius: 20)
        }

        let pickup = planner.spawnPickup(
            in: rect,
            avoiding: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: enemyCircles,
            configuration: configuration
        )

        XCTAssertNotNil(pickup)
        XCTAssertTrue(planner.isSafePickupPosition(
            pickup?.position ?? .zero,
            avoiding: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: enemyCircles,
            configuration: configuration
        ))
    }

    func testPickupPlacementReturnsNilWhenNoSafeFallbackExists() {
        let configuration = PickupSpawnConfiguration(
            pickupRadius: 6,
            edgeInset: 0,
            playerClearance: 0,
            enemyClearance: 0
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 320)
        let coveringEnemy = CollisionCircle(center: CGPoint(x: 160, y: 160), radius: 1_000)

        let pickup = planner.spawnPickup(
            in: rect,
            avoiding: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [coveringEnemy],
            configuration: configuration
        )

        XCTAssertNil(pickup)
        XCTAssertEqual(planner.nextPickupID, 1)
    }

    func testResetRestartsPickupIDsAndKindCycle() {
        let configuration = PickupSpawnConfiguration(
            weaponKindCycle: [.seekerSwarm, .freezeBurst]
        )
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
        XCTAssertEqual(first?.kind, .seekerSwarm)
        XCTAssertEqual(resetFirst?.id, 1)
        XCTAssertEqual(resetFirst?.kind, .seekerSwarm)
    }

    func testConfiguredKindCycleControlsPickupOrder() {
        let configuration = PickupSpawnConfiguration(
            weaponKindCycle: [.razorShield, .freezeBurst]
        )

        XCTAssertEqual(spawnKinds(count: 4, configuration: configuration), [
            .razorShield,
            .freezeBurst,
            .razorShield,
            .freezeBurst
        ])
    }

    func testSequenceSeedOffsetsPickupOrderRepeatably() {
        let configuration = PickupSpawnConfiguration()
        let firstSeedKinds = spawnKinds(count: 4, configuration: configuration, sequenceSeed: 20_260_521)
        let repeatSeedKinds = spawnKinds(count: 4, configuration: configuration, sequenceSeed: 20_260_521)
        let nextSeedKinds = spawnKinds(count: 4, configuration: configuration, sequenceSeed: 20_260_522)

        XCTAssertEqual(firstSeedKinds, repeatSeedKinds)
        XCTAssertNotEqual(firstSeedKinds, nextSeedKinds)
    }

    func testSequenceSeedOffsetsPickupPlacementRepeatably() {
        let configuration = PickupSpawnConfiguration()
        let firstSeedPositions = spawnPositions(count: 4, configuration: configuration, sequenceSeed: 20_260_521)
        let repeatSeedPositions = spawnPositions(count: 4, configuration: configuration, sequenceSeed: 20_260_521)
        let nextSeedPositions = spawnPositions(count: 4, configuration: configuration, sequenceSeed: 20_260_524)

        XCTAssertEqual(firstSeedPositions, repeatSeedPositions)
        XCTAssertNotEqual(firstSeedPositions, nextSeedPositions)
    }

    func testSequenceSeedUsesActivePickupCycleLength() {
        let configuration = PickupSpawnConfiguration(
            weaponKindCycle: [
                .shockwave,
                .warpDash,
                .freezeBurst,
                .gravityWell,
                .chainLightning,
                .novaBomb
            ]
        )

        XCTAssertEqual(
            spawnKinds(count: 1, configuration: configuration, sequenceSeed: 25),
            [.warpDash]
        )
    }

    func testDefaultKindCycleMakesLateControlWeaponsRareAndNovaBombLast() {
        let kinds = spawnKinds(
            count: PickupSpawnConfiguration.defaultWeaponKindCycle.count,
            configuration: PickupSpawnConfiguration()
        )

        XCTAssertEqual(kinds, PickupSpawnConfiguration.defaultWeaponKindCycle)
        XCTAssertEqual(Array(kinds.suffix(3)), [.powerWave, .ricochetLance, .novaBomb])
        XCTAssertEqual(kinds.filter { $0 == .freezeBurst }.count, 3)
        XCTAssertEqual(kinds.filter { $0 == .gravityWell }.count, 2)
        XCTAssertEqual(kinds.filter { $0 == .chainLightning }.count, 2)
        XCTAssertEqual(kinds.filter { $0 == .flameTrail }.count, 2)
        XCTAssertEqual(kinds.filter { $0 == .warpDash }.count, 2)
        XCTAssertEqual(kinds.filter { $0 == .powerWave }.count, 1)
        XCTAssertEqual(kinds.filter { $0 == .ricochetLance }.count, 1)
        XCTAssertEqual(kinds.filter { $0 == .novaBomb }.count, 1)
        XCTAssertGreaterThan(kinds.filter { $0 == .shockwave }.count, kinds.filter { $0 == .freezeBurst }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .seekerSwarm }.count, kinds.filter { $0 == .freezeBurst }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .razorShield }.count, kinds.filter { $0 == .freezeBurst }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .freezeBurst }.count, kinds.filter { $0 == .gravityWell }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .freezeBurst }.count, kinds.filter { $0 == .chainLightning }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .freezeBurst }.count, kinds.filter { $0 == .flameTrail }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .freezeBurst }.count, kinds.filter { $0 == .warpDash }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .gravityWell }.count, kinds.filter { $0 == .novaBomb }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .chainLightning }.count, kinds.filter { $0 == .novaBomb }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .flameTrail }.count, kinds.filter { $0 == .novaBomb }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .warpDash }.count, kinds.filter { $0 == .novaBomb }.count)
        XCTAssertGreaterThan(kinds.filter { $0 == .warpDash }.count, kinds.filter { $0 == .powerWave }.count)
        XCTAssertEqual(kinds.filter { $0 == .ricochetLance }.count, kinds.filter { $0 == .novaBomb }.count)
    }

    func testEmptyKindCycleDoesNotSpawnPickup() {
        let configuration = PickupSpawnConfiguration(
            weaponKindCycle: []
        )
        var planner = PickupSpawnPlanner(configuration: configuration)

        XCTAssertNil(planner.spawnPickup(
            in: CGRect(x: 0, y: 0, width: 320, height: 640),
            avoiding: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [],
            configuration: configuration
        ))
    }

    private func spawnKinds(
        count: Int,
        configuration: PickupSpawnConfiguration,
        sequenceSeed: Int? = nil
    ) -> [WeaponKind] {
        var planner = PickupSpawnPlanner(configuration: configuration, sequenceSeed: sequenceSeed)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: -1_000, y: -1_000)

        return (0..<count).compactMap { _ in
            planner.spawnPickup(
                in: rect,
                avoiding: playerPosition,
                enemyCircles: [],
                configuration: configuration
            )?.kind
        }
    }

    private func spawnPositions(
        count: Int,
        configuration: PickupSpawnConfiguration,
        sequenceSeed: Int? = nil
    ) -> [CGPoint] {
        var planner = PickupSpawnPlanner(configuration: configuration, sequenceSeed: sequenceSeed)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 640)
        let playerPosition = CGPoint(x: -1_000, y: -1_000)

        return (0..<count).compactMap { _ in
            planner.spawnPickup(
                in: rect,
                avoiding: playerPosition,
                enemyCircles: [],
                configuration: configuration
            )?.position
        }
    }

    private func preferredCandidatePositions(in rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.28),
            CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.52),
            CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.52),
            CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.72),
            CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.38),
            CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.34),
            CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.68),
            CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.58)
        ]
    }
}
