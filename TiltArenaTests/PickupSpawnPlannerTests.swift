import XCTest
@testable import TiltArena

final class PickupSpawnPlannerTests: XCTestCase {
    func testPickupChargeRecoversFromNonfiniteAgeAndDelta() {
        let configuration = PickupSpawnConfiguration(
            chargedPickupDelay: 2,
            overchargedPickupDelay: 5
        )
        var pickup = WeaponPickup(
            id: 1,
            kind: .shockwave,
            position: .zero,
            radius: 8,
            timeOnScreen: .nan
        )

        pickup.advanceCharge(deltaTime: .infinity, configuration: configuration)
        XCTAssertEqual(pickup.timeOnScreen, 0)
        XCTAssertEqual(pickup.chargeTier, .base)

        pickup.advanceCharge(deltaTime: 2, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .charged)
    }

    func testExtremeActivePickupCountIsCappedPerFrame() {
        let configuration = PickupSpawnConfiguration(
            maxActivePickups: .max,
            pickupRadius: 0,
            edgeInset: 0,
            playerClearance: 0,
            enemyClearance: 0
        )
        var planner = PickupSpawnPlanner(configuration: configuration)

        let pickups = planner.update(
            deltaTime: .infinity,
            phase: .active,
            activePickupCount: 0,
            playableRect: CGRect(x: 0, y: 0, width: 320, height: 640),
            playerPosition: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [],
            configuration: configuration
        )

        XCTAssertEqual(pickups.count, PickupSpawnPlanner.maximumActivePickupCount)
        XCTAssertTrue(pickups.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite })
    }

    func testDefaultPickupRadiusKeepsWeaponOrbsCompact() {
        let configuration = PickupSpawnConfiguration()

        XCTAssertEqual(configuration.pickupRadius, 8.5)
    }

    func testPickupChargeTierUsesTimeOnScreenThresholds() {
        let chargedDelay: TimeInterval = 2.5
        let overchargedDelay: TimeInterval = 6.5
        let configuration = PickupSpawnConfiguration(
            chargedPickupDelay: chargedDelay,
            overchargedPickupDelay: overchargedDelay
        )
        let momentBeforeThreshold: TimeInterval = 0.01

        XCTAssertEqual(configuration.chargeTier(for: chargedDelay - momentBeforeThreshold), .base)
        XCTAssertEqual(configuration.chargeTier(for: chargedDelay), .charged)
        XCTAssertEqual(configuration.chargeTier(for: overchargedDelay - momentBeforeThreshold), .charged)
        XCTAssertEqual(configuration.chargeTier(for: overchargedDelay), .overcharged)
    }

    func testPickupAdvancesChargeWithoutEnemyContext() {
        let configuration = PickupSpawnConfiguration(
            chargedPickupDelay: 2,
            overchargedPickupDelay: 5
        )
        var pickup = WeaponPickup(id: 1, kind: .shockwave, position: .zero, radius: 8)

        pickup.advanceCharge(deltaTime: 1.9, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .base)

        pickup.advanceCharge(deltaTime: 0.1, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .charged)

        pickup.advanceCharge(deltaTime: 3, configuration: configuration)
        XCTAssertEqual(pickup.chargeTier, .overcharged)
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

    func testPickupScheduleKeepsNewBatchPickupsSeparated() {
        let configuration = PickupSpawnConfiguration(
            maxActivePickups: 3,
            pickupRadius: 15,
            edgeInset: 0,
            playerClearance: 0,
            enemyClearance: 0
        )
        var planner = PickupSpawnPlanner(configuration: configuration)

        let pickups = planner.update(
            deltaTime: 0,
            phase: .active,
            activePickupCount: 0,
            playableRect: CGRect(x: 0, y: 0, width: 80, height: 80),
            playerPosition: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [],
            configuration: configuration
        )

        XCTAssertEqual(pickups.count, 3)
        for index in pickups.indices {
            for otherIndex in pickups.indices where otherIndex > index {
                XCTAssertFalse(pickups[index].collisionCircle.intersects(pickups[otherIndex].collisionCircle))
            }
        }
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

    func testPickupPlacementAvoidsExistingPickups() throws {
        let configuration = PickupSpawnConfiguration(
            pickupRadius: 10,
            edgeInset: 0,
            playerClearance: 0,
            enemyClearance: 0
        )
        var planner = PickupSpawnPlanner(configuration: configuration)
        let rect = CGRect(x: 0, y: 0, width: 320, height: 320)
        let existingPickupCircle = CollisionCircle(
            center: preferredCandidatePositions(in: rect)[0],
            radius: configuration.pickupRadius
        )

        let pickup = try XCTUnwrap(planner.spawnPickup(
            in: rect,
            avoiding: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [],
            pickupCircles: [existingPickupCircle],
            configuration: configuration
        ))

        XCTAssertFalse(pickup.collisionCircle.intersects(existingPickupCircle))
        XCTAssertTrue(planner.isSafePickupPosition(
            pickup.position,
            avoiding: CGPoint(x: -1_000, y: -1_000),
            enemyCircles: [],
            pickupCircles: [existingPickupCircle],
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

    func testClassicOpeningGuaranteesStartersWithoutChangingCycleWeights() {
        var complete = RunProfile()
        complete.unlockedWeapons = Set(WeaponKind.allCases)
        for profile in [RunProfile(), complete] {
            let configuration = ArenaModeRules.runSettings(for: .classic, profile: profile).pickupSpawnConfiguration
            let count = configuration.weaponKindCycle.count
            for seed in 0..<26 {
                let kinds = spawnKinds(count: count * 2, configuration: configuration, sequenceSeed: seed)
                XCTAssertEqual(Set(kinds.prefix(3)), Set(ArenaProgressionRules.startingWeapons))
                XCTAssertEqual(
                    kinds.prefix(count).map(\.rawValue).sorted(), configuration.weaponKindCycle.map(\.rawValue).sorted()
                )
                var ordinary = configuration
                ordinary.guaranteedOpening = []
                let original = spawnKinds(count: count, configuration: ordinary, sequenceSeed: seed)
                XCTAssertEqual(Array(kinds.suffix(count)), original)
            }
        }
    }

    func testFailedPlacementDoesNotConsumeTheGuaranteedOpening() {
        let configuration = ArenaModeRules.runSettings(for: .classic).pickupSpawnConfiguration
        var planner = PickupSpawnPlanner(configuration: configuration, sequenceSeed: 13)
        let rect = CGRect(x: 0, y: 0, width: 658, height: 317)
        XCTAssertNil(planner.spawnPickup(
            in: rect, avoiding: .zero,
            enemyCircles: [CollisionCircle(center: CGPoint(x: 329, y: 158), radius: 1_000)],
            configuration: configuration
        ))
        let kinds = (0..<3).compactMap { _ in
            planner.spawnPickup(in: rect, avoiding: .zero, enemyCircles: [], configuration: configuration)?.kind
        }
        XCTAssertEqual(Set(kinds), Set(ArenaProgressionRules.startingWeapons))
        XCTAssertEqual(planner.nextPickupID, 4)
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
