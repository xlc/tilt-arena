import XCTest
@testable import TiltArena

final class ArenaWeaponRuntimeTests: XCTestCase {
    func testActivationPlanAppliesPickupChargeTierToConfiguration() {
        let runtime = ArenaWeaponRuntime()
        let configuration = StartingWeaponConfiguration()
        runtime.configure(weaponConfiguration: configuration, effectTiming: WeaponEffectTiming())
        let pickup = WeaponPickup(
            id: 1,
            kind: .shockwave,
            position: .zero,
            radius: 8,
            chargeTier: .charged
        )

        let plan = runtime.activationPlan(for: pickup, playerPosition: .zero, enemies: [])

        XCTAssertEqual(plan.configuration, configuration.applying(chargeTier: .charged))
    }

    func testPreparingSameRunSeedProducesSameNovaTargetPlan() {
        let first = ArenaWeaponRuntime()
        let second = ArenaWeaponRuntime()
        let pickup = WeaponPickup(id: 1, kind: .novaBomb, position: .zero, radius: 8)
        let enemies = (0..<12).map { index in
            ArenaEnemy(
                id: index,
                position: CGPoint(x: CGFloat(index * 10), y: 0),
                radius: 4,
                speed: 0
            )
        }
        first.prepareRun(sequenceSeed: 42)
        second.prepareRun(sequenceSeed: 42)

        let firstPlan = first.activationPlan(for: pickup, playerPosition: .zero, enemies: enemies)
        let secondPlan = second.activationPlan(for: pickup, playerPosition: .zero, enemies: enemies)

        XCTAssertEqual(firstPlan, secondPlan)
    }
}
