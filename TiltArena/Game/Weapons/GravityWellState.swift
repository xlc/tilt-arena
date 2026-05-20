import CoreGraphics
import Foundation

struct GravityWellState {
    let center: CGPoint
    let enemyIDs: Set<Int>
    var timeRemaining: TimeInterval
}
