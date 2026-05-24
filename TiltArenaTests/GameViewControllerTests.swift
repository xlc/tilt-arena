import SpriteKit
import UIKit
import XCTest
@testable import TiltArena

final class GameViewControllerTests: XCTestCase {
    @MainActor
    func testSupportedOrientationsAreLandscapeOnly() {
        let controller = GameViewController()

        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscape)
    }

    @MainActor
    func testRunOrientationLockNarrowsToLandscapeLeft() {
        let controller = GameViewController()

        controller.lockRunOrientation(to: .landscapeLeft)

        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscapeLeft)
    }

    @MainActor
    func testRunOrientationLockNarrowsToLandscapeRight() {
        let controller = GameViewController()

        controller.lockRunOrientation(to: .landscapeRight)

        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscapeRight)
    }

    @MainActor
    func testRunOrientationUnlockRestoresBothLandscapeSides() {
        let controller = GameViewController()

        controller.lockRunOrientation(to: .landscapeLeft)
        controller.unlockRunOrientation()

        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscape)
    }

    @MainActor
    func testRunOrientationLockFallsBackToPreferredLandscapeSide() {
        let controller = GameViewController()

        let lockedOrientation = controller.lockRunOrientation(to: nil, fallback: .landscapeRight)

        XCTAssertEqual(lockedOrientation, .landscapeRight)
        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscapeRight)
    }

    @MainActor
    func testRunOrientationLockReusesLastConcreteLandscapeSide() {
        let controller = GameViewController()
        controller.lockRunOrientation(to: .landscapeRight)
        controller.unlockRunOrientation()

        let lockedOrientation = controller.lockRunOrientation(to: nil, fallback: .landscapeLeft)

        XCTAssertEqual(lockedOrientation, .landscapeRight)
        XCTAssertEqual(controller.supportedInterfaceOrientations, .landscapeRight)
    }

    @MainActor
    func testViewDidLoadInstallsLoadingScreenOverlay() {
        let spriteView = SafeAreaTestSKView(frame: CGRect(x: 0, y: 0, width: 852, height: 393))
        let controller = GameViewController()
        controller.view = spriteView

        controller.viewDidLoad()

        XCTAssertEqual(
            spriteView.subviews.filter { $0.accessibilityIdentifier == "game-loading-screen" }.count,
            1
        )
    }

    @MainActor
    func testSafeAreaInsetsChangeRefreshesPresentedSceneLayout() {
        let spriteView = SafeAreaTestSKView(frame: CGRect(x: 0, y: 0, width: 852, height: 393))
        let controller = GameViewController()
        controller.view = spriteView
        controller.viewDidLoad()
        controller.viewDidLayoutSubviews()

        guard let scene = spriteView.scene as? ArenaScene else {
            XCTFail("Expected GameViewController to present ArenaScene.")
            return
        }

        XCTAssertEqual(scene.movementController.state.position, CGPoint(x: 426, y: 196.5))

        spriteView.testSafeAreaInsets = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 47)
        controller.viewSafeAreaInsetsDidChange()

        XCTAssertEqual(scene.movementController.state.position, CGPoint(x: 432, y: 196.5))
    }

    @MainActor
    func testPausedRunSuspendsWeaponEffectPlaybackUntilResume() {
        let scene = ArenaScene(size: CGSize(width: 852, height: 393))
        scene.prepareActiveRunForTesting()
        scene.addWeaponEffectNodeForTesting(SKNode())

        XCTAssertFalse(scene.isWeaponEffectPlaybackPausedForTesting)
        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 1)

        scene.pauseRunForTesting()

        XCTAssertTrue(scene.isWeaponEffectPlaybackPausedForTesting)
        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 1)

        scene.resumeRunForTesting()

        XCTAssertFalse(scene.isWeaponEffectPlaybackPausedForTesting)
        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 1)
    }

    @MainActor
    func testEndingRunClearsPendingWeaponEffectsUntilNextRun() {
        let scene = ArenaScene(size: CGSize(width: 852, height: 393))
        scene.prepareActiveRunForTesting()
        scene.addWeaponEffectNodeForTesting(SKNode())

        scene.finishRunForTesting()

        XCTAssertTrue(scene.isWeaponEffectPlaybackPausedForTesting)
        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 0)

        scene.prepareActiveRunForTesting()

        XCTAssertFalse(scene.isWeaponEffectPlaybackPausedForTesting)
        XCTAssertEqual(scene.weaponEffectNodeCountForTesting, 0)
    }
}

private final class SafeAreaTestSKView: SKView {
    var testSafeAreaInsets: UIEdgeInsets = .zero

    override var safeAreaInsets: UIEdgeInsets {
        testSafeAreaInsets
    }
}
