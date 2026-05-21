import Foundation

struct ArenaLocalOptions: Codable, Equatable {
    var audioEnabled = true
    var hapticsEnabled = true
    var reducedEffects = false
    var themeKind: ArenaThemeKind = .darkTacticalRadar

    static let defaults = ArenaLocalOptions()

    init(
        audioEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        reducedEffects: Bool = false,
        themeKind: ArenaThemeKind = .darkTacticalRadar
    ) {
        self.audioEnabled = audioEnabled
        self.hapticsEnabled = hapticsEnabled
        self.reducedEffects = reducedEffects
        self.themeKind = themeKind
    }

    private enum CodingKeys: String, CodingKey {
        case audioEnabled
        case hapticsEnabled
        case reducedEffects
        case themeKind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        audioEnabled = try container.decodeIfPresent(Bool.self, forKey: .audioEnabled) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        reducedEffects = try container.decodeIfPresent(Bool.self, forKey: .reducedEffects) ?? false
        themeKind = (try? container.decode(ArenaThemeKind.self, forKey: .themeKind)) ?? .darkTacticalRadar
    }
}

final class ArenaLocalOptionsStore {
    private let defaults: UserDefaults
    private let optionsKey = "tiltArena.localOptions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var options: ArenaLocalOptions {
        get {
            guard
                let data = defaults.data(forKey: optionsKey),
                let options = try? JSONDecoder().decode(ArenaLocalOptions.self, from: data)
            else {
                return .defaults
            }

            return options
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            defaults.set(data, forKey: optionsKey)
        }
    }

    func reset() {
        defaults.removeObject(forKey: optionsKey)
    }
}
