import Foundation
import Logging

final class GameTuningStore {
    private let defaults: UserDefaults
    private let overridesKey = "tiltArena.gameTuningOverrides.v1"
    private let logger: Logger

    init(
        defaults: UserDefaults = .standard,
        logger: Logger = AppDiagnostics.logger(.app)
    ) {
        self.defaults = defaults
        self.logger = logger
    }

    var tuning: GameTuningConfiguration {
        get {
            var tuning = GameTuningConfiguration.defaults
            for (id, storedValue) in overrides {
                guard let parameter = GameTuningParameterCatalog.parameter(id: id) else {
                    logger.warning("tuning.unknown_parameter_ignored", metadata: [
                        "parameter": "\(id)"
                    ])
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
            guard let data = defaults.data(forKey: overridesKey) else {
                return [:]
            }

            do {
                return try JSONDecoder().decode([String: GameTuningStoredValue].self, from: data)
            } catch {
                logger.warning("tuning.load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
                defaults.removeObject(forKey: overridesKey)
                return [:]
            }
        }
        set {
            guard !newValue.isEmpty else {
                reset()
                return
            }

            do {
                defaults.set(try JSONEncoder().encode(newValue), forKey: overridesKey)
            } catch {
                logger.error("tuning.save_failed", error: error, metadata: [
                    "parameters": "\(newValue.count)"
                ])
            }
        }
    }
}
