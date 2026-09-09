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

    func testDeveloperMenuClampsPageAfterViewportGrows() {
        var state = ArenaDeveloperTuningNavigationState()
        state.selectGroup("Classic")
        state.selectSubgroup("Enemies")
        let firstMenu = state.menu(tuning: .defaults, pageSize: 1)
        state.moveToNextPage(lastPageIndex: firstMenu.pageCount - 1)
        XCTAssertEqual(state.pageIndex, 1)

        let menu = state.menu(tuning: .defaults, pageSize: firstMenu.parameters.count)

        XCTAssertEqual(menu.pageIndex, 0)
        XCTAssertEqual(state.pageIndex, 0)
        XCTAssertEqual(menu.pageCount, 1)
        XCTAssertEqual(menu.visibleParameters.map(\.id), firstMenu.parameters.map(\.id))
    }

    func testDeveloperMenuReconcilesSelectionWhenChangedParameterIsReset() {
        var state = ArenaDeveloperTuningNavigationState()
        var tuning = GameTuningConfiguration.defaults
        tuning.playerMovement.visualRadius += 1
        tuning.startingWeapons.ricochetLanceMaximumBounces += 1
        state.toggleChangedOnly()
        state.selectGroup("Weapons")
        state.selectSubgroup("Ricochet Lance")
        XCTAssertEqual(state.menu(tuning: tuning, pageSize: 3).selectedGroup, "Weapons")

        tuning.startingWeapons.ricochetLanceMaximumBounces = GameTuningConfiguration.defaults.startingWeapons.ricochetLanceMaximumBounces
        let menu = state.menu(tuning: tuning, pageSize: 3)

        XCTAssertEqual(menu.selectedGroup, "Player")
        XCTAssertEqual(menu.visibleParameters.map(\.id), ["playerMovement.visualRadius"])
        XCTAssertEqual(menu.changedCount, 1)
        XCTAssertEqual(menu.pageIndex, 0)

        let empty = state.menu(tuning: .defaults, pageSize: 3)
        XCTAssertNil(empty.selectedGroup)
        XCTAssertNil(empty.selectedSubgroup)
        XCTAssertTrue(empty.visibleParameters.isEmpty)
        XCTAssertEqual(empty.pageCount, 1)
        XCTAssertEqual(state.pageIndex, 0)
    }

    func testDeveloperMenuLastPageContainsRemainderAndCannotAdvancePastEnd() {
        var state = ArenaDeveloperTuningNavigationState()
        state.selectGroup("Weapons")
        state.selectSubgroup("Ricochet Lance")
        let first = state.menu(tuning: .defaults, pageSize: 2)
        XCTAssertEqual(first.visibleParameters.count, 2)
        XCTAssertEqual(first.pageCount, 2)

        state.moveToNextPage(lastPageIndex: first.pageCount - 1)
        state.moveToNextPage(lastPageIndex: first.pageCount - 1)
        let last = state.menu(tuning: .defaults, pageSize: 2)

        XCTAssertEqual(last.pageIndex, 1)
        XCTAssertEqual(last.visibleParameters.map(\.id), ["startingWeapons.ricochetLanceHoldDuration"])
    }
}
