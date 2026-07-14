import CoreGraphics
import XCTest
@testable import TiltArena

final class WeaponImpactPlanTests: XCTestCase {
    func testCapsAndSpreadsVisualTargetsWithoutDroppingImpacts() {
        let targets = (1...64).map {
            WeaponImpactTarget(id: $0, position: CGPoint(x: CGFloat($0), y: 0))
        }

        let plan = WeaponImpactPlan(targets: targets)

        XCTAssertEqual(plan.impactEnemyIDs, Set(1...64))
        XCTAssertEqual(plan.visualTargets.count, WeaponImpactPlan.maximumVisualTargetCount)
        XCTAssertEqual(plan.visualTargets.first?.id, 1)
        XCTAssertEqual(plan.visualTargets.last?.id, 64)
        XCTAssertEqual(Set(plan.visualTargets.map(\.id)).count, plan.visualTargets.count)
    }

    func testKeepsEveryVisualWhenAlreadyBelowCap() {
        let targets = (1...8).map {
            WeaponImpactTarget(id: $0, position: CGPoint(x: CGFloat($0), y: 0))
        }

        let plan = WeaponImpactPlan(targets: targets)

        XCTAssertEqual(plan.visualTargets, targets)
        XCTAssertEqual(plan.impactEnemyIDs, Set(1...8))
    }
}
