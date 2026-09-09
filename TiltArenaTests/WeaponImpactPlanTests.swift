import CoreGraphics
import XCTest
@testable import TiltArena

@MainActor
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

    func testGravityCollapseCapsVisualNodesForLargeClear() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        let targets = (1...64).map {
            WeaponImpactTarget(id: $0, position: CGPoint(x: CGFloat($0), y: 80))
        }

        scene.playGravityWellCollapseEffect(
            at: CGPoint(x: 160, y: 120),
            clearRadius: 32,
            targets: targets
        ) { _ in }

        XCTAssertLessThanOrEqual(
            scene.weaponEffectNodeCountForTesting,
            WeaponImpactPlan.maximumVisualTargetCount + 2
        )
    }

    func testFrozenShatterCapsVisualNodesForLargeStackedClear() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        let positions = (1...64).map { CGPoint(x: CGFloat($0), y: 80) }

        scene.playFrozenShatterEffect(at: positions, color: .white)

        XCTAssertEqual(
            scene.weaponEffectNodeCountForTesting,
            WeaponImpactPlan.maximumVisualTargetCount * 2
        )
    }

    func testEnemyClearCapsAndCombinesVisualNodesForLargeClear() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))
        let positions = (1...64).map { CGPoint(x: CGFloat($0), y: 80) }

        scene.playEnemyClearBursts(
            at: positions,
            weaponKind: .shockwave,
            comboMultiplier: 1
        )

        XCTAssertEqual(
            scene.weaponEffectNodeCountForTesting,
            WeaponImpactPlan.maximumVisualTargetCount * 4
        )
    }

    func testImpactResidueCombinesShardVisuals() {
        let scene = ArenaScene(size: CGSize(width: 320, height: 240))

        scene.playImpactResidue(
            at: CGPoint(x: 160, y: 120),
            color: .white,
            coreColor: .white,
            radius: 12,
            delay: 0
        )

        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 2)
    }

    func testChargedActivationKeepsItsDrawingBudgetBounded() {
        for tier in [WeaponPickupChargeTier.charged, .overcharged] {
            let scene = ArenaScene(size: CGSize(width: 320, height: 240))
            scene.playChargedWeaponActivationEffect(kind: .novaBomb, at: CGPoint(x: 160, y: 120), chargeTier: tier)

            XCTAssertLessThanOrEqual(scene.weaponEffectNodeCountForTesting, 5)
        }
    }
}
