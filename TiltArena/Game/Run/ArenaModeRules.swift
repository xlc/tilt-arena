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
        configuration.enemySpeedRampPerSecond = 0.03
        configuration.maximumEnemySpeedMultiplier = 2.05
        configuration.warmup = EnemyPhaseTuning(
            chaserSpawnInterval: 0.62,
            chaserSpeed: 96,
            maxActiveEnemies: 76,
            formationSpawnInterval: 6.8,
            formationSpeed: 130,
            formationLaneCount: 5
        )
        configuration.pressure = EnemyPhaseTuning(
            chaserSpawnInterval: 0.43,
            chaserSpeed: 118,
            maxActiveEnemies: 118,
            formationSpawnInterval: 4.2,
            formationSpeed: 150,
            formationLaneCount: 7,
            arrowRushSpawnInterval: 7.2,
            arrowRushSpeed: 198,
            arrowRushEnemyCount: 3,
            mineDotSpawnInterval: 10.5,
            maxActiveMineDots: 4,
            hunterDotSpawnInterval: 12,
            hunterDotSpeed: 146,
            hunterDotPredictionLead: 0.65,
            maxActiveHunterDots: 2,
            paddleTrapSpawnInterval: 16,
            maxActivePaddleTraps: 1,
            paddleTrapLifetime: 7,
            paddleTrapBarEnemyCount: 4,
            paddleTrapDotSpeed: 184
        )
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0.31,
            chaserSpeed: 146,
            maxActiveEnemies: 166,
            formationSpawnInterval: 3.1,
            formationSpeed: 178,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 4.8,
            arrowRushSpeed: 238,
            arrowRushEnemyCount: 5,
            mineDotSpawnInterval: 6.2,
            maxActiveMineDots: 7,
            hunterDotSpawnInterval: 7.8,
            hunterDotSpeed: 184,
            hunterDotPredictionLead: 0.9,
            maxActiveHunterDots: 3,
            paddleTrapSpawnInterval: 10.8,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 228
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0.23,
            chaserSpeed: 174,
            maxActiveEnemies: 240,
            formationSpawnInterval: 2.5,
            formationSpeed: 210,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 3.7,
            arrowRushSpeed: 274,
            arrowRushEnemyCount: 6,
            mineDotSpawnInterval: 5.1,
            maxActiveMineDots: 9,
            hunterDotSpawnInterval: 6.2,
            hunterDotSpeed: 214,
            hunterDotPredictionLead: 1.1,
            maxActiveHunterDots: 4,
            paddleTrapSpawnInterval: 8.6,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 258
        )
        return configuration
    }

    private static func redlinePickupSpawnConfiguration() -> PickupSpawnConfiguration {
        PickupSpawnConfiguration(
            maxActivePickups: 3,
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
