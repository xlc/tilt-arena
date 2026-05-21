import Foundation

struct ArenaLocalOptions: Codable, Equatable {
    var audioEnabled = true
    var hapticsEnabled = true
    var reducedEffects = false

    static let defaults = ArenaLocalOptions()
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
