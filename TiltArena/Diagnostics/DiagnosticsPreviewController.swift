import QuickLook
import UIKit

/// Presents an immutable plain-text diagnostics snapshot with native Quick Look UI.
///
/// The caller owns the report's lifetime. Keep the file available until
/// `onDismiss` runs, then remove or expire it as appropriate.
@MainActor
final class DiagnosticsPreviewController: QLPreviewController {
    typealias DoneHandler = @MainActor () -> Void
    typealias ShareHandler = @MainActor (
        _ reportURL: URL,
        _ presenter: UIViewController,
        _ sourceBarButtonItem: UIBarButtonItem
    ) -> Void
    typealias DismissHandler = @MainActor () -> Void

    let reportURL: URL

    private let retainedDataSource: DiagnosticsPreviewDataSource
    private let onDone: DoneHandler
    private let onShare: ShareHandler
    private let onDismiss: DismissHandler
    private var hasNotifiedDismissal = false

    init(
        reportURL: URL,
        onDone: @escaping DoneHandler = {},
        onShare: @escaping ShareHandler,
        onDismiss: @escaping DismissHandler = {}
    ) {
        self.reportURL = reportURL
        retainedDataSource = DiagnosticsPreviewDataSource(reportURL: reportURL)
        self.onDone = onDone
        self.onShare = onShare
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)

        // QLPreviewController keeps this reference weak, so retain the data
        // source separately for the complete presentation lifetime.
        dataSource = retainedDataSource
        currentPreviewItemIndex = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("DiagnosticsPreviewController must be created with a report URL.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Diagnostic Logs"
        view.accessibilityIdentifier = "diagnostics-log-preview"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = makeDoneButton()
        navigationItem.rightBarButtonItem = makeShareButton()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let presentationWasDismissed = isBeingDismissed
            || navigationController?.isBeingDismissed == true
            || isMovingFromParent
        if presentationWasDismissed {
            notifyDismissalIfNeeded()
        }
    }

    private func makeDoneButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(handleDoneAction(_:))
        )
        button.accessibilityLabel = "Done"
        button.accessibilityHint = "Closes the diagnostic log preview."
        return button
    }

    private func makeShareButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(handleShareAction(_:))
        )
        button.accessibilityLabel = "Share Logs"
        button.accessibilityHint = "Opens the system share sheet for this diagnostic report."
        return button
    }

    @objc
    func handleDoneAction(_ sender: UIBarButtonItem) {
        onDone()

        if let navigationController,
           navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true) { [weak self] in
                self?.notifyDismissalIfNeeded()
            }
        }
    }

    @objc
    func handleShareAction(_ sender: UIBarButtonItem) {
        onShare(reportURL, self, sender)
    }

    func notifyDismissalIfNeeded() {
        guard !hasNotifiedDismissal else {
            return
        }

        hasNotifiedDismissal = true
        onDismiss()
    }
}

@MainActor
private final class DiagnosticsPreviewDataSource: NSObject, QLPreviewControllerDataSource {
    private let reportURL: URL

    init(reportURL: URL) {
        self.reportURL = reportURL
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(
        _ controller: QLPreviewController,
        previewItemAt index: Int
    ) -> any QLPreviewItem {
        reportURL as NSURL
    }
}
