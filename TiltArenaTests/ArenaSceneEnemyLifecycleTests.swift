import CoreGraphics
import XCTest
@testable import TiltArena

@MainActor
final class ArenaSceneEnemyLifecycleTests: XCTestCase {
    func testDroppedFrameStillChecksTheTravelingPowerWaveBeforeItPassesAnEnemy() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        var tuning = ArenaBalanceVariant.baseline.tuning
        tuning.startingWeapons.powerWaveChargeDuration = 0
        tuning.startingWeapons.powerWaveRange = 20
        tuning.startingWeapons.powerWaveExpansionDuration = 0.02
        harness.scene.prepareBalanceRunForTesting(tuning: tuning, seed: 91)
        let center = harness.scene.playerPositionForTesting
        harness.scene.inputOverrideForTesting = CGVector(dx: 0.25, dy: 0)
        harness.step(at: 0)
        harness.step(at: 0.01)
        harness.scene.inputOverrideForTesting = .zero
        harness.scene.seedBalanceEnemiesForTesting([
            ArenaEnemy(id: 100, position: CGPoint(x: center.x + 50, y: center.y), radius: 8, speed: 0)
        ])
        harness.scene.collectWeaponForTesting(.powerWave)
        harness.step(at: 0.31)
        XCTAssertTrue(harness.scene.enemyIDsForTesting.isEmpty)
        XCTAssertFalse(harness.scene.isRunGameOverForTesting)
    }

    func testFlameBoostStopsAtItsDeadlineWithinAFrame() throws {
        let harness = try ArenaBalanceHarness()
        defer { harness.close() }
        var tuning = ArenaBalanceVariant.baseline.tuning
        tuning.flameTrail.duration = 0.01
        harness.scene.prepareBalanceRunForTesting(tuning: tuning, seed: 91)
        harness.scene.inputOverrideForTesting = CGVector(dx: 0.5, dy: 0)
        let start = harness.scene.playerPositionForTesting
        harness.scene.collectWeaponForTesting(.flameTrail)
        harness.step(at: 0)
        harness.step(at: 0.05)

        let speed = tuning.playerMovement.maximumSpeed(in: harness.scene.currentGameplayBounds)
        let distance = speed * (tuning.flameTrail.speedMultiplier * 0.01 + 0.5 * 0.04)
        XCTAssertEqual(harness.scene.playerPositionForTesting.x, start.x + distance, accuracy: 0.001)
    }

    func testResumeWithoutPausedFramesExcludesBackgroundTime() {
        let scene = makeActiveScene()
        scene.update(1)
        scene.update(1.02)
        scene.pauseRunForTesting()
        scene.resumeRunForTesting()
        scene.update(100)
        XCTAssertEqual(scene.runSurvivalTimeForTesting, 0.02, accuracy: 0.001)
    }

    func testDailySimulationUsesTheSameWorldAcrossPhoneLayoutsAndResize() throws {
        func makeScene(size: CGSize) throws -> ArenaScene {
            let suite = "DailyLayoutTests.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
            return ArenaScene(
                size: size,
                tiltSettingsStore: TiltSettingsStore(defaults: defaults),
                runProfileStore: RunProfileStore(defaults: defaults),
                localOptionsStore: ArenaLocalOptionsStore(defaults: defaults),
                gameTuningStore: GameTuningStore(defaults: defaults)
            )
        }
        let small = try makeScene(size: CGSize(width: 667, height: 375))
        let large = try makeScene(size: CGSize(width: 932, height: 430))
        for scene in [small, large] {
            scene.prepareActiveRunForTesting(mode: .daily, sequenceSeed: 20_260_909)
            scene.update(0)
        }
        XCTAssertEqual(small.currentGameplayBounds, large.currentGameplayBounds)
        XCTAssertEqual(small.currentPlayableRect.size, CGSize(width: 658, height: 317))
        for frame in 1...360 {
            let angle = Double(frame) / 90
            for scene in [small, large] {
                scene.inputOverrideForTesting = CGVector(dx: cos(angle), dy: sin(angle))
                if frame == 60 { scene.collectWeaponForTesting(.shockwave, id: 800) }
                if frame == 120 { scene.collectWeaponForTesting(.freezeBurst, id: 801) }
                scene.update(Double(frame) / 60)
            }
            if frame == 180 { large.size = CGSize(width: 852, height: 393) }
            XCTAssertEqual(small.playerPositionForTesting, large.playerPositionForTesting)
            XCTAssertEqual(small.enemiesForTesting.map(\.id), large.enemiesForTesting.map(\.id))
            XCTAssertEqual(small.enemiesForTesting.map(\.position), large.enemiesForTesting.map(\.position))
            XCTAssertEqual(small.enemiesForTesting.map(\.behavior), large.enemiesForTesting.map(\.behavior))
            XCTAssertEqual(small.enemiesForTesting.map(\.frozenTimeRemaining), large.enemiesForTesting.map(\.frozenTimeRemaining))
            XCTAssertEqual(small.pickupsForTesting, large.pickupsForTesting)
            XCTAssertEqual(small.scoreForTesting, large.scoreForTesting)
            XCTAssertEqual(small.uiStateForTesting, large.uiStateForTesting)
            XCTAssertEqual(small.uiStateForTesting, .activeGameplay)
        }
        XCTAssertGreaterThanOrEqual(small.scoreBreakdownForTesting.pickups, 2 * ClassicRunConfiguration().itemPickupScore)
        XCTAssertGreaterThan(small.runSurvivalTimeForTesting, 5)
        XCTAssertNotEqual(small.screenPositionForTesting(small.playerPositionForTesting),
                          large.screenPositionForTesting(large.playerPositionForTesting))
    }

    func testResizeDoesNotResetRetryOrMoveThePlayerInWorldSpace() {
        let scene = makeActiveScene()
        scene.finishRunForTesting()
        scene.retryRunForTesting()
        scene.update(0)
        for frame in 1...30 { scene.update(Double(frame) / 60) }
        let position = scene.playerPositionForTesting
        scene.size = CGSize(width: 932, height: 430)
        XCTAssertEqual(scene.playerPositionForTesting, position)
        for frame in 31...46 { scene.update(Double(frame) / 60) }
        XCTAssertEqual(scene.uiStateForTesting, .activeGameplay)
    }

    func testGravityWellDestroysPickupLocationEnemyOnActivation() {
        let scene = makeActiveScene()
        let pickupPosition = CGPoint(x: 80, y: 90)
        let centerEnemy = ArenaEnemy(id: 100, position: pickupPosition, radius: 10, speed: 0)
        let outerEnemy = ArenaEnemy(
            id: 101,
            position: CGPoint(x: pickupPosition.x + 70, y: pickupPosition.y),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(centerEnemy)
        scene.addEnemyForTesting(outerEnemy)
        scene.activateGravityWellForTesting(
            center: pickupPosition,
            configuration: StartingWeaponConfiguration(gravityWellClearRadius: 24)
        )

        XCTAssertEqual(scene.enemyIDsForTesting, [outerEnemy.id])
    }

    func testSeekerSwarmLeavesTargetLiveBeforeImpact() {
        let scene = makeActiveScene()
        let target = ArenaEnemy(
            id: 100,
            position: CGPoint(x: 160, y: 120),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(target)
        scene.playSeekerSwarmForTesting(enemyIDs: [target.id], from: CGPoint(x: 40, y: 40))

        XCTAssertEqual(scene.enemyIDsForTesting, [target.id])
        XCTAssertEqual(scene.enemyNodeCountForTesting, 1)
    }

    func testSeekerExplosionUsesStoredImpactLocationAfterOriginalTargetDies() {
        let scene = makeActiveScene()
        let target = ArenaEnemy(
            id: 100,
            position: CGPoint(x: 160, y: 120),
            radius: 10,
            speed: 0
        )
        let nearbyEnemy = ArenaEnemy(
            id: 101,
            position: CGPoint(x: 178, y: 120),
            radius: 10,
            speed: 0
        )

        scene.addEnemyForTesting(target)
        scene.addEnemyForTesting(nearbyEnemy)
        scene.removeEnemyForTesting(id: target.id)

        XCTAssertEqual(scene.enemyIDsForTesting, [nearbyEnemy.id])

        scene.resolveSeekerExplosionForTesting(
            at: WeaponImpactTarget(id: target.id, position: target.position)
        )

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertEqual(scene.enemyNodeCountForTesting, 0)
    }

    func testPostWeaponSafetyTemporarilySuppressesEnemyCollision() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 200, position: playerPosition, radius: 10, speed: 0)

        scene.addEnemyForTesting(enemy)
        scene.grantPostWeaponSafetyForTesting()
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertFalse(scene.isRunGameOverForTesting)

        scene.advancePostWeaponSafetyForTesting(deltaTime: 1)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertTrue(scene.isRunGameOverForTesting)
    }

    func testSweptCollisionCatchesEnemyCrossingPlayerBetweenFrameEndpoints() throws {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(
            id: 205,
            position: CGPoint(x: playerPosition.x + 20, y: playerPosition.y),
            radius: 4,
            speed: 0
        )
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [
                enemy.id: CGPoint(x: playerPosition.x - 20, y: playerPosition.y)
            ]
        )

        XCTAssertTrue(scene.isRunGameOverForTesting)
        let collision = try XCTUnwrap(scene.lastDeathCollisionSnapshotForTesting)
        XCTAssertEqual(collision.playerPosition.x, playerPosition.x, accuracy: 0.0001)
        XCTAssertEqual(
            abs(collision.enemyPosition.x - playerPosition.x),
            ClassicRunConfiguration().playerHitRadius + enemy.radius,
            accuracy: 0.0001
        )
    }

    func testSweptCollisionDoesNotRetroactivelyKillAcrossProtectedMovement() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(
            id: 207,
            position: CGPoint(x: playerPosition.x + 20, y: playerPosition.y),
            radius: 4,
            speed: 0
        )
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [
                enemy.id: CGPoint(x: playerPosition.x - 20, y: playerPosition.y)
            ],
            allowsSweptCollision: false
        )

        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testSweptCollisionDoesNotRetroactivelyKillAcrossEnemySpawnGrace() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(
            id: 208,
            position: CGPoint(x: playerPosition.x + 20, y: playerPosition.y),
            radius: 4,
            speed: 0
        )
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [:]
        )

        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testEnemyLeavingSpawnGraceCanStillHitAtFrameEndpoint() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 209, position: playerPosition, radius: 4, speed: 0)
        scene.addEnemyForTesting(enemy)

        scene.detectPlayerCollisionForTesting(
            playerPosition: playerPosition,
            previousPlayerPosition: playerPosition,
            previousDamageableEnemyPositions: [:]
        )

        XCTAssertTrue(scene.isRunGameOverForTesting)
    }

    func testFrozenEnemyCanBeShatteredBeforeThawWindow() {
        let scene = makeActiveScene()
        let frozenEnemy = ArenaEnemy(
            id: 206,
            position: scene.playerPositionForTesting,
            radius: 4,
            speed: 0,
            frozenTimeRemaining: 4
        )
        scene.addEnemyForTesting(frozenEnemy)

        scene.shatterFrozenContactEnemiesForTesting()

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testFreezeBurstCapsContactPulsesWithoutDroppingFrozenEnemies() {
        let scene = makeActiveScene()
        let enemies = (1...64).map {
            ArenaEnemy(
                id: 300 + $0,
                position: CGPoint(x: CGFloat($0), y: 80),
                radius: 4,
                speed: 0
            )
        }
        for enemy in enemies {
            scene.addEnemyForTesting(enemy)
        }

        let enemyIDs = Set(enemies.map(\.id))
        scene.freezeEnemiesForTesting(ids: enemyIDs, duration: 4)

        XCTAssertEqual(scene.frozenEnemyIDsForTesting, enemyIDs)
        XCTAssertEqual(
            scene.weaponEffectNodeCountForTesting,
            WeaponImpactPlan.maximumVisualTargetCount
        )
    }

    func testControlAndArenaClearsSuppressSplitterChildren() {
        for weaponKind in [WeaponKind.freezeBurst, .gravityWell, .novaBomb] {
            let scene = makeActiveScene()
            let splitter = ArenaEnemy(
                id: 207,
                position: CGPoint(x: 80, y: 80),
                radius: 8,
                speed: 70,
                behavior: .splitter
            )
            scene.addEnemyForTesting(splitter)

            scene.destroyEnemiesForTesting(ids: [splitter.id], weaponKind: weaponKind)

            XCTAssertTrue(scene.enemyIDsForTesting.isEmpty, "\(weaponKind) should fully clear splitters")
        }
    }

    func testDirectDamageStillTriggersSplitterChildren() {
        let scene = makeActiveScene()
        let splitter = ArenaEnemy(
            id: 208,
            position: CGPoint(x: 80, y: 80),
            radius: 8,
            speed: 70,
            behavior: .splitter
        )
        scene.addEnemyForTesting(splitter)

        scene.destroyEnemiesForTesting(ids: [splitter.id], weaponKind: .shockwave)

        XCTAssertEqual(scene.enemyIDsForTesting.count, 2)
        XCTAssertFalse(scene.enemyIDsForTesting.contains(splitter.id))
    }

    func testPostWeaponSafetyHonorsMinimumEffectTravelDuration() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 201, position: playerPosition, radius: 10, speed: 0)

        scene.addEnemyForTesting(enemy)
        scene.grantPostWeaponSafetyForTesting(.novaBomb, minimumDuration: 1.5)
        scene.advancePostWeaponSafetyForTesting(deltaTime: 1)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertFalse(scene.isRunGameOverForTesting)

        scene.advancePostWeaponSafetyForTesting(deltaTime: 0.51)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)

        XCTAssertTrue(scene.isRunGameOverForTesting)
    }

    func testNovaClearResolvesBeforeCollisionWhenDroppedFrameCrossesDeadline() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 204, position: playerPosition, radius: 10, speed: 0)

        scene.addEnemyForTesting(enemy)
        scene.activateNovaBombForTesting(enemyIDs: [enemy.id])
        scene.updateActiveRunForTesting(
            deltaTime: scene.weaponEffectTiming.maximumWaveTravelDuration + 0.01
        )

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testRazorShieldResolvesContactBeforeEnemyCanDamagePlayerOrQueueDuplicateBolts() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 201, position: playerPosition, radius: 10, speed: 0)
        let configuration = StartingWeaponConfiguration(
            razorShieldRadius: 24,
            razorShieldDuration: 1
        )

        scene.addEnemyForTesting(enemy)
        scene.activateRazorShieldForTesting(configuration: configuration)
        scene.updateRazorShieldForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)
        XCTAssertFalse(scene.isRunGameOverForTesting)

        let effectNodeCountAfterContact = scene.weaponEffectNodeCountForTesting
        XCTAssertLessThanOrEqual(effectNodeCountAfterContact, 12)
        scene.updateRazorShieldForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, effectNodeCountAfterContact)
    }

    func testZeroDurationRazorShieldCompletesImmediatelyWithExplosionSafety() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 202, position: playerPosition, radius: 10, speed: 0)
        let configuration = StartingWeaponConfiguration(
            razorShieldRadius: 24,
            razorShieldDuration: 0,
            razorShieldExplosionRadius: 48
        )

        scene.addEnemyForTesting(enemy)
        scene.activateRazorShieldForTesting(configuration: configuration)

        XCTAssertFalse(scene.isRazorShieldActiveForTesting)
        XCTAssertTrue(scene.isPostWeaponSafeForTesting)
        XCTAssertGreaterThan(scene.weaponEffectNodeCountForTesting, 0)

        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)
        XCTAssertFalse(scene.isRunGameOverForTesting)
    }

    func testZeroDurationTimeDilationCompletesWithoutLeavingAuraState() {
        let scene = makeActiveScene()
        let configuration = StartingWeaponConfiguration(timeDilationDuration: 0)

        scene.activateTimeDilationAuraForTesting(configuration: configuration)

        XCTAssertFalse(scene.isTimeDilationAuraActiveForTesting)
        XCTAssertTrue(scene.isPostWeaponSafeForTesting)
    }

    func testTimeDilationSlowsEnemiesBelowAndAboveTheirSpeedCap() throws {
        for speed: CGFloat in [40, 1_000] {
            let normalScene = makeActiveScene()
            let slowedScene = makeActiveScene()
            let playerPosition = normalScene.playerPositionForTesting
            let enemy = ArenaEnemy(
                id: 203,
                position: CGPoint(x: playerPosition.x + 60, y: playerPosition.y),
                radius: 4,
                speed: speed
            )
            normalScene.addEnemyForTesting(enemy)
            slowedScene.addEnemyForTesting(enemy)
            let normalNode = try XCTUnwrap(normalScene.gameplayChildrenForTesting.compactMap { $0 as? EnemyNode }.first)
            let slowedNode = try XCTUnwrap(slowedScene.gameplayChildrenForTesting.compactMap { $0 as? EnemyNode }.first)
            slowedScene.activateTimeDilationAuraForTesting(configuration: StartingWeaponConfiguration(
                timeDilationRadius: 120,
                timeDilationMaximumSlowFactor: 3,
                timeDilationPushRadius: 0
            ))

            normalScene.updateActiveRunForTesting(deltaTime: 1.0 / 60)
            slowedScene.updateActiveRunForTesting(deltaTime: 1.0 / 60)

            let normalDistance = enemy.position.x - normalNode.position.x
            let slowedDistance = enemy.position.x - slowedNode.position.x
            XCTAssertGreaterThan(normalDistance, 0)
            // Halfway into a factor-three aura, actual movement should be halved.
            XCTAssertEqual(slowedDistance, normalDistance / 2, accuracy: 0.0001, "Base speed: \(speed)")
        }
    }

    func testFlameTrailResolvesBurnBeforeEnemyCanDamagePlayerOrQueueDuplicateBursts() {
        let scene = makeActiveScene()
        let playerPosition = scene.playerPositionForTesting
        let enemy = ArenaEnemy(id: 203, position: playerPosition, radius: 10, speed: 0)
        let configuration = FlameTrailConfiguration(
            duration: 0.3,
            segmentLifetime: 1,
            segmentRadius: 16,
            segmentSpacing: 14,
            maxSegments: 4,
            invulnerabilityDuration: 0,
            speedMultiplier: 1
        )

        scene.addEnemyForTesting(enemy)
        scene.activateFlameTrailForTesting(configuration: configuration)
        scene.updateFlameTrailForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        scene.detectPlayerCollisionForTesting(playerPosition: playerPosition)
        XCTAssertFalse(scene.isRunGameOverForTesting)

        let effectNodeCountAfterBurn = scene.weaponEffectNodeCountForTesting
        XCTAssertLessThanOrEqual(effectNodeCountAfterBurn, 12)
        scene.updateFlameTrailForTesting(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, effectNodeCountAfterBurn)
    }

    func testNonFiniteFrameTimeDoesNotPoisonLaterGameplayUpdates() {
        let scene = makeActiveScene()

        scene.update(1)
        scene.update(.nan)
        scene.update(2)
        scene.update(2 + 1.0 / 60.0)

        XCTAssertEqual(scene.runSurvivalTimeForTesting, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testDeathTransitionCompletesAfterSceneActionsAreRemoved() {
        let scene = makeActiveScene()

        scene.finishRunWithFeedbackForTesting()
        XCTAssertEqual(scene.uiStateForTesting, .activeGameplay)
        XCTAssertTrue(scene.isResolvingDeathForTesting)

        scene.removeAllActions()
        scene.update(1)
        for frame in 1...4 {
            scene.update(1 + Double(frame) / 15.0)
        }

        XCTAssertEqual(scene.uiStateForTesting, .postRun)
        XCTAssertFalse(scene.isResolvingDeathForTesting)
    }

    func testOverlappingWeaponEffectsCannotClaimTheSameEnemyTwice() {
        let scene = makeActiveScene()
        let first = WeaponActivation(kind: .seekerSwarm)
        let second = WeaponActivation(kind: .chainLightning)
        scene.addEnemyForTesting(ArenaEnemy(id: 700, position: .zero, radius: 8, speed: 0))
        scene.destroyEnemiesForTesting(ids: [700], weaponKind: first.kind, activation: first)
        scene.destroyEnemiesForTesting(ids: [700], weaponKind: second.kind, activation: second)
        XCTAssertEqual(first.killCount, 1)
        XCTAssertEqual(second.killCount, 0)
        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
    }

    func testFrozenContactShattersRetainOneActivationAcrossSeparateClears() {
        let scene = makeActiveScene()
        let activation = WeaponActivation(kind: .freezeBurst)
        for enemyID in 701...702 {
            scene.addEnemyForTesting(ArenaEnemy(
                id: enemyID, position: scene.playerPositionForTesting, radius: 8, speed: 0
            ))
            scene.freezeEnemiesForTesting(ids: [enemyID], duration: 2, activation: activation)
            scene.shatterFrozenContactEnemiesForTesting()
        }
        XCTAssertEqual(activation.killCount, 2)
        XCTAssertTrue(activation.hasQualifiedClear)
        scene.shatterFrozenContactEnemiesForTesting()
        XCTAssertEqual(activation.killCount, 2)
    }

    func testGravityFieldPullsLateEntrantsButDoesNotTetherOutsideEnemies() throws {
        let scene = makeActiveScene()
        scene.activateGravityWellForTesting(center: .zero, configuration: StartingWeaponConfiguration(
            gravityWellRadius: 100, gravityWellActivationDelay: 0, gravityWellPullDuration: 2, gravityWellClearRadius: 10
        ))
        scene.addEnemyForTesting(ArenaEnemy(id: 800, position: CGPoint(x: 80, y: 0), radius: 2, speed: 0))
        scene.addEnemyForTesting(ArenaEnemy(id: 801, position: CGPoint(x: 130, y: 0), radius: 2, speed: 0))
        scene.updateGravityWellForTesting(deltaTime: 0.5)
        XCTAssertEqual(try XCTUnwrap(scene.enemyPositionForTesting(id: 800)).x, 55, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(scene.enemyPositionForTesting(id: 801)).x, 130, accuracy: 0.0001)
        scene.addEnemyForTesting(ArenaEnemy(id: 802, position: .zero, radius: 2, speed: 0))
        scene.updateGravityWellForTesting(deltaTime: 0)
        XCTAssertFalse(scene.enemyIDsForTesting.contains(802))
    }

    func testReplacingGravityWellRemovesOldFieldWithoutAnExtraClear() {
        let scene = makeActiveScene()
        let configuration = StartingWeaponConfiguration(gravityWellRadius: 50, gravityWellClearRadius: 10)
        scene.activateGravityWellForTesting(center: .zero, configuration: configuration)
        scene.activateGravityWellForTesting(center: CGPoint(x: 200, y: 0), configuration: configuration)
        scene.addEnemyForTesting(ArenaEnemy(id: 803, position: .zero, radius: 2, speed: 0))
        scene.addEnemyForTesting(ArenaEnemy(id: 804, position: CGPoint(x: 200, y: 0), radius: 2, speed: 0))
        scene.updateGravityWellForTesting(deltaTime: 0.1)
        XCTAssertTrue(scene.enemyIDsForTesting.contains(803))
        XCTAssertFalse(scene.enemyIDsForTesting.contains(804))
    }

    func testEveryWeaponProvidesImmediateCollectionGrace() {
        for kind in WeaponKind.allCases {
            let scene = makeActiveScene()
            scene.collectWeaponForTesting(kind)
            XCTAssertGreaterThanOrEqual(scene.postWeaponSafetyRemainingForTesting, 0.2, "\(kind)")
        }
    }

    func testCollectionGraceRefreshesWithoutStackingDurations() {
        let scene = makeActiveScene()
        scene.collectWeaponForTesting(.shockwave)
        scene.advancePostWeaponSafetyForTesting(deltaTime: 0.1)
        scene.collectWeaponForTesting(.freezeBurst, id: 2)
        XCTAssertEqual(scene.postWeaponSafetyRemainingForTesting, 0.2, accuracy: 0.0001)
        scene.advancePostWeaponSafetyForTesting(deltaTime: 0.21)
        XCTAssertFalse(scene.isPostWeaponSafeForTesting)
    }

    func testSeekerProtectionHasOneScheduledDeadlineThatImpactsCannotExtend() {
        let scene = makeActiveScene()
        let center = scene.playerPositionForTesting
        let target = WeaponImpactTarget(id: 900, position: CGPoint(x: center.x + 100, y: center.y))
        scene.addEnemyForTesting(ArenaEnemy(id: target.id, position: target.position, radius: 5, speed: 0))
        scene.collectWeaponForTesting(.seekerSwarm)
        let duration = scene.postWeaponSafetyRemainingForTesting
        XCTAssertGreaterThan(duration, 0.5)
        XCTAssertLessThanOrEqual(duration, 1.165)
        scene.advancePostWeaponSafetyForTesting(deltaTime: duration + 0.01)
        scene.resolveSeekerExplosionForTesting(at: target)
        XCTAssertFalse(scene.isPostWeaponSafeForTesting)
    }

    func testRetryHasNoGameplayDuringCountdownAndIgnoresDuplicateTaps() {
        let scene = makeActiveScene()
        scene.finishRunForTesting()
        scene.retryRunForTesting()
        let startPosition = scene.playerPositionForTesting
        scene.update(0)
        for frame in 1...44 { scene.update(Double(frame) / 60) }
        XCTAssertEqual(scene.uiStateForTesting, .preRun)
        XCTAssertEqual(scene.runSurvivalTimeForTesting, 0)
        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
        XCTAssertEqual(scene.pickupCountForTesting, 0)
        XCTAssertEqual(scene.playerPositionForTesting, startPosition)
        scene.retryRunForTesting()
        for frame in 45...46 { scene.update(Double(frame) / 60) }
        XCTAssertEqual(scene.uiStateForTesting, .activeGameplay)
    }

    func testBackgroundingCancelsPendingRetry() {
        let scene = makeActiveScene()
        scene.finishRunForTesting()
        scene.retryRunForTesting()
        scene.pauseActiveRunIfNeeded()
        scene.update(0)
        for frame in 1...300 { scene.update(Double(frame) / 60) }
        XCTAssertEqual(scene.uiStateForTesting, .home)
        XCTAssertEqual(scene.runSurvivalTimeForTesting, 0)
        XCTAssertTrue(scene.enemyIDsForTesting.isEmpty)
    }

    private func makeActiveScene() -> ArenaScene {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        scene.prepareActiveRunForTesting()
        return scene
    }
}
