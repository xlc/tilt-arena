import Foundation

struct ArenaModeRunSettings: Equatable {
    let enemySpawnConfiguration: EnemySpawnConfiguration
    let pickupSpawnConfiguration: PickupSpawnConfiguration
    let sequenceSeed: Int?
}

struct ArenaModeRules {
    static let redlineBestScoreRequirement = 5_000
    static let dailyEnemyUnlockRequirement = 400

    static func isAvailable(_ mode: ArenaModeKind, profile: RunProfile) -> Bool {
        switch mode {
        case .classic:
            return true
        case .redline:
            return profile.bestScore >= redlineBestScoreRequirement
        case .daily:
            return profile.totalEnemiesDestroyed >= dailyEnemyUnlockRequirement
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
            return "\(min(profile.totalEnemiesDestroyed, dailyEnemyUnlockRequirement))/\(dailyEnemyUnlockRequirement) UNLOCK TRACK"
        }
    }

    static func activeUnlockText(profile: RunProfile) -> String {
        if !isAvailable(.redline, profile: profile) {
            return "REDLINE \(min(profile.bestScore, redlineBestScoreRequirement))/\(redlineBestScoreRequirement)"
        }

        if !isAvailable(.daily, profile: profile) {
            return "DAILY \(min(profile.totalEnemiesDestroyed, dailyEnemyUnlockRequirement))/\(dailyEnemyUnlockRequirement)"
        }

        return "ALL LOCAL MODES READY"
    }

    static func runSettings(
        for mode: ArenaModeKind,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> ArenaModeRunSettings {
        switch mode {
        case .classic:
            return ArenaModeRunSettings(
                enemySpawnConfiguration: EnemySpawnConfiguration(),
                pickupSpawnConfiguration: PickupSpawnConfiguration(),
                sequenceSeed: nil
            )
        case .redline:
            return ArenaModeRunSettings(
                enemySpawnConfiguration: redlineEnemySpawnConfiguration(),
                pickupSpawnConfiguration: redlinePickupSpawnConfiguration(),
                sequenceSeed: nil
            )
        case .daily:
            return ArenaModeRunSettings(
                enemySpawnConfiguration: EnemySpawnConfiguration(),
                pickupSpawnConfiguration: PickupSpawnConfiguration(),
                sequenceSeed: dailySeed(for: date, calendar: calendar)
            )
        }
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
        configuration.warmup = EnemyPhaseTuning(
            chaserSpawnInterval: 0.82,
            chaserSpeed: 78,
            maxActiveEnemies: 64,
            formationSpawnInterval: 9,
            formationSpeed: 112,
            formationLaneCount: 5
        )
        configuration.pressure = EnemyPhaseTuning(
            chaserSpawnInterval: 0.62,
            chaserSpeed: 94,
            maxActiveEnemies: 96,
            formationSpawnInterval: 6.5,
            formationSpeed: 124,
            formationLaneCount: 7,
            arrowRushSpawnInterval: 11,
            arrowRushSpeed: 160,
            arrowRushEnemyCount: 3,
            mineDotSpawnInterval: 16,
            maxActiveMineDots: 4,
            hunterDotSpawnInterval: 18,
            hunterDotSpeed: 112,
            hunterDotPredictionLead: 0.65,
            maxActiveHunterDots: 2,
            paddleTrapSpawnInterval: 24,
            maxActivePaddleTraps: 1,
            paddleTrapLifetime: 7,
            paddleTrapBarEnemyCount: 4,
            paddleTrapDotSpeed: 150
        )
        configuration.chaos = EnemyPhaseTuning(
            chaserSpawnInterval: 0.45,
            chaserSpeed: 112,
            maxActiveEnemies: 140,
            formationSpawnInterval: 4.8,
            formationSpeed: 144,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 7.5,
            arrowRushSpeed: 190,
            arrowRushEnemyCount: 5,
            mineDotSpawnInterval: 10,
            maxActiveMineDots: 7,
            hunterDotSpawnInterval: 12,
            hunterDotSpeed: 140,
            hunterDotPredictionLead: 0.9,
            maxActiveHunterDots: 3,
            paddleTrapSpawnInterval: 17,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 178
        )
        configuration.survivalHell = EnemyPhaseTuning(
            chaserSpawnInterval: 0.34,
            chaserSpeed: 132,
            maxActiveEnemies: 210,
            formationSpawnInterval: 3.8,
            formationSpeed: 164,
            formationLaneCount: 9,
            arrowRushSpawnInterval: 5.5,
            arrowRushSpeed: 215,
            arrowRushEnemyCount: 6,
            mineDotSpawnInterval: 8,
            maxActiveMineDots: 9,
            hunterDotSpawnInterval: 10,
            hunterDotSpeed: 158,
            hunterDotPredictionLead: 1.1,
            maxActiveHunterDots: 4,
            paddleTrapSpawnInterval: 14,
            maxActivePaddleTraps: 2,
            paddleTrapLifetime: 8,
            paddleTrapBarEnemyCount: 5,
            paddleTrapDotSpeed: 195
        )
        return configuration
    }

    private static func redlinePickupSpawnConfiguration() -> PickupSpawnConfiguration {
        PickupSpawnConfiguration(
            initialSpawnDelay: 5.0,
            spawnInterval: 5.2,
            maxActivePickups: 2,
            weaponKindCycle: [
                .flameTrail,
                .warpDash,
                .freezeBurst,
                .gravityWell,
                .chainLightning,
                .seekerSwarm,
                .flameTrail,
                .warpDash,
                .decoyBeacon,
                .freezeBurst,
                .gravityWell,
                .razorShield,
                .chainLightning,
                .flameTrail,
                .warpDash,
                .decoyBeacon,
                .shockwave
            ]
        )
    }
}
