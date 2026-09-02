import XCTest
@testable import TiltArena

final class ArenaNavigationStateTests: XCTestCase {
    func testTransitionClearsContextualState() {
        var state = ArenaNavigationState()
        state.isResetDataArmed = true
        state.gameCenterStatusMessage = "OFFLINE"

        let transition = state.transition(to: .awards)

        XCTAssertEqual(transition, ArenaNavigationTransition(previous: .home, current: .awards))
        XCTAssertFalse(state.isResetDataArmed)
        XCTAssertNil(state.gameCenterStatusMessage)
    }

    func testBackNavigationReturnsToPresentingScreen() {
        var state = ArenaNavigationState()
        _ = state.transition(to: .pause)
        state.prepareOptionsPresentation()
        _ = state.transition(to: .options)

        XCTAssertTrue(state.shouldLockCurrentOrientation)
        XCTAssertEqual(state.prepareBackNavigation(), .pause)
    }

    func testDeveloperSelectionResetsDependentState() {
        var state = ArenaDeveloperTuningNavigationState()
        state.selectGroup("Player")
        state.selectSubgroup("Movement")
        state.moveToNextPage(lastPageIndex: 3)
        state.confirmation = "COPIED"

        state.selectGroup("Weapons")

        XCTAssertEqual(state.selectedGroup, "Weapons")
        XCTAssertNil(state.selectedSubgroup)
        XCTAssertEqual(state.pageIndex, 0)
        XCTAssertNil(state.confirmation)
    }
}
