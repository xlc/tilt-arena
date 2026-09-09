import CoreGraphics
import Foundation

/// The collision front and its visible boundary use the same response curve.
enum WeaponWaveExpansion {
    static func progress(elapsed: TimeInterval, duration: TimeInterval, exponent: Double) -> CGFloat {
        guard duration > 0 else { return 1 }
        let progress = min(1, max(0, elapsed / duration))
        let exponent = exponent.isFinite ? min(4, max(1, exponent)) : 1
        return CGFloat(1 - pow(1 - progress, exponent))
    }
}
