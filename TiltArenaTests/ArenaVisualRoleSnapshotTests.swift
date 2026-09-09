import SnapshotTesting
import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class ArenaVisualRoleSnapshotTests: XCTestCase {
    private struct EnemyContactFixture {
        let label: String
        let enemy: ArenaEnemy
    }

    private static let weaponLabels: [WeaponKind: String] = [
        .shockwave: "SHOCK",
        .seekerSwarm: "SEEKER",
        .razorShield: "SHIELD",
        .freezeBurst: "FREEZE",
        .gravityWell: "GRAV",
        .chainLightning: "CHAIN",
        .flameTrail: "FLAME",
        .warpDash: "TIME",
        .powerWave: "WAVE",
        .ricochetLance: "LANCE",
        .novaBomb: "NOVA"
    ]

    private let sceneSize = CGSize(width: 720, height: 420)
    private let arenaRect = CGRect(x: 24, y: 32, width: 672, height: 364)

    func testDarkVisualRolesContactSheet() throws {
        assertSnapshot(
            of: try makeVisualRolesImage(theme: .darkTacticalRadar),
            as: .image(precision: 0.99)
        )
    }

    func testWhiteVisualRolesContactSheet() throws {
        assertSnapshot(
            of: try makeVisualRolesImage(theme: .whitePrecisionBoard),
            as: .image(precision: 0.99)
        )
    }

    func testActorDetailsStayVisibleWhenChildInsertionOrderChanges() throws {
        for theme in [ArenaTheme.darkTacticalRadar, .whitePrecisionBoard] {
            let expected = try makeVisualRolesImage(theme: theme, ignoresSiblingOrder: false)
            let reordered = try makeVisualRolesImage(
                theme: theme, ignoresSiblingOrder: false, reverseActorChildren: true
            )
            let difference = Snapshotting<UIImage, UIImage>.image(precision: 0.999).diffing.diff(expected, reordered)
            XCTAssertNil(difference, "Actor details must stay above their fills in \(theme.kind).")
        }
    }

    func testDarkPickupChargeStates() throws {
        assertSnapshot(of: try makeChargeStatesImage(theme: .darkTacticalRadar), as: .image(precision: 0.99))
    }

    func testWhitePickupChargeStates() throws {
        assertSnapshot(of: try makeChargeStatesImage(theme: .whitePrecisionBoard), as: .image(precision: 0.99))
    }

    private func makeChargeStatesImage(theme: ArenaTheme) throws -> UIImage {
        try SnapshotImageRenderer.render(size: CGSize(width: 720, height: 240), backgroundColor: theme.backgroundColor) { scene in
            let tiers: [WeaponPickupChargeTier] = [.base, .charged, .overcharged]
            for (row, tier) in tiers.enumerated() {
                let y = CGFloat(190 - row * 65)
                addContactLabel(["BASE", "CHARGED", "OVERCHARGED"][row], at: CGPoint(x: 66, y: y), to: scene, theme: theme)
                for (column, kind) in WeaponKind.allCases.enumerated() {
                    let pickup = WeaponPickup(
                        id: row * 11 + column,
                        kind: kind,
                        position: CGPoint(x: 145 + CGFloat(column) * 52, y: y),
                        radius: 12,
                        chargeTier: tier
                    )
                    scene.addChild(WeaponPickupNode(pickup: pickup, theme: theme))
                }
            }
        }
    }

    func testDirectionalEnemyHeadingTracksCurrentTravelVelocity() {
        assertHeading(
            for: .formationLine(velocity: CGVector(dx: 0, dy: 40), formationID: 1),
            equals: .pi / 2,
            label: "formation"
        )
        assertHeading(
            for: .arrowRush(velocity: CGVector(dx: -40, dy: 0)),
            equals: .pi,
            label: "arrow rush"
        )
        assertHeading(
            for: .paddleTrapDot(
                trapID: 1,
                velocity: CGVector(dx: 40, dy: -40),
                bounds: arenaRect,
                remainingLifetime: 2
            ),
            equals: -.pi / 4,
            label: "paddle puck"
        )
        var reflectedPuck = ArenaEnemy(
            id: 99,
            position: .zero,
            radius: 4,
            speed: 0,
            behavior: .paddleTrapDot(
                trapID: 1,
                velocity: CGVector(dx: 40, dy: 0),
                bounds: arenaRect,
                remainingLifetime: 2
            )
        )
        let reflectedPuckNode = EnemyNode(enemy: reflectedPuck, theme: .darkTacticalRadar)
        reflectedPuck.behavior = .paddleTrapDot(
            trapID: 1,
            velocity: CGVector(dx: 0, dy: 40),
            bounds: arenaRect,
            remainingLifetime: 2
        )

        reflectedPuckNode.apply(reflectedPuck)

        XCTAssertEqual(reflectedPuckNode.zRotation, .pi / 2, accuracy: 0.0001)
    }

    func testPaddleBarHeadingPreservesTrapOrientation() {
        assertHeading(
            for: .paddleTrapBar(trapID: 1, orientation: .horizontal, remainingLifetime: 2),
            equals: 0,
            label: "horizontal paddle bar"
        )
        assertHeading(
            for: .paddleTrapBar(trapID: 1, orientation: .vertical, remainingLifetime: 2),
            equals: .pi / 2,
            label: "vertical paddle bar"
        )
    }

    private func assertHeading(for behavior: EnemyBehavior, equals rotation: CGFloat, label: String) {
        let enemy = ArenaEnemy(id: 0, position: .zero, radius: 4, speed: 0, behavior: behavior)
        let node = EnemyNode(enemy: enemy, theme: .darkTacticalRadar)

        XCTAssertEqual(node.zRotation, rotation, accuracy: 0.0001, label)
    }

    private func makeVisualRolesImage(
        theme: ArenaTheme,
        ignoresSiblingOrder: Bool = true,
        reverseActorChildren: Bool = false
    ) throws -> UIImage {
        try SnapshotImageRenderer.render(
            size: sceneSize, backgroundColor: theme.backgroundColor, ignoresSiblingOrder: ignoresSiblingOrder
        ) { scene in
            scene.addChild(
                ArenaThemeRenderer(theme: theme).makeArenaBackground(
                    size: sceneSize,
                    arenaRect: arenaRect
                )
            )

            addActorRow(to: scene, theme: theme)
            addEffectAndPickupRow(to: scene, theme: theme)
            if reverseActorChildren {
                // Exercise another legal order for siblings that share the same depth.
                for actor in scene.children where actor is PlayerCraftNode || actor is EnemyNode || actor is WeaponPickupNode {
                    let children = actor.children.reversed()
                    actor.removeAllChildren()
                    children.forEach(actor.addChild)
                }
            }
        }
    }

    private func addActorRow(to scene: SKScene, theme: ArenaTheme) {
        let player = PlayerCraftNode(theme: theme, visualRadius: 12)
        player.position = CGPoint(x: 64, y: 350)
        player.zRotation = .pi / 8
        scene.addChild(player)
        addContactLabel("PLAYER", at: CGPoint(x: 64, y: 324), to: scene, theme: theme)

        let enemyRadius: CGFloat = 4
        addEnemyFixtures(
            topEnemyFixtures(radius: enemyRadius),
            labelY: 324,
            to: scene,
            theme: theme
        )
        addEnemyFixtures(
            bottomEnemyFixtures(radius: enemyRadius),
            labelY: 244,
            to: scene,
            theme: theme
        )
    }

    private func topEnemyFixtures(radius: CGFloat) -> [EnemyContactFixture] {
        [
            EnemyContactFixture(
                label: "CHASER",
                enemy: ArenaEnemy(id: 1, position: CGPoint(x: 180, y: 350), radius: radius, speed: 0)
            ),
            EnemyContactFixture(
                label: "FORMATION",
                enemy: ArenaEnemy(
                    id: 2,
                    position: CGPoint(x: 300, y: 350),
                    radius: radius,
                    speed: 0,
                    behavior: .formationLine(velocity: CGVector(dx: 50, dy: 28), formationID: 1)
                )
            ),
            EnemyContactFixture(
                label: "ARROW",
                enemy: ArenaEnemy(
                    id: 3,
                    position: CGPoint(x: 420, y: 350),
                    radius: radius,
                    speed: 0,
                    behavior: .arrowRush(velocity: CGVector(dx: 64, dy: -30))
                )
            ),
            EnemyContactFixture(
                label: "HUNTER",
                enemy: ArenaEnemy(
                    id: 4,
                    position: CGPoint(x: 540, y: 350),
                    radius: radius,
                    speed: 0,
                    behavior: .hunterDot(predictionLead: 1.2, previousTarget: nil)
                )
            ),
            EnemyContactFixture(
                label: "MINE",
                enemy: ArenaEnemy(
                    id: 5,
                    position: CGPoint(x: 656, y: 350),
                    radius: radius,
                    speed: 0,
                    behavior: .mineDot
                )
            )
        ]
    }

    private func bottomEnemyFixtures(radius: CGFloat) -> [EnemyContactFixture] {
        [
            EnemyContactFixture(
                label: "PADDLE BAR",
                enemy: ArenaEnemy(
                    id: 6, position: CGPoint(x: 120, y: 274),
                    radius: radius,
                    speed: 0,
                    behavior: .paddleTrapBar(trapID: 1, orientation: .vertical, remainingLifetime: 2)
                )
            ),
            EnemyContactFixture(
                label: "PADDLE PUCK",
                enemy: ArenaEnemy(
                    id: 7,
                    position: CGPoint(x: 240, y: 274),
                    radius: radius,
                    speed: 0,
                    behavior: .paddleTrapDot(
                        trapID: 1,
                        velocity: CGVector(dx: 48, dy: 34),
                        bounds: arenaRect,
                        remainingLifetime: 2
                    )
                )
            ),
            EnemyContactFixture(
                label: "SPLITTER",
                enemy: ArenaEnemy(
                    id: 8, position: CGPoint(x: 360, y: 274),
                    radius: radius * 1.85, speed: 0, behavior: .splitter
                )
            ),
            EnemyContactFixture(
                label: "SPLIT CHILD",
                enemy: ArenaEnemy(
                    id: 9, position: CGPoint(x: 480, y: 274),
                    radius: radius * 0.85, speed: 0, behavior: .splitterChild
                )
            ),
            EnemyContactFixture(
                label: "FROZEN",
                enemy: ArenaEnemy(
                    id: 10,
                    position: CGPoint(x: 600, y: 274),
                    radius: radius,
                    speed: 0,
                    frozenTimeRemaining: 1
                )
            )
        ]
    }

    private func addEnemyFixtures(
        _ fixtures: [EnemyContactFixture],
        labelY: CGFloat,
        to scene: SKScene,
        theme: ArenaTheme
    ) {
        for fixture in fixtures {
            scene.addChild(EnemyNode(enemy: fixture.enemy, theme: theme))
            addContactLabel(
                fixture.label,
                at: CGPoint(x: fixture.enemy.position.x, y: labelY),
                to: scene,
                theme: theme
            )
        }
    }

    private func addEffectAndPickupRow(to scene: SKScene, theme: ArenaTheme) {
        let telegraph = EnemyTelegraph(
            id: 1,
            segments: [
                EnemyTelegraphSegment(start: CGPoint(x: 58, y: 166), end: CGPoint(x: 142, y: 206)),
                EnemyTelegraphSegment(start: CGPoint(x: 58, y: 206), end: CGPoint(x: 142, y: 166))
            ]
        )
        scene.addChild(EnemyTelegraphNode(telegraph: telegraph, theme: theme))
        addContactLabel("TELEGRAPH", at: CGPoint(x: 100, y: 148), to: scene, theme: theme)

        let flameTrail = FlameTrailEffectNode(theme: theme)
        flameTrail.apply(segments: [
            FlameTrailSegment(id: 1, position: CGPoint(x: 190, y: 172), radius: 16, timeRemaining: 1.0, lifetime: 1.2),
            FlameTrailSegment(id: 2, position: CGPoint(x: 216, y: 186), radius: 16, timeRemaining: 0.7, lifetime: 1.2),
            FlameTrailSegment(id: 3, position: CGPoint(x: 242, y: 200), radius: 16, timeRemaining: 0.4, lifetime: 1.2)
        ])
        scene.addChild(flameTrail)
        addContactLabel("FLAME TRAIL", at: CGPoint(x: 216, y: 148), to: scene, theme: theme)

        for (index, kind) in WeaponKind.allCases.enumerated() {
            let pickupX = 58 + CGFloat(index) * 58
            let pickup = WeaponPickup(
                id: index + 1,
                kind: kind,
                position: CGPoint(x: pickupX, y: 78),
                radius: 12
            )
            scene.addChild(WeaponPickupNode(pickup: pickup, theme: theme))
            addContactLabel(
                label(for: kind),
                at: CGPoint(x: pickup.position.x, y: 56),
                to: scene,
                theme: theme
            )
        }
    }

    private func label(for kind: WeaponKind) -> String {
        Self.weaponLabels[kind] ?? kind.displayName.uppercased()
    }

    private func addContactLabel(_ text: String, at position: CGPoint, to scene: SKScene, theme: ArenaTheme) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 10
        label.fontColor = theme.playerColor.withAlphaComponent(0.82)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 80
        scene.addChild(label)
    }
}
