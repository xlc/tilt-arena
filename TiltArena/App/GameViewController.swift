import SpriteKit
import UIKit
#if canImport(GameKit)
import GameKit
#endif

final class GameViewController: UIViewController {
    private static let loadingScreenAssetName = "LoadingScreen"
    private static let minimumLoadingScreenDuration: CFTimeInterval = 0.75

    private var hasPresentedScene = false
    private var lockedOrientationMask: UIInterfaceOrientationMask?
    private var lastLandscapeOrientation: UIInterfaceOrientation?
    private var loadingOverlayInstalledAt: CFTimeInterval?
    private var loadingOverlayView: UIView?
    private var isHidingLoadingOverlay = false
    private let logger = AppDiagnostics.logger(.app)
    private var diagnosticsReportTask: Task<Void, Never>?
    private weak var diagnosticsPreviewController: DiagnosticsPreviewController?

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
        guard !Self.isRunningUnitTests else {
            return
        }

        GameCenterService.shared.authenticate(presenter: nil, allowsPrompt: false)
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
        let scene = ArenaScene(size: spriteView.bounds.size)
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
        hideLoadingOverlayWhenReady()
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
            object: nil
        )
    }

    @objc private func gameCenterMenuStatusDidChange(_ notification: Notification) {
        refreshPresentedSceneGameCenterStatus()
    }

    private func installLoadingOverlay() {
        guard loadingOverlayView == nil, let spriteView = view as? SKView else {
            return
        }

        let overlayView = makeLoadingOverlayView()
        let imageView = makeLoadingImageView()
        let scrimView = makeLoadingScrimView()
        let stackView = makeLoadingStackView()
        for subview in [imageView, scrimView, stackView] {
            overlayView.addSubview(subview)
        }
        spriteView.addSubview(overlayView)

        activateLoadingOverlayConstraints(
            overlayView: overlayView,
            imageView: imageView,
            scrimView: scrimView,
            stackView: stackView,
            spriteView: spriteView
        )

        loadingOverlayInstalledAt = CACurrentMediaTime()
        loadingOverlayView = overlayView
    }

    private func makeLoadingOverlayView() -> UIView {
        let overlayView = UIView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = .black
        overlayView.isUserInteractionEnabled = false
        overlayView.accessibilityIdentifier = "game-loading-screen"
        return overlayView
    }

    private func makeLoadingImageView() -> UIImageView {
        let image = UIImage(
            named: Self.loadingScreenAssetName,
            in: Bundle(for: Self.self),
            compatibleWith: traitCollection
        )
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }

    private func makeLoadingScrimView() -> UIView {
        let scrimView = UIView()
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        scrimView.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        return scrimView
    }

    private func makeLoadingStackView() -> UIStackView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = UIColor(red: 0.18, green: 0.86, blue: 1, alpha: 1)
        spinner.startAnimating()

        let stackView = UIStackView(arrangedSubviews: [
            makeLoadingTitleLabel(),
            makeLoadingLabel(),
            spinner
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }

    private func makeLoadingTitleLabel() -> UILabel {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.text = "TILT ARENA"
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.65
        titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420).isActive = true
        return titleLabel
    }

    private func makeLoadingLabel() -> UILabel {
        let loadingLabel = UILabel()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        loadingLabel.text = "LOADING"
        loadingLabel.textAlignment = .center
        loadingLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        return loadingLabel
    }

    private func activateLoadingOverlayConstraints(
        overlayView: UIView,
        imageView: UIView,
        scrimView: UIView,
        stackView: UIView,
        spriteView: UIView
    ) {
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: spriteView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: spriteView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: spriteView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: spriteView.bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: overlayView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),

            scrimView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            scrimView.topAnchor.constraint(equalTo: overlayView.topAnchor),
            scrimView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),

            stackView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            stackView.bottomAnchor.constraint(
                equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor,
                constant: -26
            ),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: overlayView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: overlayView.trailingAnchor, constant: -24)
        ])
    }

    private func hideLoadingOverlayWhenReady() {
        guard let overlayView = loadingOverlayView, !isHidingLoadingOverlay else {
            return
        }

        let elapsed = CACurrentMediaTime() - (loadingOverlayInstalledAt ?? CACurrentMediaTime())
        let delay = max(0, Self.minimumLoadingScreenDuration - elapsed)
        isHidingLoadingOverlay = true

        UIView.animate(
            withDuration: 0.25,
            delay: delay,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: {
                overlayView.alpha = 0
            },
            completion: { [weak self, weak overlayView] _ in
                overlayView?.removeFromSuperview()
                self?.loadingOverlayView = nil
                self?.loadingOverlayInstalledAt = nil
                self?.isHidingLoadingOverlay = false
            }
        )
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

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
        GameCenterService.shared.menuStatus
    }

    func arenaSceneRequestsClassicLeaderboard(_ scene: ArenaScene) -> GameCenterLeaderboardPresentationResult {
        let result = GameCenterService.shared.presentClassicSurvivalLeaderboard(presenter: self)
        if result == .unavailable(.authenticationRequired) {
            GameCenterService.shared.retryAuthentication(presenter: self)
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
