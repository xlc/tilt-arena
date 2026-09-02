import XCTest
@testable import TiltArena

final class ArenaRunSessionStateTests: XCTestCase {
    func testPreparingNewRunClearsCompletionStateButKeepsSelectedMode() {
        var state = ArenaRunSessionState()
        state.selectMode(.redline)
        state.beginRunCompletion(previousBestScore: 12, collision: nil, transitionDuration: 0.22)

        state.prepareNewRun()

        XCTAssertEqual(state.selectedMode, .redline)
        XCTAssertFalse(state.isResolvingDeath)
        XCTAssertNil(state.postRunTransitionTimeRemaining)
        XCTAssertTrue(state.needsFinalRunPersistence)
    }

    func testPostRunTransitionCompletesOnlyAfterDurationElapses() {
        var state = ArenaRunSessionState()
        state.beginRunCompletion(previousBestScore: 0, collision: nil, transitionDuration: 0.22)

        XCTAssertFalse(state.advancePostRunTransition(by: 0.1))
        XCTAssertTrue(state.advancePostRunTransition(by: 0.13))

        state.completePostRunTransition()
        XCTAssertFalse(state.isResolvingDeath)
        XCTAssertNil(state.postRunTransitionTimeRemaining)
    }
}
