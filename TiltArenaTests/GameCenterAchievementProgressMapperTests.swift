import Foundation
import XCTest
@testable import TiltArena

final class GameCenterAchievementProgressMapperTests: XCTestCase {
    func testRunFinishedMapsMilestoneProgress() {
        let summary = RunSummary(
            score: 50_000,
            survivalTime: 30,
            maxCombo: 25,
            enemiesDestroyed: 4,
            bestWeapon: .shockwave,
            timestamp: Date(timeIntervalSince1970: 1),
            mode: .classic
        )

        let progress = mappedProgress(for: .runFinished(summary))

        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstRun.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstEnemyClear.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo10.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo50.rawValue], 50)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.survive60.rawValue], 50)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.score100000.rawValue], 50)
    }

    func testEnemyClearMapsCompletedComboMilestonesAndChainReaction() {
        let progress = mappedProgress(for: .enemyClear(
            count: 2,
            weaponKind: .chainLightning,
            maxCombo: 12
        ))

        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstEnemyClear.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstChainReaction.rawValue], 100)
        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.combo10.rawValue], 100)
        XCTAssertNil(progress[GameCenterIdentifiers.Achievement.combo50.rawValue])
        XCTAssertNil(progress[GameCenterIdentifiers.Achievement.firstRun.rawValue])
    }

    func testEnemyClearDefersPartialComboProgressUntilRunFinishes() {
        let progress = mappedProgress(for: .enemyClear(count: 1, weaponKind: nil, maxCombo: 9))

        XCTAssertEqual(progress[GameCenterIdentifiers.Achievement.firstEnemyClear.rawValue], 100)
        XCTAssertNil(progress[GameCenterIdentifiers.Achievement.combo10.rawValue])
        XCTAssertNil(progress[GameCenterIdentifiers.Achievement.combo50.rawValue])
    }

    func testWeaponOrbMapsFirstOrbCompletion() {
        let progress = mappedProgress(for: .weaponOrbCollected)

        XCTAssertEqual(
            progress,
            [GameCenterIdentifiers.Achievement.firstWeaponOrb.rawValue: 100]
        )
    }

    private func mappedProgress(for event: GameCenterAchievementEvent) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: GameCenterAchievementProgressMapper
            .progress(for: event)
            .map { ($0.achievementID, $0.percentComplete) })
    }
}
