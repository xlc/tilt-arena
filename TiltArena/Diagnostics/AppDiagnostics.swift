import Foundation
import Logging

@MainActor
enum AppDiagnostics {
    nonisolated static let subsystem = "com.xlc.TiltArena"
    nonisolated private static let sessionID = UUID().uuidString
    private static var isBootstrapped = false
    private static var metricKitCollector: MetricKitDiagnosticCollector?

    static func bootstrap(store: DiagnosticLogStore = .shared) {
        guard !isBootstrapped else {
            return
        }

        let currentSessionID = sessionID
        LoggingSystem.bootstrap { label in
            MultiplexLogHandler([
                DiagnosticOSLogHandler(label: label),
                DiagnosticJSONLLogHandler(
                    label: label,
                    store: store,
                    sessionID: currentSessionID
                )
            ])
        }
        isBootstrapped = true

        let collector = MetricKitDiagnosticCollector()
        metricKitCollector = collector
        collector.start()

        logger(.app).notice("app.launch")
    }

    nonisolated static func logger(_ category: DiagnosticCategory) -> Logger {
        Logger(label: "\(subsystem).\(category.rawValue)")
    }

    nonisolated static func makeReport(gameplay: DiagnosticGameplaySnapshot?) throws -> URL {
        let generatedAt = Date()
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: generatedAt,
            sessionID: sessionID,
            gameplay: gameplay
        )
        let builder = DiagnosticTextReportBuilder(
            outputDirectoryURL: exportDirectoryURL()
        )
        return try builder.makeReport(metadata: metadata)
    }

    nonisolated private static func exportDirectoryURL() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DiagnosticsExports", isDirectory: true)
    }
}

enum DiagnosticCategory: String {
    case app
    case diagnostics
    case scene
    case input
    case run
    case spawn
    case weapon
    case profile
    case performance
    case gameCenter = "game_center"
}
