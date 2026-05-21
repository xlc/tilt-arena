import XCTest
@testable import TiltArena

final class ArenaProgressionRulesTests: XCTestCase {
    func testWeaponUnlockOrderUsesConcreteMilestones() {
        var profile = RunProfile()

        XCTAssertEqual(ArenaProgressionRules.unlockedWeapons(for: profile), [
            .shockwave,
            .seekerSwarm,
            .razorShield
        ])

        profile.totalEnemiesDestroyed = 50
        XCTAssertEqual(ArenaProgressionRules.unlockedWeapons(for: profile), [
            .shockwave,
            .seekerSwarm,
            .razorShield,
            .freezeBurst
        ])

        profile.totalEnemiesDestroyed = 100
        profile.bestScore = 1_500
        profile.highestCombo = 20
        XCTAssertEqual(ArenaProgressionRules.unlockedWeapons(for: profile), [
            .shockwave,
            .seekerSwarm,
            .razorShield,
            .freezeBurst,
            .gravityWell,
            .flameTrail,
            .warpDash
        ])

        profile.totalEnemiesDestroyed = 300
        profile.bestScore = 3_000
        XCTAssertEqual(ArenaProgressionRules.unlockedWeapons(for: profile), ArenaProgressionRules.allGameplayWeapons)
    }

    func testNewUnlocksAreReportedAfterRunRecord() {
        var profile = RunProfile()

        let result = profile.record(RunSummary(
            score: 100,
            survivalTime: 12,
            maxCombo: 4,
            enemiesDestroyed: 50,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: 1)
        ))

        XCTAssertEqual(result.newlyUnlockedWeapons, [.freezeBurst])
        XCTAssertTrue(profile.unlockedWeapons.contains(.freezeBurst))
    }

    func testPickupCyclesFilterToUnlockedWeapons() {
        var profile = RunProfile()

        var classic = ArenaModeRules.runSettings(for: .classic, profile: profile)
        XCTAssertEqual(Set(classic.pickupSpawnConfiguration.weaponKindCycle), Set(ArenaProgressionRules.startingWeapons))
        let daily = ArenaModeRules.runSettings(for: .daily, profile: profile)
        XCTAssertEqual(Set(daily.pickupSpawnConfiguration.weaponKindCycle), Set(ArenaProgressionRules.startingWeapons))

        profile.totalEnemiesDestroyed = 300
        profile.bestScore = 3_000
        profile.highestCombo = 20
        classic = ArenaModeRules.runSettings(for: .classic, profile: profile)
        let fullyUnlockedDaily = ArenaModeRules.runSettings(for: .daily, profile: profile)

        XCTAssertEqual(Set(classic.pickupSpawnConfiguration.weaponKindCycle), Set(WeaponKind.allCases))
        XCTAssertEqual(Set(fullyUnlockedDaily.pickupSpawnConfiguration.weaponKindCycle), Set(WeaponKind.allCases))
    }

    func testRedlineKeepsModeCycleButFiltersLockedWeapons() {
        var profile = RunProfile()
        profile.bestScore = ArenaProgressionRules.redlineBestScoreRequirement

        var redline = ArenaModeRules.runSettings(for: .redline, profile: profile)
        XCTAssertEqual(Set(redline.pickupSpawnConfiguration.weaponKindCycle), [
            .shockwave,
            .seekerSwarm,
            .razorShield,
            .flameTrail,
            .decoyBeacon
        ])
        XCTAssertFalse(redline.pickupSpawnConfiguration.weaponKindCycle.contains(.warpDash))
        XCTAssertFalse(redline.pickupSpawnConfiguration.weaponKindCycle.contains(.novaBomb))

        profile.totalEnemiesDestroyed = 300
        profile.highestCombo = 20
        redline = ArenaModeRules.runSettings(for: .redline, profile: profile)

        XCTAssertTrue(redline.pickupSpawnConfiguration.weaponKindCycle.contains(.flameTrail))
        XCTAssertTrue(redline.pickupSpawnConfiguration.weaponKindCycle.contains(.warpDash))
        XCTAssertFalse(redline.pickupSpawnConfiguration.weaponKindCycle.contains(.novaBomb))
    }

    func testAwardCompletionAndNewAwardsUseProfileState() {
        var profile = RunProfile()

        let result = profile.record(RunSummary(
            score: 5_000,
            survivalTime: 120,
            maxCombo: 10,
            enemiesDestroyed: 25,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: 1)
        ))

        XCTAssertEqual(
            result.newlyEarnedAwardIDs,
            [.comboSpark, .scoreCrest, .freezeShatter, .survivor]
        )
        XCTAssertTrue(profile.earnedAwardIDs.contains(.comboSpark))
        XCTAssertTrue(profile.earnedAwardIDs.contains(.survivor))
    }
}
