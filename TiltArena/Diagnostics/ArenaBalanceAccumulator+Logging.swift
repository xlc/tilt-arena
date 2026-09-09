import CoreGraphics
import Foundation
import Logging

extension ArenaBalanceAccumulator {
    struct Event {
        let name: String
        var metadata: Logger.Metadata
    }

    func events(
        summary: RunSummary, score: RunScoreBreakdown, experimental: Bool,
        arenaSize: CGSize, unlockedWeapons: Int
    ) -> [Event] {
        var events = [Event(name: "run.balance", metadata: [
            "mode": "\(summary.mode.rawValue)", "seed": "\(summary.sequenceSeed)",
            "rules_version": "\(summary.rulesVersion)", "experimental": "\(experimental)",
            "arena_width": "\(arenaSize.width)", "arena_height": "\(arenaSize.height)",
            "unlocked_weapons": "\(unlockedWeapons)", "score": "\(summary.score)",
            "kill_score": "\(score.kills)", "pickup_score": "\(score.pickups)", "survival_score": "\(score.survival)",
            "survival_s": "\(summary.survivalTime)", "max_combo": "\(summary.maxCombo)",
            "kills": "\(summary.enemiesDestroyed)", "death_role": "\(deathRole?.rawValue ?? "none")",
            "synergies": "\(synergies)", "cascades": "\(cascades)",
            "end_reason": "\(deathRole == nil ? "ended" : "collision")",
            "run_band": "\(Self.runBand(summary.survivalTime))",
            "last_pickup": "\(lastPickup?.kind.rawValue ?? "none")",
            "last_tier": "\(lastPickup?.tier.metadataValue ?? "none")",
            "since_pickup_s": "\(lastPickup.map { max(0, summary.survivalTime - $0.time) } ?? -1)"
        ]), Event(name: "run.balance_exposure", metadata: [
            "protected_s": "\(protectedSeconds)", "shield_s": "\(shieldSeconds)",
            "freeze_s": "\(freezeSeconds)", "gravity_s": "\(gravitySeconds)", "slow_s": "\(slowSeconds)"
        ])]
        var spawn: Logger.Metadata = [
            "peak_active": "\(peakActiveEnemies)", "peak_reserved": "\(peakReservedEnemies)",
            "capacity_gate_s": "\(capacityGateSeconds)", "warning_gate_s": "\(warningGateSeconds)",
            "role_gate_s": "\(roleGateSeconds)"
        ]
        for (role, count) in spawned { spawn["spawned_\(role.rawValue)"] = "\(count)" }
        events.append(Event(name: "run.balance_spawns", metadata: spawn))
        for kind in WeaponKind.allCases {
            guard let totals = weapons[kind] else { continue }
            events.append(Event(name: "run.balance_weapon", metadata: [
                "weapon": "\(kind.rawValue)",
                "base_pickups": "\(totals.pickups[0])", "charged_pickups": "\(totals.pickups[1])",
                "overcharged_pickups": "\(totals.pickups[2])", "pickup_age_sum_s": "\(totals.ageSeconds)",
                "base_kills": "\(totals.kills[0])", "charged_kills": "\(totals.kills[1])",
                "overcharged_kills": "\(totals.kills[2])", "max_activation_kills": "\(totals.maximumKills)",
                "activations_0_kills": "\(totals.killDistribution[0])",
                "activations_1_kill": "\(totals.killDistribution[1])",
                "activations_2_4_kills": "\(totals.killDistribution[2])",
                "activations_5_9_kills": "\(totals.killDistribution[3])",
                "activations_10_plus_kills": "\(totals.killDistribution[4])"
            ]))
        }
        return events.map { event in
            var event = event
            event.metadata["run_id"] = "\(runID)"
            return event
        }
    }

    private static func runBand(_ time: TimeInterval) -> String {
        switch time {
        case ..<30: return "0_30"
        case ..<60: return "30_60"
        case ..<120: return "60_120"
        case ..<180: return "120_180"
        default: return "180_plus"
        }
    }
}
