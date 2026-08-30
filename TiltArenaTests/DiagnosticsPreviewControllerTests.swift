import QuickLook
import UIKit
import XCTest
@testable import TiltArena

@MainActor
final class DiagnosticsPreviewControllerTests: XCTestCase {
    func testRetainsOnePlainTextPreviewItem() throws {
        let reportURL = try makeReportURL()
        let controller = DiagnosticsPreviewController(
            reportURL: reportURL,
            onShare: { _, _, _ in }
        )

        let dataSource = try XCTUnwrap(controller.dataSource)

        XCTAssertEqual(dataSource.numberOfPreviewItems(in: controller), 1)
        let item = dataSource.previewController(controller, previewItemAt: 0)
        XCTAssertEqual(item.previewItemURL, reportURL)
    }

    func testInstallsAccessibleDoneAndShareActions() throws {
        let controller = DiagnosticsPreviewController(
            reportURL: try makeReportURL(),
            onShare: { _, _, _ in }
        )

        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.view.accessibilityIdentifier, "diagnostics-log-preview")
        XCTAssertEqual(controller.navigationItem.leftBarButtonItem?.accessibilityLabel, "Done")
        XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.accessibilityLabel, "Share Logs")
    }

    func testShareActionReturnsReportPresenterAndPopoverSource() throws {
        let reportURL = try makeReportURL()
        var sharedURL: URL?
        weak var sharedPresenter: UIViewController?
        weak var sharedSource: UIBarButtonItem?
        let controller = DiagnosticsPreviewController(
            reportURL: reportURL,
            onShare: { url, presenter, source in
                sharedURL = url
                sharedPresenter = presenter
                sharedSource = source
            }
        )
        controller.loadViewIfNeeded()
        let shareButton = try XCTUnwrap(controller.navigationItem.rightBarButtonItem)

        controller.handleShareAction(shareButton)

        XCTAssertEqual(sharedURL, reportURL)
        XCTAssertTrue(sharedPresenter === controller)
        XCTAssertTrue(sharedSource === shareButton)
    }

    func testDoneActionNotifiesCallerBeforeRequestingDismissal() throws {
        var doneCallCount = 0
        let controller = DiagnosticsPreviewController(
            reportURL: try makeReportURL(),
            onDone: {
                doneCallCount += 1
            },
            onShare: { _, _, _ in }
        )
        controller.loadViewIfNeeded()
        let doneButton = try XCTUnwrap(controller.navigationItem.leftBarButtonItem)

        controller.handleDoneAction(doneButton)

        XCTAssertEqual(doneCallCount, 1)
    }

    func testDismissalCallbackRunsOnlyOnce() throws {
        var dismissalCallCount = 0
        let controller = DiagnosticsPreviewController(
            reportURL: try makeReportURL(),
            onShare: { _, _, _ in },
            onDismiss: {
                dismissalCallCount += 1
            }
        )

        controller.notifyDismissalIfNeeded()
        controller.notifyDismissalIfNeeded()

        XCTAssertEqual(dismissalCallCount, 1)
    }

    private func makeReportURL() throws -> URL {
        let reportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiltArenaDiagnostics-\(UUID().uuidString).txt")
        try "diagnostic test record\n".write(to: reportURL, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: reportURL)
        }
        return reportURL
    }
}
