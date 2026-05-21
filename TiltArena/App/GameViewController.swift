import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var hasPresentedScene = false
    private var lockedOrientationMask: UIInterfaceOrientationMask?
    private var lastLandscapeOrientation: UIInterfaceOrientation?

    override func loadView() {
        view = SKView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSpriteView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rememberCurrentLandscapeOrientation()

        guard let spriteView = view as? SKView else {
            return
        }

        if hasPresentedScene {
            updatePresentedSceneSize(in: spriteView)
        } else {
            presentArenaScene(in: spriteView)
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refreshPresentedSceneSafeAreaLayout()
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        lockedOrientationMask ?? .landscape
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    private func configureSpriteView() {
        guard let spriteView = view as? SKView else {
            return
        }

        spriteView.ignoresSiblingOrder = true
        spriteView.shouldCullNonVisibleNodes = true
        spriteView.preferredFramesPerSecond = 120

        #if DEBUG
        spriteView.showsFPS = true
        spriteView.showsNodeCount = true
        #endif
    }

    private func presentArenaScene(in spriteView: SKView) {
        let scene = ArenaScene(size: spriteView.bounds.size)
        scene.orientationDelegate = self
        scene.scaleMode = .resizeFill
        spriteView.presentScene(scene)
        scene.refreshSafeAreaLayout()
        hasPresentedScene = true
    }

    private func updatePresentedSceneSize(in spriteView: SKView) {
        let sceneSize = spriteView.bounds.size
        guard spriteView.scene?.size != sceneSize else {
            return
        }

        spriteView.scene?.size = sceneSize
        refreshPresentedSceneSafeAreaLayout()
    }

    private func refreshPresentedSceneSafeAreaLayout() {
        ((view as? SKView)?.scene as? ArenaScene)?.refreshSafeAreaLayout()
    }

    @discardableResult
    func lockRunOrientation(
        to orientation: UIInterfaceOrientation?,
        fallback: TiltScreenOrientation = .landscapeLeft
    ) -> TiltScreenOrientation {
        let resolvedOrientation = Self.landscapeOrientation(for: orientation)
            ?? lastLandscapeOrientation
            ?? fallback.interfaceOrientation
        lastLandscapeOrientation = resolvedOrientation
        lockedOrientationMask = Self.landscapeMask(for: resolvedOrientation)
        setNeedsUpdateOfSupportedInterfaceOrientations()
        return TiltScreenOrientation(interfaceOrientation: resolvedOrientation) ?? fallback
    }

    func unlockRunOrientation() {
        lockedOrientationMask = nil
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private static func landscapeMask(for orientation: UIInterfaceOrientation?) -> UIInterfaceOrientationMask? {
        switch orientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return nil
        }
    }

    private static func landscapeOrientation(for orientation: UIInterfaceOrientation?) -> UIInterfaceOrientation? {
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            return orientation
        default:
            return nil
        }
    }

    private func rememberCurrentLandscapeOrientation() {
        if let orientation = Self.landscapeOrientation(for: view.window?.windowScene?.interfaceOrientation) {
            lastLandscapeOrientation = orientation
        }
    }
}

extension GameViewController: ArenaSceneOrientationDelegate {
    func arenaSceneRequestsRunOrientationLock(
        _ scene: ArenaScene,
        preferredOrientation: TiltScreenOrientation
    ) -> TiltScreenOrientation {
        lockRunOrientation(
            to: view.window?.windowScene?.interfaceOrientation,
            fallback: preferredOrientation
        )
    }

    func arenaSceneRequestsOrientationUnlock(_ scene: ArenaScene) {
        unlockRunOrientation()
    }
}
