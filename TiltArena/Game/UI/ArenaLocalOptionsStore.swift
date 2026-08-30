import Foundation
import Logging

struct ArenaLocalOptions: Codable, Equatable {
    var audioEnabled = true
    var hapticsEnabled = true
    var themeKind: ArenaThemeKind = .darkTacticalRadar

    static let defaults = ArenaLocalOptions()

    init(
        audioEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        themeKind: ArenaThemeKind = .darkTacticalRadar
    ) {
        self.audioEnabled = audioEnabled
        self.hapticsEnabled = hapticsEnabled
        self.themeKind = themeKind
    }

    private enum CodingKeys: String, CodingKey {
        case audioEnabled
        case hapticsEnabled
        case themeKind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        audioEnabled = try container.decodeIfPresent(Bool.self, forKey: .audioEnabled) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        themeKind = (try? container.decode(ArenaThemeKind.self, forKey: .themeKind)) ?? .darkTacticalRadar
    }
}

final class ArenaLocalOptionsStore {
    private let defaults: UserDefaults
    private let optionsKey = "tiltArena.localOptions"
    private let logger: Logger

    init(
        defaults: UserDefaults = .standard,
        logger: Logger = AppDiagnostics.logger(.app)
    ) {
        self.defaults = defaults
        self.logger = logger
    }

    var options: ArenaLocalOptions {
        get {
            guard let data = defaults.data(forKey: optionsKey) else {
                return .defaults
            }

            do {
                return try JSONDecoder().decode(ArenaLocalOptions.self, from: data)
            } catch {
                logger.warning("options.load_failed", error: error, metadata: [
                    "bytes": "\(data.count)"
                ])
                return .defaults
            }
        }
        set {
            do {
                defaults.set(try JSONEncoder().encode(newValue), forKey: optionsKey)
            } catch {
                logger.error("options.save_failed", error: error)
            }
        }
    }

    func reset() {
        defaults.removeObject(forKey: optionsKey)
    }
}
