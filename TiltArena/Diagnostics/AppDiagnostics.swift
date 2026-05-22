import Foundation
import Logging

@MainActor
enum AppDiagnostics {
    nonisolated static let subsystem = "com.xlc.TiltArena"
    private static let sessionID = UUID().uuidString
    private static var isBootstrapped = false

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

        logger(.app).notice("app.launch", metadata: [
            "sessionID": "\(currentSessionID)"
        ])
    }

    static func logger(_ category: DiagnosticCategory) -> Logger {
        Logger(label: "\(subsystem).\(category.rawValue)")
    }

    static func makeExportBundle(gameplay: DiagnosticGameplaySnapshot?) throws -> URL {
        let generatedAt = Date()
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: generatedAt,
            sessionID: sessionID,
            gameplay: gameplay
        )
        let builder = DiagnosticBundleBuilder(
            outputDirectoryURL: exportDirectoryURL()
        )
        return try builder.makeBundle(metadata: metadata)
    }

    private static func exportDirectoryURL() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DiagnosticsExports", isDirectory: true)
    }
}

enum DiagnosticCategory: String {
    case app
    case scene
    case input
    case run
    case spawn
    case weapon
    case profile
    case performance
}
