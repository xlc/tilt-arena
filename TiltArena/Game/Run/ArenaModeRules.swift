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
        configuration.enemySpeedRampPerSecond = 0.02
        configuration.maximumEnemySpeedMultiplier = 1.8
        configuration.warmup = EnemyPhaseTuning(
            chaserSpawnInterval: 0.72,
            chaserSpeed: 86,
            maxActiveEnemies: 64,
            formationSpawnInterval: 8,
            formationSpeed: 118,
            formationLaneCount: 5
        )
        configuration.pressure = EnemyPhaseTuning(
            chaserSpawnInterval: 0.52,
            chaserSpeed: 104,
            maxActiveEnemies: 96,
            formationSpawnInterval: 5.2,
            formationSpeed: 134,
            formationLaneCount: 7,
            arrowRushSpawnInterval: 9,
            arrowRushSpeed: 178,
            arrowRushEnemyCount: 3,
            mineDotSpawnInterval: 13,
            maxActiveMineDots: 4,
            hunterDotSpawnInterval: 15,
            hunterDotSpeed: 126,
            hunterDotPredictionLead: 0.65,
            maxActiveHunterDots: 2,
            paddleTrapSpawnInterval: 20,
            maxActivePaddleTraps: 1,
            paddleTrapLifetime: 7,
            paddleTrapBarEnemyCount: 4,
            paddleTrapDotSpeed: 165
        )
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0.38,
            chaserSpeed: 126,
            maxActiveEnemies: 140,
            formationSpawnInterval: 3.8,
            formationSpeed: 158,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 6,
            arrowRushSpeed: 210,
            arrowRushEnemyCount: 5,
            mineDotSpawnInterval: 8,
            maxActiveMineDots: 7,
            hunterDotSpawnInterval: 10,
            hunterDotSpeed: 158,
            hunterDotPredictionLead: 0.9,
            maxActiveHunterDots: 3,
            paddleTrapSpawnInterval: 14,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 198
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0.28,
            chaserSpeed: 150,
            maxActiveEnemies: 210,
            formationSpawnInterval: 3,
            formationSpeed: 186,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 4.5,
            arrowRushSpeed: 240,
            arrowRushEnemyCount: 6,
            mineDotSpawnInterval: 6.5,
            maxActiveMineDots: 9,
            hunterDotSpawnInterval: 8,
            hunterDotSpeed: 184,
            hunterDotPredictionLead: 1.1,
            maxActiveHunterDots: 4,
            paddleTrapSpawnInterval: 11,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 220
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
