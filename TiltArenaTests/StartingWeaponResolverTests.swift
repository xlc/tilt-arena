import UIKit
import XCTest
@testable import TiltArena

final class StartingWeaponResolverTests: XCTestCase {
    func testDefaultShockwaveTuningKeepsWaveReadableAndLargerThanShieldBurst() {
        let configuration = StartingWeaponConfiguration()

        XCTAssertGreaterThan(configuration.shockwaveRadius, configuration.razorShieldExplosionRadius)
        XCTAssertGreaterThan(configuration.shockwaveExpansionDuration, 0)
        XCTAssertGreaterThanOrEqual(configuration.shockwaveHoldDuration, 0)
        XCTAssertLessThanOrEqual(configuration.shockwaveHoldDuration, configuration.shockwaveExpansionDuration)
    }

    @MainActor
    func testWeaponSpriteSheetFramesContainGlyphsWithTransparentGutters() throws {
        let image = try XCTUnwrap(UIImage(named: WeaponSpriteSheet.assetName)?.cgImage)
        for kind in WeaponKind.allCases {
            let frame = WeaponSpriteSheet.textureRect(for: kind)
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(frame))
            let sourceRect = CGRect(
                x: frame.minX * CGFloat(image.width),
                y: (1 - frame.maxY) * CGFloat(image.height),
                width: frame.width * CGFloat(image.width),
                height: frame.height * CGFloat(image.height)
            ).integral
            let glyph = try XCTUnwrap(image.cropping(to: sourceRect))
            let width = glyph.width
            let height = glyph.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            try pixels.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(glyph, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            var opaquePixels = 0
            var borderAlpha: UInt8 = 0
            for y in 0..<height {
                for x in 0..<width {
                    let alpha = pixels[(y * width + x) * 4 + 3]
                    if alpha > 240 { opaquePixels += 1 }
                    if x < 4 || y < 4 || x >= width - 4 || y >= height - 4 {
                        borderAlpha = max(borderAlpha, alpha)
                    }
                }
            }
            XCTAssertGreaterThan(opaquePixels, 1_000, "Missing glyph: \(kind)")
            XCTAssertLessThan(opaquePixels, width * height / 2, "Opaque background: \(kind)")
            XCTAssertLessThan(borderAlpha, 8, "Clipped or bleeding glyph: \(kind)")
        }
    }

    func testDefaultWeaponTuningKeepsWeaponFamiliesInDistinctRoles() {
        let configuration = StartingWeaponConfiguration()
        let flameTrailConfiguration = FlameTrailConfiguration()

        XCTAssertGreaterThan(configuration.seekerExplosionRadius, 0)
        XCTAssertGreaterThan(configuration.seekerTravelSpeed, 0)
        XCTAssertGreaterThan(configuration.razorShieldExplosionRadius, configuration.razorShieldRadius)
        XCTAssertGreaterThan(configuration.freezeBurstRadius, configuration.shockwaveRadius)
        XCTAssertGreaterThan(configuration.freezeDuration, configuration.freezeExpansionDuration)
        XCTAssertGreaterThan(configuration.gravityWellRadius, configuration.gravityWellClearRadius)
        XCTAssertGreaterThan(configuration.gravityWellPullDuration, configuration.gravityWellActivationDelay)
        XCTAssertGreaterThan(configuration.chainLightningInitialRange, configuration.chainLightningJumpRange)
        XCTAssertGreaterThan(configuration.chainLightningTargetLimit, configuration.seekerTargetLimit)
        XCTAssertGreaterThan(flameTrailConfiguration.segmentLifetime, flameTrailConfiguration.duration)
        XCTAssertGreaterThan(flameTrailConfiguration.segmentRadius, 0)
        XCTAssertGreaterThan(flameTrailConfiguration.speedMultiplier, 1)
        XCTAssertGreaterThan(configuration.timeDilationRadius, configuration.timeDilationPushRadius)
        XCTAssertGreaterThan(configuration.timeDilationDuration, 0)
        XCTAssertGreaterThan(configuration.timeDilationMaximumSlowFactor, 1)
        XCTAssertGreaterThan(configuration.powerWaveRange, configuration.timeDilationPushRadius)
        XCTAssertGreaterThan(configuration.powerWaveFanAngleDegrees, 0)
        XCTAssertLessThanOrEqual(configuration.powerWaveFanAngleDegrees, 360)
        XCTAssertGreaterThan(configuration.ricochetLanceBeamWidth, 0)
        XCTAssertEqual(configuration.ricochetLanceMaximumBounces, 1)
        XCTAssertGreaterThan(configuration.ricochetLanceHoldDuration, 0)
        XCTAssertEqual(configuration.novaBombTargetFraction, 0.5)
    }

    func testBaseWeaponConfigurationPreservesEveryConfiguredValue() {
        let base = StartingWeaponConfiguration(
            shockwaveRadius: 103,
            seekerTargetLimit: 7,
            ricochetLanceMaximumBounces: 3,
            novaBombTargetFraction: 0.4
        )

        XCTAssertEqual(base.applying(chargeTier: .base), base)
    }

    func testChargedWeaponConfigurationAppliesMeaningfulUpgradeFromConfiguredBase() {
        let base = StartingWeaponConfiguration(
            shockwaveRadius: 100,
            seekerTargetLimit: 4,
            chainLightningTargetLimit: 6,
            ricochetLanceMaximumBounces: 3,
            novaBombTargetFraction: 0.4
        )

        let charged = base.applying(chargeTier: .charged)
        let overcharged = base.applying(chargeTier: .overcharged)

        XCTAssertGreaterThan(charged.shockwaveRadius, base.shockwaveRadius)
        XCTAssertGreaterThan(overcharged.shockwaveRadius, charged.shockwaveRadius)
        XCTAssertGreaterThan(charged.seekerTargetLimit, base.seekerTargetLimit)
        XCTAssertGreaterThan(overcharged.seekerTargetLimit, charged.seekerTargetLimit)
        XCTAssertGreaterThan(charged.chainLightningTargetLimit, base.chainLightningTargetLimit)
        XCTAssertGreaterThan(overcharged.chainLightningTargetLimit, charged.chainLightningTargetLimit)
        XCTAssertEqual(charged.ricochetLanceMaximumBounces, 4)
        XCTAssertEqual(overcharged.ricochetLanceMaximumBounces, 5)
        XCTAssertEqual(charged.novaBombTargetFraction, 0.65, accuracy: 0.0001)
        XCTAssertEqual(overcharged.novaBombTargetFraction, 0.9, accuracy: 0.0001)
    }

    func testChargedNovaBombTargetFractionIsCappedAtOne() {
        let base = StartingWeaponConfiguration(novaBombTargetFraction: 0.8)

        XCTAssertEqual(base.applying(chargeTier: .charged).novaBombTargetFraction, 1)
        XCTAssertEqual(base.applying(chargeTier: .overcharged).novaBombTargetFraction, 1)
    }

    func testRazorShieldMergePreservesStrongestCoverage() {
        let current = StartingWeaponConfiguration(
            razorShieldRadius: 64,
            razorShieldDuration: 1,
            razorShieldExplosionRadius: 20
        )
        let incoming = StartingWeaponConfiguration(
            razorShieldRadius: 12,
            razorShieldDuration: 8,
            razorShieldExplosionRadius: 80
        )

        let merged = current.mergingRazorShield(with: incoming)

        XCTAssertEqual(merged.razorShieldRadius, current.razorShieldRadius)
        XCTAssertEqual(merged.razorShieldDuration, incoming.razorShieldDuration)
        XCTAssertEqual(merged.razorShieldExplosionRadius, incoming.razorShieldExplosionRadius)
    }

    func testTimeDilationMergePreservesStrongestControl() {
        let current = StartingWeaponConfiguration(
            timeDilationRadius: 180,
            timeDilationDuration: 1,
            timeDilationMaximumSlowFactor: 9,
            timeDilationPushRadius: 20,
            timeDilationMaximumPushDistance: 40
        )
        let incoming = StartingWeaponConfiguration(
            timeDilationRadius: 40,
            timeDilationDuration: 8,
            timeDilationMaximumSlowFactor: 2,
            timeDilationPushRadius: 60,
            timeDilationMaximumPushDistance: 200
        )

        let merged = current.mergingTimeDilation(with: incoming)

        XCTAssertEqual(merged.timeDilationRadius, current.timeDilationRadius)
        XCTAssertEqual(merged.timeDilationDuration, incoming.timeDilationDuration)
        XCTAssertEqual(merged.timeDilationMaximumSlowFactor, current.timeDilationMaximumSlowFactor)
        XCTAssertEqual(merged.timeDilationPushRadius, incoming.timeDilationPushRadius)
        XCTAssertEqual(merged.timeDilationMaximumPushDistance, incoming.timeDilationMaximumPushDistance)
    }

    func testShockwaveClearsEnemiesInsideRadius() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(shockwaveRadius: 50)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 60, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .shockwave,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [1])
    }

    func testSeekerSwarmClearsNearestCappedEnemies() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(seekerTargetLimit: 2)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 200, y: 0)),
            enemy(id: 2, position: CGPoint(x: 20, y: 0)),
            enemy(id: 3, position: CGPoint(x: 60, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .seekerSwarm,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [2, 3])
    }

    func testSeekerExplosionTargetsEnemiesInsideExplosionRadius() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(seekerExplosionRadius: 30)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 22, y: 0)),
            enemy(id: 2, position: CGPoint(x: 38, y: 0)),
            enemy(id: 3, position: CGPoint(x: 64, y: 0))
        ]

        XCTAssertEqual(
            resolver.seekerExplosionTargets(center: .zero, enemies: enemies),
            [1, 2]
        )
    }

    func testRazorShieldClearsContactEnemies() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(razorShieldRadius: 24)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 28, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .razorShield,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolver.shieldTargets(playerPosition: .zero, enemies: enemies), [1])
    }

    func testRazorShieldExplosionUsesExpandedExpiryRadius() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(
                razorShieldRadius: 24,
                razorShieldExplosionRadius: 40
            )
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 28, y: 0)),
            enemy(id: 2, position: CGPoint(x: 46, y: 0)),
            enemy(id: 3, position: CGPoint(x: 80, y: 0))
        ]

        XCTAssertEqual(resolver.shieldTargets(playerPosition: .zero, enemies: enemies), [1])
        XCTAssertEqual(resolver.shieldExplosionTargets(playerPosition: .zero, enemies: enemies), [1, 2])
    }

    func testFreezeBurstFreezesEnemiesInsideRadiusWithoutDestroyingThem() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(freezeBurstRadius: 50)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .freezeBurst,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [1])
    }

    func testFreezeBurstHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .freezeBurst,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
    }

    func testGravityWellTargetsEnemiesInsideRadiusIncludingFrozenEnemiesWithoutDestroyingThem() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(gravityWellRadius: 50)
        )
        var frozenEnemy = enemy(id: 3, position: CGPoint(x: 20, y: 0))
        frozenEnemy.freeze(duration: 1, thawGraceDuration: 0.35)
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0)),
            frozenEnemy
        ]

        let resolution = resolver.resolve(
            kind: .gravityWell,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [1, 3])
    }

    func testGravityWellCollapseCanClearFrozenEnemiesInsideClearRadius() {
        var frozenEnemy = enemy(id: 3, position: CGPoint(x: 20, y: 0))
        frozenEnemy.freeze(duration: 1, thawGraceDuration: 0.35)
        let state = GravityWellState(
            center: .zero,
            timeRemaining: 0,
            clearRadius: 24
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 12, y: 0)),
            enemy(id: 2, position: CGPoint(x: 80, y: 0)),
            frozenEnemy
        ]

        XCTAssertEqual(
            state.collapseTargets(enemies: enemies),
            [1, 3]
        )
    }

    func testGravityWellHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .gravityWell,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
    }

    func testChainLightningDestroysOrderedChainedTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 100, y: 0)),
            enemy(id: 2, position: CGPoint(x: 150, y: 0)),
            enemy(id: 3, position: CGPoint(x: 210, y: 0)),
            enemy(id: 4, position: CGPoint(x: 60, y: 90))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [1, 2, 3])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [1, 2, 3])
    }

    func testChainLightningStopsWhenNextTargetIsOutOfJumpRange() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 100, y: 0)),
            enemy(id: 2, position: CGPoint(x: 210, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [1])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [1])
    }

    func testChainLightningRespectsTargetLimit() {
        let resolver = StartingWeaponResolver(
            configuration: StartingWeaponConfiguration(chainLightningTargetLimit: 2)
        )
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 80, y: 0)),
            enemy(id: 2, position: CGPoint(x: 130, y: 0)),
            enemy(id: 3, position: CGPoint(x: 180, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [1, 2])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [1, 2])
    }

    func testChainLightningRequiresFirstTargetInsideInitialRange() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 141, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testChainLightningHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .chainLightning,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testNovaBombSelectionIsHandledOutsideResolver() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 200, y: 0)),
            enemy(id: 2, position: CGPoint(x: -40, y: 70)),
            enemy(id: 3, position: CGPoint(x: 0, y: -120))
        ]

        let resolution = resolver.resolve(
            kind: .novaBomb,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testRicochetLanceSelectionIsHandledOutsideResolver() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 20, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .ricochetLance,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
    }

    func testFlameTrailDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .flameTrail,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
    }

    func testTimeDilationDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .warpDash,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
    }

    func testPowerWaveDoesNotInstantlyResolveTargets() {
        let resolver = StartingWeaponResolver()
        let enemies = [
            enemy(id: 1, position: CGPoint(x: 10, y: 0))
        ]

        let resolution = resolver.resolve(
            kind: .powerWave,
            playerPosition: .zero,
            enemies: enemies
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
        XCTAssertEqual(resolution.frozenEnemyIDs, [])
        XCTAssertEqual(resolution.gravityWellEnemyIDs, [])
        XCTAssertEqual(resolution.chainLightningEnemyIDs, [])
    }

    func testNovaBombHandlesEmptyArena() {
        let resolver = StartingWeaponResolver()

        let resolution = resolver.resolve(
            kind: .novaBomb,
            playerPosition: .zero,
            enemies: []
        )

        XCTAssertEqual(resolution.destroyedEnemyIDs, [])
    }

    func testWeaponEffectTimingKeepsProjectileImpactsTrackable() {
        let timing = WeaponEffectTiming(
            projectileSpeed: 500,
            waveSpeed: 600,
            minimumTravelDuration: 0.08,
            maximumProjectileTravelDuration: 0.42,
            maximumWaveTravelDuration: 0.72
        )

        XCTAssertEqual(
            timing.projectileDuration(from: .zero, to: CGPoint(x: 100, y: 0)),
            0.2,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            timing.projectileDuration(from: .zero, to: CGPoint(x: 1_000, y: 0)),
            0.42,
            accuracy: 0.0001
        )
    }

    func testWeaponEffectTimingAccumulatesChainImpactDelays() {
        let timing = WeaponEffectTiming(
            projectileSpeed: 500,
            waveSpeed: 600,
            minimumTravelDuration: 0.08,
            maximumProjectileTravelDuration: 0.42,
            maximumWaveTravelDuration: 0.72
        )

        let delays = timing.chainImpactDelays(
            origin: .zero,
            targets: [
                CGPoint(x: 50, y: 0),
                CGPoint(x: 150, y: 0),
                CGPoint(x: 150, y: 40)
            ]
        )

        XCTAssertEqual(delays.count, 3)
        XCTAssertEqual(delays[0], 0.1, accuracy: 0.0001)
        XCTAssertEqual(delays[1], 0.3, accuracy: 0.0001)
        XCTAssertEqual(delays[2], 0.38, accuracy: 0.0001)
    }

    private func enemy(id: Int, position: CGPoint) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: 8, speed: 0)
    }
}
