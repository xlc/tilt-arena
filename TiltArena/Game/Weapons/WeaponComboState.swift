import Foundation

enum WeaponComboFamily: String, Equatable {
    case force
    case seek
    case control
    case defense

    var hudLabel: String {
        switch self {
        case .force:
            return "FORCE"
        case .seek:
            return "SEEK"
        case .control:
            return "CONTROL"
        case .defense:
            return "GUARD"
        }
    }
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

    var hudLabel: String {
        switch self {
        case .synergy:
            return "WEAPON"
        case .cascade:
            return "CASCADE"
        }
    }
}

struct WeaponComboEvent: Equatable {
    let kind: WeaponComboEventKind
    let previousFamily: WeaponComboFamily
    let currentFamily: WeaponComboFamily
    let scoreBonus: Int
    let comboWindowExtension: TimeInterval
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
        guard primerTimeRemaining > 0 else {
            reset()
            return
        }

        primerTimeRemaining = max(0, primerTimeRemaining - max(0, deltaTime))
        if primerTimeRemaining == 0 {
            reset()
        }
    }

    mutating func recordWeaponClear(
        kind: WeaponKind,
        killCount: Int,
        configuration: ClassicRunConfiguration
    ) -> WeaponComboEvent? {
        let currentFamily = kind.comboFamily
        let previousFamily = activePrimer?.family
        let previousChainFamilies = chainFamilies
        let minimumKillCount = max(2, configuration.weaponComboMinimumKillCount)
        prime(currentFamily, window: configuration.weaponComboWindow)

        guard
            killCount >= minimumKillCount,
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
        let scoreBonus = isCascade
            ? max(0, configuration.weaponComboCascadeScoreBonus)
            : max(0, configuration.weaponComboScoreBonus)
        let comboWindowExtension = isCascade
            ? max(0, configuration.weaponComboCascadeWindowExtension)
            : max(0, configuration.weaponComboWindowExtension)
        let event = WeaponComboEvent(
            kind: isCascade ? .cascade : .synergy,
            previousFamily: previousFamily,
            currentFamily: currentFamily,
            scoreBonus: scoreBonus,
            comboWindowExtension: comboWindowExtension
        )

        chainFamilies = isCascade ? [currentFamily] : nextChainFamilies
        return event
    }

    private mutating func prime(_ family: WeaponComboFamily, window: TimeInterval) {
        primedFamily = family
        primerTimeRemaining = max(0, window)
    }
}
