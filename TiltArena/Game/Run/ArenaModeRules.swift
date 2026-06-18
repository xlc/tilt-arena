import Foundation

struct ArenaModeRunSettings: Equatable {
    let enemySpawnConfiguration: EnemySpawnConfiguration
    let pickupSpawnConfiguration: PickupSpawnConfiguration
    let sequenceSeed: Int?
}

struct ArenaModeRules {
    static let redlineBestScoreRequirement = ArenaProgressionRules.redlineBestScoreRequirement

    static func isAvailable(_ mode: ArenaModeKind, profile: RunProfile) -> Bool {
        switch mode {
        case .classic:
            return true
        case .redline:
            return ArenaProgressionRules.isRedlineAvailable(profile: profile)
        case .daily:
            return ArenaProgressionRules.isDailyAvailable(profile: profile)
        }
    }

    static func subtitle(for mode: ArenaModeKind) -> String {
        switch mode {
        case .classic:
            return "Classic Survival"
        case .redline:
            return "Faster pressure curve"
        case .daily:
            return "Local fixed-seed arena"
        }
    }

    static func statusText(for mode: ArenaModeKind, selectedMode: ArenaModeKind, profile: RunProfile) -> String {
        guard isAvailable(mode, profile: profile) else {
            return "LOCKED"
        }

        return mode == selectedMode ? "SELECTED" : "AVAILABLE"
    }

    static func progressText(for mode: ArenaModeKind, profile: RunProfile) -> String {
        switch mode {
        case .classic:
            return "BEST \(profile.bestScore)"
        case .redline:
            return "\(min(profile.bestScore, redlineBestScoreRequirement))/\(redlineBestScoreRequirement) CLASSIC BEST"
        case .daily:
            return "\(ArenaProgressionRules.unlockedWeapons(for: profile).count)/\(ArenaProgressionRules.allGameplayWeapons.count) WEAPONS"
        }
    }

    static func activeUnlockText(profile: RunProfile) -> String {
        ArenaProgressionRules.nextUnlockText(profile: profile)
    }

    static func runSettings(
        for mode: ArenaModeKind,
        profile: RunProfile? = nil,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> ArenaModeRunSettings {
        let settings: ArenaModeRunSettings

        switch mode {
        case .classic:
            settings = ArenaModeRunSettings(
                enemySpawnConfiguration: EnemySpawnConfiguration(),
                pickupSpawnConfiguration: PickupSpawnConfiguration(),
                sequenceSeed: nil
            )
        case .redline:
            settings = ArenaModeRunSettings(
                enemySpawnConfiguration: redlineEnemySpawnConfiguration(),
                pickupSpawnConfiguration: redlinePickupSpawnConfiguration(),
                sequenceSeed: nil
            )
        case .daily:
            settings = ArenaModeRunSettings(
                enemySpawnConfiguration: EnemySpawnConfiguration(),
                pickupSpawnConfiguration: PickupSpawnConfiguration(),
                sequenceSeed: dailySeed(for: date, calendar: calendar)
            )
        }

        guard let profile else {
            return settings
        }

        var pickupSpawnConfiguration = settings.pickupSpawnConfiguration
        pickupSpawnConfiguration.weaponKindCycle = ArenaProgressionRules.filteredWeaponCycle(
            pickupSpawnConfiguration.weaponKindCycle,
            profile: profile
        )

        return ArenaModeRunSettings(
            enemySpawnConfiguration: settings.enemySpawnConfiguration,
            pickupSpawnConfiguration: pickupSpawnConfiguration,
            sequenceSeed: settings.sequenceSeed
        )
    }

    static func dailySeed(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = max(0, components.year ?? 0)
        let month = max(0, components.month ?? 0)
        let day = max(0, components.day ?? 0)
        return year * 10_000 + month * 100 + day
    }

    private static func redlineEnemySpawnConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        applyRedlineEnemySpawnOverrides(to: &configuration)
        configuration.warmup = redlineWarmupTuning()
        configuration.pressure = redlinePressureTuning()
        configuration.chaos = redlineChaosTuning()
        configuration.survivalHell = redlineSurvivalHellTuning()
        return configuration
    }

    private static func applyRedlineEnemySpawnOverrides(to configuration: inout EnemySpawnConfiguration) {
        configuration.enemySurvivalSpeedStartMultiplier = 0.9
        configuration.enemySurvivalSpeedRampDuration = 95
        configuration.maximumEnemySurvivalSpeedMultiplier = 1.52
        configuration.enemySpeedRampPerSecond = 0.036
        configuration.maximumEnemySpeedMultiplier = 2.25
        configuration.playerSafetyRadius = 100
        configuration.spawnWarningDuration = 0.35
        configuration.spawnPlayerCollisionGraceDuration = 0.32
        configuration.maxPendingSpawnWarnings = 5
        configuration.maxPendingEnemyTelegraphs = 3
        configuration.formationTelegraphDuration = 0.95
        configuration.arrowRushTelegraphDuration = 0.68
        configuration.mineDotTelegraphDuration = 0.72
        configuration.hunterDotTelegraphDuration = 0.6
        configuration.paddleTrapTelegraphDuration = 0.82
    }

    private static func redlineWarmupTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.54,
            chaserSpeed: 104,
            maxActiveEnemies: 88,
            formationSpawnInterval: 5.6,
            formationSpeed: 142,
            formationLaneCount: 5,
            arrowRushSpawnInterval: 9.5,
            arrowRushSpeed: 206,
            arrowRushEnemyCount: 2
        )
    }

    private static func redlinePressureTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.36,
            chaserSpeed: 130,
            maxActiveEnemies: 136,
            formationSpawnInterval: 3.5,
            formationSpeed: 166,
            formationLaneCount: 7,
            arrowRushSpawnInterval: 5.6,
            arrowRushSpeed: 224,
            arrowRushEnemyCount: 4,
            mineDotSpawnInterval: 8.4,
            maxActiveMineDots: 5,
            hunterDotSpawnInterval: 9.5,
            hunterDotSpeed: 162,
            hunterDotPredictionLead: 0.75,
            maxActiveHunterDots: 2,
            paddleTrapSpawnInterval: 13.5,
            maxActivePaddleTraps: 1,
            paddleTrapLifetime: 7,
            paddleTrapBarEnemyCount: 4,
            paddleTrapDotSpeed: 202,
            splitterSpawnInterval: 8.8,
            splitterSpeed: 98,
            maxActiveSplitters: 3
        )
    }

    private static func redlineChaosTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.25,
            chaserSpeed: 162,
            maxActiveEnemies: 192,
            formationSpawnInterval: 2.45,
            formationSpeed: 198,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 3.8,
            arrowRushSpeed: 266,
            arrowRushEnemyCount: 6,
            mineDotSpawnInterval: 5.0,
            maxActiveMineDots: 8,
            hunterDotSpawnInterval: 6.3,
            hunterDotSpeed: 206,
            hunterDotPredictionLead: 1.05,
            maxActiveHunterDots: 4,
            paddleTrapSpawnInterval: 8.8,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 252,
            splitterSpawnInterval: 6.4,
            splitterSpeed: 128,
            maxActiveSplitters: 4
        )
    }

    private static func redlineSurvivalHellTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.18,
            chaserSpeed: 194,
            maxActiveEnemies: 270,
            formationSpawnInterval: 1.95,
            formationSpeed: 236,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 2.9,
            arrowRushSpeed: 308,
            arrowRushEnemyCount: 7,
            mineDotSpawnInterval: 4.0,
            maxActiveMineDots: 11,
            hunterDotSpawnInterval: 4.8,
            hunterDotSpeed: 242,
            hunterDotPredictionLead: 1.25,
            maxActiveHunterDots: 5,
            paddleTrapSpawnInterval: 6.8,
            maxActivePaddleTraps: 3,
            paddleTrapLifetime: 9,
            paddleTrapBarEnemyCount: 6,
            paddleTrapDotSpeed: 288,
            splitterSpawnInterval: 5.0,
            splitterSpeed: 156,
            maxActiveSplitters: 5
        )
    }

    private static func redlinePickupSpawnConfiguration() -> PickupSpawnConfiguration {
        PickupSpawnConfiguration(
            refillDelay: 0.75,
            chargedPickupDelay: 3.8,
            overchargedPickupDelay: 7.2,
            maxActivePickups: 2,
            playerClearance: 104,
            enemyClearance: 4,
            weaponKindCycle: [
                .flameTrail,
                .warpDash,
                .freezeBurst,
                .gravityWell,
                .chainLightning,
                .seekerSwarm,
                .flameTrail,
                .warpDash,
                .powerWave,
                .ricochetLance,
                .freezeBurst,
                .gravityWell,
                .razorShield,
                .chainLightning,
                .flameTrail,
                .warpDash,
                .powerWave,
                .ricochetLance,
                .shockwave
            ]
        )
    }
}
