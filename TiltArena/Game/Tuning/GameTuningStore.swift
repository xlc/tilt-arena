import Foundation

final class GameTuningStore {
    private let defaults: UserDefaults
    private let overridesKey = "tiltArena.gameTuningOverrides.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var tuning: GameTuningConfiguration {
        get {
            var tuning = GameTuningConfiguration.defaults
            for (id, storedValue) in overrides {
                guard let parameter = GameTuningParameterCatalog.parameter(id: id) else {
                    continue
                }

                parameter.applyStoredValue(storedValue, to: &tuning)
            }

            return tuning
        }
        set {
            var nextOverrides: [String: GameTuningStoredValue] = [:]
            let baseline = GameTuningConfiguration.defaults
            for parameter in GameTuningParameterCatalog.parameters where !parameter.matchesDefault(in: newValue, baseline: baseline) {
                nextOverrides[parameter.id] = parameter.storedValue(in: newValue)
            }

            overrides = nextOverrides
        }
    }

    func reset() {
        defaults.removeObject(forKey: overridesKey)
    }

    private var overrides: [String: GameTuningStoredValue] {
        get {
            guard
                let data = defaults.data(forKey: overridesKey),
                let overrides = try? JSONDecoder().decode([String: GameTuningStoredValue].self, from: data)
            else {
                return [:]
            }

            return overrides
        }
        set {
            guard !newValue.isEmpty else {
                reset()
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }

            defaults.set(data, forKey: overridesKey)
        }
    }
}
