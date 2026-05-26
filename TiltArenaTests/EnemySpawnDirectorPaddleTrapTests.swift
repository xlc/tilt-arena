import CoreGraphics
import XCTest
@testable import TiltArena

final class EnemySpawnDirectorPaddleTrapTests: XCTestCase {
    func testPaddleTrapDoesNotTelegraphBeforeChaos() {
        var director = EnemySpawnDirector(configuration: paddleTrapTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)

        let pressureFrame = director.update(
            deltaTime: 100,
            survivalTime: 89.9,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )

        XCTAssertTrue(pressureFrame.telegraphsToShow.isEmpty)

        let chaosFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )

        XCTAssertEqual(chaosFrame.telegraphsToShow.count, 1)
        XCTAssertTrue(chaosFrame.newEnemies.isEmpty)
    }

    func testPaddleTrapUsesChaosAndSurvivalHellDefaults() {
        let configuration = EnemySpawnConfiguration()
        let chaos = configuration.tuning(at: 90)
        let survivalHell = configuration.tuning(at: 180)

        XCTAssertEqual(chaos.paddleTrapSpawnInterval, 16.5)
        XCTAssertEqual(chaos.maxActivePaddleTraps, 1)
        XCTAssertEqual(chaos.paddleTrapLifetime, 7, accuracy: 0.0001)
        XCTAssertEqual(chaos.paddleTrapBarEnemyCount, 4)
        XCTAssertEqual(chaos.paddleTrapDotSpeed, 172, accuracy: 0.0001)
        XCTAssertEqual(survivalHell.paddleTrapSpawnInterval, 12)
        XCTAssertEqual(survivalHell.maxActivePaddleTraps, 2)
        XCTAssertEqual(survivalHell.paddleTrapLifetime, 8, accuracy: 0.0001)
        XCTAssertEqual(survivalHell.paddleTrapBarEnemyCount, 5)
        XCTAssertEqual(survivalHell.paddleTrapDotSpeed, 214, accuracy: 0.0001)
    }

    func testPaddleTrapTelegraphsBeforeSpawningAndBuildsTrapComponents() throws {
        var director = EnemySpawnDirector(configuration: paddleTrapTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)
        XCTAssertEqual(telegraphFrame.telegraphsToShow[0].segments.count, 3)
        XCTAssertTrue(telegraphFrame.newEnemies.isEmpty)

        let waitingFrame = director.update(
            deltaTime: 0.5,
            survivalTime: 90.5,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(waitingFrame.newEnemies.isEmpty)
        XCTAssertTrue(waitingFrame.telegraphIDsToRemove.isEmpty)

        let spawnFrame = director.update(
            deltaTime: 0.5,
            survivalTime: 91,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(spawnFrame.telegraphIDsToRemove, [telegraphFrame.telegraphsToShow[0].id])
        XCTAssertEqual(spawnFrame.newEnemies.count, 9)
        XCTAssertEqual(Set(spawnFrame.newEnemies.compactMap(\.paddleTrapID)), [1])
        XCTAssertEqual(spawnFrame.newEnemies.filter(\.isPaddleTrap).count, 9)
        XCTAssertEqual(spawnFrame.newEnemies.filter(isPaddleTrapBar).count, 8)

        let dot = try XCTUnwrap(spawnFrame.newEnemies.first(where: isPaddleTrapDot))
        let velocity = paddleTrapDotVelocity(for: dot)
        XCTAssertEqual(hypot(velocity.dx, velocity.dy), 145, accuracy: 0.0001)
        XCTAssertNil(dot.formationID)
        XCTAssertFalse(dot.isLinearPatternEnemy)
    }

    func testPendingPaddleTrapComponentsCountAgainstActiveCap() {
        var configuration = paddleTrapTestConfiguration()
        configuration.chaos.maxActiveEnemies = 17
        configuration.chaos.maxActivePaddleTraps = 2
        configuration.chaos.paddleTrapSpawnInterval = 0.1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let cappedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
        XCTAssertTrue(cappedFrame.telegraphsToShow.isEmpty)
    }

    func testPendingPaddleTrapCountsAgainstTrapSpecificCap() {
        var configuration = paddleTrapTestConfiguration()
        configuration.chaos.paddleTrapSpawnInterval = 0.1
        configuration.chaos.maxActivePaddleTraps = 1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let cappedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(cappedFrame.newEnemies.isEmpty)
        XCTAssertTrue(cappedFrame.telegraphsToShow.isEmpty)
    }

    func testActivePaddleTrapCountsAgainstTrapSpecificCap() {
        var configuration = paddleTrapTestConfiguration()
        configuration.chaos.maxActivePaddleTraps = 1
        var director = EnemySpawnDirector(configuration: configuration)

        let frame = director.update(
            deltaTime: 1,
            survivalTime: 90,
            activeEnemies: [paddleTrapBarEnemy()],
            playableRect: CGRect(x: 0, y: 0, width: 300, height: 300),
            playerPosition: CGPoint(x: 150, y: 150),
            pickupCircles: []
        )

        XCTAssertTrue(frame.newEnemies.isEmpty)
        XCTAssertTrue(frame.telegraphsToShow.isEmpty)
    }

    func testPaddleTrapPlacementAvoidsPlayerPickupsAndActiveEnemies() {
        var configuration = paddleTrapTestConfiguration()
        configuration.playerSafetyRadius = 30
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 117, y: 117)
        let pickupCircle = CollisionCircle(center: CGPoint(x: 150, y: 117), radius: 16)
        let activeEnemy = ArenaEnemy(
            id: 20_000,
            position: CGPoint(x: 183, y: 117),
            radius: 8,
            speed: 0
        )

        _ = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [activeEnemy],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        let spawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 91,
            activeEnemies: [activeEnemy],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: [pickupCircle]
        )

        XCTAssertEqual(spawnFrame.newEnemies.count, 9)

        for enemy in spawnFrame.newEnemies {
            XCTAssertTrue(director.isSafeSpawn(
                enemy.position,
                avoiding: playerPosition,
                pickupCircles: [pickupCircle]
            ))
            XCTAssertGreaterThan(
                distance(from: enemy.position, to: activeEnemy.position),
                activeEnemy.radius + enemy.radius
            )
        }
    }

    func testPendingPaddleTrapSpacingCanBlockNearbyTrap() {
        var configuration = paddleTrapTestConfiguration()
        configuration.maxPendingEnemyTelegraphs = 2
        configuration.paddleTrapMinimumSpacing = 1_000
        configuration.chaos.maxActiveEnemies = 40
        configuration.chaos.maxActivePaddleTraps = 2
        configuration.chaos.paddleTrapSpawnInterval = 0.1
        var director = EnemySpawnDirector(configuration: configuration)
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let telegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertEqual(telegraphFrame.telegraphsToShow.count, 1)

        let blockedFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90.1,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        XCTAssertTrue(blockedFrame.newEnemies.isEmpty)
        XCTAssertTrue(blockedFrame.telegraphsToShow.isEmpty)
    }

    func testResetRestartsPaddleTrapTimersAndIDs() throws {
        var director = EnemySpawnDirector(configuration: paddleTrapTestConfiguration())
        let playableRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let playerPosition = CGPoint(x: 150, y: 150)

        let firstTelegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )
        let firstSpawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 91,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        director.reset()

        let resetTelegraphFrame = director.update(
            deltaTime: 0.1,
            survivalTime: 90,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )
        let resetSpawnFrame = director.update(
            deltaTime: 1,
            survivalTime: 91,
            activeEnemies: [],
            playableRect: playableRect,
            playerPosition: playerPosition,
            pickupCircles: []
        )

        let firstEnemy = try XCTUnwrap(firstSpawnFrame.newEnemies.first)
        let resetEnemy = try XCTUnwrap(resetSpawnFrame.newEnemies.first)
        XCTAssertEqual(firstTelegraphFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(resetTelegraphFrame.telegraphsToShow.first?.id, 1)
        XCTAssertEqual(firstEnemy.id, 1)
        XCTAssertEqual(resetEnemy.id, 1)
        XCTAssertEqual(firstEnemy.paddleTrapID, 1)
        XCTAssertEqual(resetEnemy.paddleTrapID, 1)
        XCTAssertEqual(firstEnemy.position, resetEnemy.position)
    }

    private func paddleTrapTestConfiguration() -> EnemySpawnConfiguration {
        var configuration = EnemySpawnConfiguration()
        configuration.playerSafetyRadius = 20
        configuration.paddleTrapTelegraphDuration = 1
        configuration.paddleTrapMinimumSpacing = 64
        configuration.warmup = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.pressure = disabledPhaseTuning(maxActiveEnemies: 20)
        configuration.chaos = paddleTrapPhaseTuning(
            spawnInterval: 24,
            maxTraps: 1,
            lifetime: 7,
            barCount: 4,
            dotSpeed: 145
        )
        configuration.survivalHell = paddleTrapPhaseTuning(
            spawnInterval: 18,
            maxTraps: 2,
            lifetime: 8,
            barCount: 5,
            dotSpeed: 170
        )
        return configuration
    }

    private func paddleTrapPhaseTuning(
        spawnInterval: TimeInterval,
        maxTraps: Int,
        lifetime: TimeInterval,
        barCount: Int,
        dotSpeed: CGFloat
    ) -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: 20,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5,
            arrowRushSpawnInterval: nil,
            arrowRushSpeed: 0,
            arrowRushEnemyCount: 0,
            mineDotSpawnInterval: nil,
            maxActiveMineDots: 0,
            hunterDotSpawnInterval: nil,
            hunterDotSpeed: 0,
            hunterDotPredictionLead: 0,
            maxActiveHunterDots: 0,
            paddleTrapSpawnInterval: spawnInterval,
            maxActivePaddleTraps: maxTraps,
            paddleTrapLifetime: lifetime,
            paddleTrapBarEnemyCount: barCount,
            paddleTrapDotSpeed: dotSpeed
        )
    }

    private func disabledPhaseTuning(maxActiveEnemies: Int) -> EnemyPhaseTuning {
        EnemyPhaseTuning(
            chaserSpawnInterval: 0,
            chaserSpeed: 0,
            maxActiveEnemies: maxActiveEnemies,
            formationSpawnInterval: nil,
            formationSpeed: 0,
            formationLaneCount: 5
        )
    }

    private func paddleTrapBarEnemy() -> ArenaEnemy {
        ArenaEnemy(
            id: 10_000,
            position: CGPoint(x: 20, y: 20),
            radius: 8,
            speed: 0,
            behavior: .paddleTrapBar(trapID: 99, remainingLifetime: 7)
        )
    }

    private func isPaddleTrapBar(_ enemy: ArenaEnemy) -> Bool {
        guard case .paddleTrapBar = enemy.behavior else {
            return false
        }

        return true
    }

    private func isPaddleTrapDot(_ enemy: ArenaEnemy) -> Bool {
        guard case .paddleTrapDot = enemy.behavior else {
            return false
        }

        return true
    }

    private func paddleTrapDotVelocity(for enemy: ArenaEnemy) -> CGVector {
        guard case let .paddleTrapDot(_, velocity, _, _) = enemy.behavior else {
            XCTFail("Expected Paddle Trap dot behavior.")
            return .zero
        }

        return velocity
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
