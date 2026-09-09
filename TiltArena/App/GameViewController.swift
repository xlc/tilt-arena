import SpriteKit
import UIKit
#if canImport(GameKit)
import GameKit
#endif

final class GameViewController: UIViewController {
    private var hasPresentedScene = false
    private var lockedOrientationMask: UIInterfaceOrientationMask?
    private var lastLandscapeOrientation: UIInterfaceOrientation?
    private weak var loadingOverlayView: GameLoadingOverlayView?
    private let logger = AppDiagnostics.logger(.app)
    private var diagnosticsReportTask: Task<Void, Never>?
    private weak var diagnosticsPreviewController: DiagnosticsPreviewController?
    private let gameCenterClient: any GameCenterClient

    init(gameCenterClient: any GameCenterClient = NoopGameCenterClient()) {
        self.gameCenterClient = gameCenterClient
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("GameViewController does not support storyboard initialization.")
    }

    override func loadView() {
        view = SKView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSpriteView()
        installLoadingOverlay()
        installGameCenterStatusObserver()
        logger.info("view.loaded")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logger.info("view.appeared")
        gameCenterClient.authenticate(presenter: nil, allowsPrompt: false)
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
        spriteView.showsFPS = false
        spriteView.showsNodeCount = false
        #endif
    }

    private func presentArenaScene(in spriteView: SKView) {
        let scene = ArenaScene(
            size: spriteView.bounds.size,
            gameCenterReporter: gameCenterClient
        )
        scene.orientationDelegate = self
        scene.diagnosticsDelegate = self
        scene.gameCenterDelegate = self
        scene.scaleMode = .resizeFill
        spriteView.presentScene(scene)
        scene.refreshSafeAreaLayout()
        hasPresentedScene = true
        logger.notice("scene.presentation_completed", metadata: [
            "height": "\(spriteView.bounds.height.rounded())",
            "width": "\(spriteView.bounds.width.rounded())"
        ])
        loadingOverlayView?.hideWhenReady()
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

    private func refreshPresentedSceneGameCenterStatus() {
        ((view as? SKView)?.scene as? ArenaScene)?.refreshGameCenterMenuStatus()
    }

    func pauseActiveRunIfNeeded() {
        ((viewIfLoaded as? SKView)?.scene as? ArenaScene)?.pauseActiveRunIfNeeded()
    }

    private func installGameCenterStatusObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gameCenterMenuStatusDidChange),
            name: .gameCenterMenuStatusDidChange,
            object: gameCenterClient
        )
    }

    @objc private func gameCenterMenuStatusDidChange(_ notification: Notification) {
        refreshPresentedSceneGameCenterStatus()
    }

    private func installLoadingOverlay() {
        guard loadingOverlayView == nil, let spriteView = view as? SKView else {
            return
        }

        loadingOverlayView = GameLoadingOverlayView.install(in: spriteView, compatibleWith: traitCollection)
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
        logger.info("orientation.locked", metadata: [
            "orientation": "\(resolvedOrientation.rawValue)"
        ])
        return TiltScreenOrientation(interfaceOrientation: resolvedOrientation) ?? fallback
    }

    func unlockRunOrientation() {
        lockedOrientationMask = nil
        setNeedsUpdateOfSupportedInterfaceOrientations()
        logger.info("orientation.unlocked")
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

extension GameViewController: ArenaSceneDiagnosticsDelegate {
    func arenaSceneRequestsDiagnosticsPresentation(
        _ scene: ArenaScene,
        snapshot: DiagnosticGameplaySnapshot
    ) {
        guard diagnosticsReportTask == nil, diagnosticsPreviewController == nil else {
            logger.info("diagnostics.presentation_skipped", metadata: [
                "reason": "already_active"
            ])
            return
        }

        logger.info("diagnostics.report_build_started")
        diagnosticsReportTask = Task { [weak self] in
            defer { self?.diagnosticsReportTask = nil }

            do {
                let reportURL = try await Task.detached(priority: .userInitiated) {
                    try AppDiagnostics.makeReport(gameplay: snapshot)
                }.value
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: reportURL)
                    self?.logger.info("diagnostics.report_build_cancelled")
                    return
                }

                guard let self else {
                    try? FileManager.default.removeItem(at: reportURL)
                    return
                }

                self.presentDiagnosticsReport(at: reportURL)
            } catch {
                self?.logger.error("diagnostics.report_build_failed", error: error)
                self?.presentDiagnosticsFailureAlert()
            }
        }
    }

    func presentDiagnosticsReport(at reportURL: URL) {
        guard let windowScene = viewIfLoaded?.window?.windowScene else {
            logger.warning("diagnostics.presentation_rejected", metadata: [
                "reason": "view_detached"
            ])
            removeDiagnosticsReport(at: reportURL)
            return
        }
        guard windowScene.activationState == .foregroundActive else {
            logger.warning("diagnostics.presentation_rejected", metadata: [
                "reason": "scene_inactive"
            ])
            removeDiagnosticsReport(at: reportURL)
            return
        }
        guard presentedViewController == nil else {
            logger.info("diagnostics.presentation_rejected", metadata: [
                "reason": "another_controller_presented"
            ])
            removeDiagnosticsReport(at: reportURL)
            return
        }

        let previewController = makeDiagnosticsPreviewController(reportURL: reportURL)
        diagnosticsPreviewController = previewController

        let navigationController = UINavigationController(rootViewController: previewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true) { [weak self, weak navigationController] in
            guard let self, self.presentedViewController === navigationController else {
                return
            }
            self.logger.notice("diagnostics.preview_presented")
        }
    }

    private func makeDiagnosticsPreviewController(reportURL: URL) -> DiagnosticsPreviewController {
        DiagnosticsPreviewController(
            reportURL: reportURL,
            onDone: { [weak self] in
                self?.logger.info("diagnostics.preview_done")
            },
            onShare: { [weak self] url, presenter, sourceButton in
                self?.presentDiagnosticsShareSheet(
                    reportURL: url,
                    presenter: presenter,
                    sourceButton: sourceButton
                )
            },
            onDismiss: { [weak self] in
                guard let self else {
                    try? FileManager.default.removeItem(at: reportURL)
                    return
                }
                self.diagnosticsPreviewController = nil
                self.removeDiagnosticsReport(at: reportURL)
            }
        )
    }

    private func presentDiagnosticsShareSheet(
        reportURL: URL,
        presenter: UIViewController,
        sourceButton: UIBarButtonItem
    ) {
        guard presenter.presentedViewController == nil else {
            logger.info("diagnostics.share_skipped", metadata: [
                "reason": "another_controller_presented"
            ])
            return
        }

        let activityController = UIActivityViewController(
            activityItems: [reportURL],
            applicationActivities: nil
        )
        activityController.popoverPresentationController?.barButtonItem = sourceButton
        activityController.completionWithItemsHandler = { [weak self] _, completed, _, error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.logger.error("diagnostics.share_failed", error: error)
                } else {
                    self?.logger.info("diagnostics.share_completed", metadata: [
                        "completed": "\(completed)"
                    ])
                }
            }
        }
        logger.notice("diagnostics.share_presented")
        presenter.present(activityController, animated: true)
    }

    private func presentDiagnosticsFailureAlert() {
        guard
            viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive,
            presentedViewController == nil
        else {
            logger.info("diagnostics.failure_alert_skipped", metadata: [
                "reason": "presentation_unavailable"
            ])
            return
        }

        let alert = UIAlertController(
            title: "Logs Unavailable",
            message: "Tilt Arena could not prepare the diagnostic report. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func removeDiagnosticsReport(at reportURL: URL) {
        do {
            try FileManager.default.removeItem(at: reportURL)
            logger.info("diagnostics.report_removed")
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            logger.warning("diagnostics.report_remove_failed", error: error)
        }
    }
}

extension GameViewController: GameCenterAuthenticationPresenting {
    func presentGameCenterAuthentication(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
}

extension GameViewController: GameCenterLeaderboardPresenting {
    func presentGameCenterLeaderboard(_ viewController: UIViewController) {
        #if canImport(GameKit)
        if let gameCenterViewController = viewController as? GKGameCenterViewController {
            gameCenterViewController.gameCenterDelegate = self
        }
        #endif

        present(viewController, animated: true)
    }
}

extension GameViewController: ArenaSceneGameCenterDelegate {
    func arenaSceneGameCenterMenuStatus(_ scene: ArenaScene) -> GameCenterMenuStatus {
        gameCenterClient.menuStatus
    }

    func arenaSceneRequestsClassicLeaderboard(_ scene: ArenaScene) -> GameCenterLeaderboardPresentationResult {
        let result = gameCenterClient.presentClassicSurvivalLeaderboard(presenter: self)
        if result == .unavailable(.authenticationRequired) {
            gameCenterClient.retryAuthentication(presenter: self)
        }
        return result
    }
}

#if canImport(GameKit)
extension GameViewController: @preconcurrency GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        dismiss(animated: true)
    }
}
#endif
