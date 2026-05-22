import CoreGraphics
import UIKit

enum ArenaHapticImpactStyle: Equatable {
    case light
    case medium
    case heavy
}

enum ArenaHapticNotificationStyle: Equatable {
    case success
    case warning
    case error
}

struct ArenaHapticPattern: Equatable {
    enum Kind: Equatable {
        case impact(ArenaHapticImpactStyle)
        case notification(ArenaHapticNotificationStyle)
    }

    let kind: Kind
    let intensity: CGFloat?

    static func impact(_ style: ArenaHapticImpactStyle, intensity: CGFloat) -> ArenaHapticPattern {
        ArenaHapticPattern(kind: .impact(style), intensity: intensity)
    }

    static func notification(_ style: ArenaHapticNotificationStyle) -> ArenaHapticPattern {
        ArenaHapticPattern(kind: .notification(style), intensity: nil)
    }
}

enum ArenaHapticEvent: Equatable {
    case pickup
    case dangerPickup
    case nearMiss
    case enemyClear(count: Int)
    case comboMilestone(multiplier: Int)
    case shieldWarning
    case shieldExpired
    case death
    case newBest

    var pattern: ArenaHapticPattern {
        switch self {
        case .pickup:
            return .impact(.light, intensity: 0.45)
        case .dangerPickup:
            return .impact(.heavy, intensity: 0.82)
        case .nearMiss:
            return .impact(.light, intensity: 0.35)
        case let .enemyClear(count) where count >= 8:
            return .impact(.heavy, intensity: 0.9)
        case let .enemyClear(count) where count >= 3:
            return .impact(.medium, intensity: 0.68)
        case .enemyClear:
            return .impact(.light, intensity: 0.42)
        case let .comboMilestone(multiplier) where multiplier >= 4:
            return .impact(.heavy, intensity: 1.0)
        case .comboMilestone:
            return .impact(.medium, intensity: 0.78)
        case .shieldWarning:
            return .impact(.light, intensity: 0.52)
        case .shieldExpired:
            return .notification(.warning)
        case .death:
            return .notification(.error)
        case .newBest:
            return .notification(.success)
        }
    }
}

@MainActor
final class ArenaHapticsController {
    var isEnabled = true {
        didSet {
            if isEnabled {
                prepare()
            }
        }
    }

    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func prepare() {
        guard isEnabled else {
            return
        }

        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    func play(_ event: ArenaHapticEvent) {
        guard isEnabled else {
            return
        }

        play(event.pattern)
    }

    private func play(_ pattern: ArenaHapticPattern) {
        switch pattern.kind {
        case let .impact(style):
            impactGenerator(for: style).impactOccurred(intensity: pattern.clampedIntensity)
        case let .notification(style):
            notificationGenerator.notificationOccurred(style.feedbackType)
        }
    }

    private func impactGenerator(for style: ArenaHapticImpactStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return lightImpactGenerator
        case .medium:
            return mediumImpactGenerator
        case .heavy:
            return heavyImpactGenerator
        }
    }
}

private extension ArenaHapticPattern {
    var clampedIntensity: CGFloat {
        min(1, max(0, intensity ?? 1))
    }
}

private extension ArenaHapticNotificationStyle {
    var feedbackType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}
