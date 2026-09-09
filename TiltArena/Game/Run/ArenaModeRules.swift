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
            return "BEST \(profile.competitiveRecord(for: .classic).bestScore)"
        case .redline:
            if isAvailable(.redline, profile: profile) {
                return "BEST \(profile.competitiveRecord(for: .redline).bestScore)"
            }
            let classicBest = profile.competitiveRecord(for: .classic).bestScore
            return "\(min(classicBest, redlineBestScoreRequirement))/\(redlineBestScoreRequirement) CLASSIC BEST"
        case .daily:
            if isAvailable(.daily, profile: profile) {
                return "TODAY’S BEST \(profile.competitiveRecord(for: .daily).bestScore)"
            }
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
        let runSequenceSeed = sequenceSeed(for: mode, date: date, calendar: calendar)
        let settings: ArenaModeRunSettings

        switch mode {
        case .classic:
            settings = ArenaModeRunSettings(
                enemySpawnConfiguration: classicEnemySpawnConfiguration(),
                pickupSpawnConfiguration: PickupSpawnConfiguration(),
                sequenceSeed: runSequenceSeed
            )
        case .redline:
            settings = ArenaModeRunSettings(
                enemySpawnConfiguration: redlineEnemySpawnConfiguration(),
                pickupSpawnConfiguration: redlinePickupSpawnConfiguration(),
                sequenceSeed: runSequenceSeed
            )
        case .daily:
            settings = ArenaModeRunSettings(
                enemySpawnConfiguration: classicEnemySpawnConfiguration(),
                pickupSpawnConfiguration: PickupSpawnConfiguration(),
                sequenceSeed: runSequenceSeed
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

    static func sequenceSeed(
        for mode: ArenaModeKind,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        switch mode {
        case .classic, .redline:
            return nil
        case .daily:
            return dailySeed(for: date, calendar: calendar)
        }
    }

    static func dailySeed(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = max(0, components.year ?? 0)
        let month = max(0, components.month ?? 0)
        let day = max(0, components.day ?? 0)
        return year * 10_000 + month * 100 + day
    }

    private static func classicEnemySpawnConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.patternIntroductionSpacing = 0
        configuration.formationMinimumSurvivalTime = 30
        configuration.splitterMinimumSurvivalTime = 50
        configuration.mineDotMinimumSurvivalTime = 70
        configuration.arrowRushMinimumSurvivalTime = 95
        configuration.hunterDotMinimumSurvivalTime = 120
        configuration.paddleTrapMinimumSurvivalTime = 150
        configuration.pressure.mineDotSpawnInterval = 18
        configuration.pressure.maxActiveMineDots = 2
        return configuration
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
        configuration.chaserPlayerSpeedRatio = 0.82
        configuration.formationPlayerSpeedRatio = 1
        configuration.arrowRushPlayerSpeedRatio = 1.25
        configuration.hunterDotPlayerSpeedRatio = 0.95
        configuration.paddleTrapDotPlayerSpeedRatio = 1.1
        configuration.splitterPlayerSpeedRatio = 0.72
        configuration.splitterChildPlayerSpeedRatio = 0.9
        configuration.playerSafetyRadius = 100
        configuration.paddleTrapPlayerSafetyRadius = 56
        configuration.spawnWarningDuration = 0.35
        configuration.spawnPlayerCollisionGraceDuration = 0.32
        configuration.maxPendingSpawnWarnings = 5
        configuration.maxPendingEnemyTelegraphs = 3
        configuration.patternIntroductionSpacing = 0
        configuration.formationMinimumSurvivalTime = 0
        configuration.arrowRushMinimumSurvivalTime = 0
        configuration.splitterMinimumSurvivalTime = 15
        configuration.mineDotMinimumSurvivalTime = 30
        configuration.hunterDotMinimumSurvivalTime = 45
        configuration.paddleTrapMinimumSurvivalTime = 60
        configuration.formationTelegraphDuration = 0.95
        configuration.arrowRushTelegraphDuration = 0.68
        configuration.mineDotTelegraphDuration = 0.72
        configuration.hunterDotTelegraphDuration = 0.6
        configuration.paddleTrapTelegraphDuration = 0.82
    }

    private static func redlineWarmupTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.54,
            chaserSpeed: 112,
            maxActiveEnemies: 88,
            formationSpawnInterval: 5.6,
            formationSpeed: 154,
            formationLaneCount: 5,
            arrowRushSpawnInterval: 9.5,
            arrowRushSpeed: 236,
            arrowRushEnemyCount: 2,
            splitterSpawnInterval: 12,
            splitterSpeed: 92,
            maxActiveSplitters: 2
        )
    }

    private static func redlinePressureTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.36,
            chaserSpeed: 142,
            maxActiveEnemies: 136,
            formationSpawnInterval: 3.5,
            formationSpeed: 186,
            formationLaneCount: 7,
            arrowRushSpawnInterval: 5.6,
            arrowRushSpeed: 264,
            arrowRushEnemyCount: 4,
            mineDotSpawnInterval: 8.4,
            maxActiveMineDots: 5,
            hunterDotSpawnInterval: 9.5,
            hunterDotSpeed: 180,
            hunterDotPredictionLead: 0.75,
            maxActiveHunterDots: 2,
            paddleTrapSpawnInterval: 13.5,
            maxActivePaddleTraps: 1,
            paddleTrapLifetime: 7,
            paddleTrapBarEnemyCount: 3,
            paddleTrapDotSpeed: 226,
            splitterSpawnInterval: 8.8,
            splitterSpeed: 110,
            maxActiveSplitters: 3
        )
    }

    private static func redlineChaosTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.25,
            chaserSpeed: 180,
            maxActiveEnemies: 192,
            formationSpawnInterval: 2.45,
            formationSpeed: 228,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 3.8,
            arrowRushSpeed: 318,
            arrowRushEnemyCount: 6,
            mineDotSpawnInterval: 5.0,
            maxActiveMineDots: 8,
            hunterDotSpawnInterval: 6.3,
            hunterDotSpeed: 234,
            hunterDotPredictionLead: 1.05,
            maxActiveHunterDots: 4,
            paddleTrapSpawnInterval: 8.8,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 4,
            paddleTrapDotSpeed: 292,
            splitterSpawnInterval: 6.4,
            splitterSpeed: 150,
            maxActiveSplitters: 4
        )
    }

    private static func redlineSurvivalHellTuning() -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0.18,
            chaserSpeed: 216,
            maxActiveEnemies: 270,
            formationSpawnInterval: 1.95,
            formationSpeed: 274,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 2.9,
            arrowRushSpeed: 372,
            arrowRushEnemyCount: 7,
            mineDotSpawnInterval: 4.0,
            maxActiveMineDots: 11,
            hunterDotSpawnInterval: 4.8,
            hunterDotSpeed: 282,
            hunterDotPredictionLead: 1.25,
            maxActiveHunterDots: 5,
            paddleTrapSpawnInterval: 6.8,
            maxActivePaddleTraps: 3,
            paddleTrapLifetime: 9,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 338,
            splitterSpawnInterval: 5.0,
            splitterSpeed: 186,
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
