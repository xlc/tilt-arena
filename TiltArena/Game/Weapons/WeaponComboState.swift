import Foundation

enum WeaponComboFamily: String, Equatable {
    case force
    case seek
    case control
    case defense
}

extension WeaponKind {
    var comboFamily: WeaponComboFamily {
        switch self {
        case .shockwave, .powerWave, .novaBomb:
            return .force
        case .seekerSwarm, .chainLightning, .ricochetLance:
            return .seek
        case .freezeBurst, .gravityWell, .warpDash:
            return .control
        case .razorShield, .flameTrail:
            return .defense
        }
    }
}

struct WeaponComboPrimer: Equatable {
    let family: WeaponComboFamily
    let timeRemaining: TimeInterval
}

enum WeaponComboEventKind: String, Equatable {
    case synergy
    case cascade
}

struct WeaponComboEvent: Equatable {
    let kind: WeaponComboEventKind
    let previousFamily: WeaponComboFamily
    let currentFamily: WeaponComboFamily
}

/// Shared only by the effects created by one pickup. References expire with
/// projectiles, trail segments, and frozen enemies; there is no run-long ledger.
final class WeaponActivation: Hashable {
    let kind: WeaponKind
    private(set) var killCount = 0
    private(set) var hasQualifiedClear = false

    init(kind: WeaponKind) {
        self.kind = kind
    }

    func recordKills(_ count: Int, minimum: Int) -> Bool {
        let (total, overflow) = killCount.addingReportingOverflow(max(0, count))
        killCount = overflow ? Int.max : total
        guard !hasQualifiedClear, killCount >= max(2, minimum) else { return false }
        hasQualifiedClear = true
        return true
    }

    static func == (lhs: WeaponActivation, rhs: WeaponActivation) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct WeaponComboState: Equatable {
    private static let cascadeFamilyCount = 3

    private var primedFamily: WeaponComboFamily?
    private var primerTimeRemaining: TimeInterval = 0
    private var chainFamilies: [WeaponComboFamily] = []

    var activePrimer: WeaponComboPrimer? {
        guard let primedFamily, primerTimeRemaining > 0 else {
            return nil
        }

        return WeaponComboPrimer(family: primedFamily, timeRemaining: primerTimeRemaining)
    }

    mutating func reset() {
        primedFamily = nil
        primerTimeRemaining = 0
        chainFamilies.removeAll()
    }

    mutating func update(deltaTime: TimeInterval) {
        if !primerTimeRemaining.isFinite {
            reset()
            return
        }
        guard primerTimeRemaining > 0 else {
            reset()
            return
        }

        let deltaTime = deltaTime.isFinite ? max(0, deltaTime) : 0
        primerTimeRemaining = max(0, primerTimeRemaining - deltaTime)
        if primerTimeRemaining == 0 {
            reset()
        }
    }

    mutating func recordWeaponClear(
        kind: WeaponKind,
        killCount: Int,
        configuration: ClassicRunConfiguration
    ) -> WeaponComboEvent? {
        guard killCount >= max(2, configuration.weaponComboMinimumKillCount) else { return nil }
        let currentFamily = kind.comboFamily
        let previousFamily = activePrimer?.family
        let previousChainFamilies = chainFamilies
        prime(currentFamily, window: configuration.weaponComboWindow)

        guard
            let previousFamily,
            previousFamily != currentFamily
        else {
            chainFamilies = [currentFamily]
            return nil
        }

        var nextChainFamilies = previousChainFamilies.isEmpty ? [previousFamily] : previousChainFamilies
        if !nextChainFamilies.contains(previousFamily) {
            nextChainFamilies.append(previousFamily)
        }
        if !nextChainFamilies.contains(currentFamily) {
            nextChainFamilies.append(currentFamily)
        }

        let isCascade = nextChainFamilies.count >= Self.cascadeFamilyCount
        let event = WeaponComboEvent(
            kind: isCascade ? .cascade : .synergy,
            previousFamily: previousFamily,
            currentFamily: currentFamily
        )

        chainFamilies = isCascade ? [currentFamily] : nextChainFamilies
        return event
    }

    private mutating func prime(_ family: WeaponComboFamily, window: TimeInterval) {
        primedFamily = family
        primerTimeRemaining = WeaponRuntimeSafetyLimits.duration(window)
    }
}
