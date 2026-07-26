import CoreGraphics
import XCTest
@testable import TiltArena

final class EnemySpawnDirectorBalanceTests: XCTestCase {
    private enum Threat: Hashable {
        case chaser
        case formation
        case arrowRush
        case mine
        case hunter
        case paddleTrap
        case splitter
    }

    private struct SpawnSummary {
        var firstAppearance: [Threat: TimeInterval] = [:]
        var counts: [Threat: Int] = [:]
    }

    private struct IntroductionWindow {
        let threat: Threat
        let earliest: TimeInterval
        let latest: TimeInterval
    }

    private struct SimulationContext {
        let configuration: EnemySpawnConfiguration
        let playableRect = CGRect(x: 67, y: 8, width: 718, height: 377)
        let deltaTime: TimeInterval
        let frameCount: Int

        var playerPosition: CGPoint {
            CGPoint(x: playableRect.midX, y: playableRect.midY)
        }

        var pickup: CollisionCircle {
            CollisionCircle(center: CGPoint(x: playableRect.midX + 100, y: playableRect.midY), radius: 8.5)
        }

        var playerMaximumSpeed: CGFloat {
            PlayerMovementConfiguration().maximumSpeed(in: playableRect)
        }

        var cullingRect: CGRect {
            playableRect.insetBy(dx: -configuration.cullingOutset, dy: -configuration.cullingOutset)
        }

        init(mode: ArenaModeKind, framesPerSecond: Int) {
            configuration = ArenaModeRules.runSettings(for: mode).enemySpawnConfiguration
            deltaTime = 1 / TimeInterval(framesPerSecond)
            frameCount = 180 * framesPerSecond
        }
    }

    func testClassicRealizesStagedThreatIntroductionsAcrossFullRun() throws {
        let summary = simulate(mode: .classic, framesPerSecond: 60)
        let expectedWindows = [
            IntroductionWindow(threat: .formation, earliest: 30, latest: 34),
            IntroductionWindow(threat: .splitter, earliest: 50, latest: 53),
            IntroductionWindow(threat: .mine, earliest: 70, latest: 74),
            IntroductionWindow(threat: .arrowRush, earliest: 95, latest: 99),
            IntroductionWindow(threat: .hunter, earliest: 120, latest: 125),
            IntroductionWindow(threat: .paddleTrap, earliest: 150, latest: 170)
        ]

        for window in expectedWindows {
            let firstAppearance = try XCTUnwrap(
                summary.firstAppearance[window.threat],
                "Missing \(window.threat)"
            )
            XCTAssertGreaterThanOrEqual(
                firstAppearance,
                window.earliest,
                "\(window.threat) arrived before it was taught"
            )
            XCTAssertLessThan(
                firstAppearance,
                window.latest,
                "\(window.threat) was starved by the shared telegraph schedule"
            )
        }
    }

    func testRedlineAcceleratesPressureWithoutDroppingThreatRoles() throws {
        let classic = simulate(mode: .classic, framesPerSecond: 60)
        let redline = simulate(mode: .redline, framesPerSecond: 60)
        let redlineWindows = [
            IntroductionWindow(threat: .formation, earliest: 0, latest: 3),
            IntroductionWindow(threat: .arrowRush, earliest: 0, latest: 3),
            IntroductionWindow(threat: .splitter, earliest: 15, latest: 18),
            IntroductionWindow(threat: .mine, earliest: 30, latest: 35),
            IntroductionWindow(threat: .hunter, earliest: 45, latest: 51),
            IntroductionWindow(threat: .paddleTrap, earliest: 60, latest: 75)
        ]

        for window in redlineWindows {
            let firstAppearance = try XCTUnwrap(
                redline.firstAppearance[window.threat],
                "Missing \(window.threat)"
            )
            XCTAssertGreaterThanOrEqual(firstAppearance, window.earliest)
            XCTAssertLessThan(firstAppearance, window.latest)
        }

        XCTAssertGreaterThan(redline.counts[.chaser, default: 0], classic.counts[.chaser, default: 0])
        XCTAssertGreaterThan(redline.counts[.arrowRush, default: 0], classic.counts[.arrowRush, default: 0])
        XCTAssertGreaterThan(redline.counts.values.reduce(0, +), classic.counts.values.reduce(0, +))
    }

    func testSpawnScheduleIsStableAcrossThirtyAndOneHundredTwentyHertz() throws {
        let lowRate = simulate(mode: .classic, framesPerSecond: 30)
        let highRate = simulate(mode: .classic, framesPerSecond: 120)

        for threat in [Threat.formation, .splitter, .mine, .arrowRush, .hunter, .paddleTrap] {
            let lowAppearance = try XCTUnwrap(lowRate.firstAppearance[threat])
            let highAppearance = try XCTUnwrap(highRate.firstAppearance[threat])
            XCTAssertEqual(lowAppearance, highAppearance, accuracy: 0.12, "\(threat) timing drifted with frame rate")
        }

        for threat in [Threat.chaser, .formation, .arrowRush, .mine, .hunter, .paddleTrap, .splitter] {
            XCTAssertEqual(
                lowRate.counts[threat, default: 0],
                highRate.counts[threat, default: 0],
                accuracy: 1,
                "\(threat) spawn count drifted with frame rate"
            )
        }
    }

    private func simulate(mode: ArenaModeKind, framesPerSecond: Int) -> SpawnSummary {
        let context = SimulationContext(mode: mode, framesPerSecond: framesPerSecond)
        var director = EnemySpawnDirector(
            configuration: context.configuration,
            sequenceSeed: 20_260_726
        )
        let simulatedClearDelay: TimeInterval = 6
        var summary = SpawnSummary()
        var activeEnemies: [ArenaEnemy] = []
        var spawnTimes: [Int: TimeInterval] = [:]

        for frameIndex in 1...context.frameCount {
            let survivalTime = TimeInterval(frameIndex) * context.deltaTime
            let frame = director.update(
                deltaTime: context.deltaTime,
                survivalTime: survivalTime,
                activeEnemies: activeEnemies,
                playableRect: context.playableRect,
                playerPosition: context.playerPosition,
                pickupCircles: [context.pickup]
            )

            for enemy in frame.newEnemies {
                let threat = threat(for: enemy)
                summary.firstAppearance[threat] = summary.firstAppearance[threat] ?? survivalTime
                summary.counts[threat, default: 0] += 1
                spawnTimes[enemy.id] = survivalTime
            }
            activeEnemies.append(contentsOf: frame.newEnemies)

            advancePopulation(
                &activeEnemies,
                survivalTime: survivalTime,
                deltaTime: context.deltaTime,
                playerPosition: context.playerPosition,
                playerMaximumSpeed: context.playerMaximumSpeed,
                configuration: context.configuration
            )
            clearResolvedPopulation(
                &activeEnemies,
                at: survivalTime,
                spawnTimes: spawnTimes,
                cullingRect: context.cullingRect,
                simulatedClearDelay: simulatedClearDelay
            )
        }

        return summary
    }

    private func advancePopulation(
        _ activeEnemies: inout [ArenaEnemy],
        survivalTime: TimeInterval,
        deltaTime: TimeInterval,
        playerPosition: CGPoint,
        playerMaximumSpeed: CGFloat,
        configuration: EnemySpawnConfiguration
    ) {
        let speedMultiplier = configuration.enemySurvivalSpeedMultiplier(at: survivalTime)
        for index in activeEnemies.indices {
            activeEnemies[index].advance(
                toward: playerPosition,
                deltaTime: deltaTime,
                externalSpeedMultiplier: speedMultiplier,
                maximumSpeed: configuration.maximumSpeed(
                    for: activeEnemies[index].behavior.kind,
                    playerMaximumSpeed: playerMaximumSpeed
                )
            )
        }
    }

    private func clearResolvedPopulation(
        _ activeEnemies: inout [ArenaEnemy],
        at survivalTime: TimeInterval,
        spawnTimes: [Int: TimeInterval],
        cullingRect: CGRect,
        simulatedClearDelay: TimeInterval
    ) {
        // A neutral clear cadence keeps pressure resident long enough to exercise
        // total/per-role caps without pretending to model player skill.
        activeEnemies.removeAll { enemy in
            let age = survivalTime - (spawnTimes[enemy.id] ?? survivalTime)
            return enemy.isExpired
                || (enemy.isLinearPatternEnemy && !cullingRect.contains(enemy.position))
                || age >= simulatedClearDelay
        }
    }

    private func threat(for enemy: ArenaEnemy) -> Threat {
        switch enemy.behavior {
        case .chaser:
            return .chaser
        case .formationLine:
            return .formation
        case .arrowRush:
            return .arrowRush
        case .mineDot:
            return .mine
        case .hunterDot:
            return .hunter
        case .paddleTrapBar, .paddleTrapDot:
            return .paddleTrap
        case .splitter, .splitterChild:
            return .splitter
        }
    }
}
