import Foundation
import Logging
import OSLog

struct DiagnosticJSONLLogHandler: LogHandler {
    private let label: String
    private let store: DiagnosticLogStore
    private let sessionID: String
    private let dateProvider: @Sendable () -> Date
    var metadata: Logging.Logger.Metadata = [:]
    var metadataProvider: Logging.Logger.MetadataProvider?
    var logLevel: Logging.Logger.Level

    init(
        label: String,
        store: DiagnosticLogStore = .shared,
        sessionID: String,
        logLevel: Logging.Logger.Level = .info,
        dateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.label = label
        self.store = store
        self.sessionID = sessionID
        self.logLevel = logLevel
        self.dateProvider = dateProvider
    }

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        let record = DiagnosticLogRecord(
            timestamp: dateProvider(),
            sessionID: sessionID,
            level: event.level,
            label: label,
            message: event.message,
            metadata: DiagnosticMetadataSanitizer.merged(
                base: metadata,
                provider: metadataProvider,
                explicit: event.metadata
            ),
            source: event.source,
            file: event.file,
            function: event.function,
            line: event.line
        )

        try? store.append(record)
    }
}

struct DiagnosticOSLogHandler: LogHandler {
    private let label: String
    var metadata: Logging.Logger.Metadata = [:]
    var metadataProvider: Logging.Logger.MetadataProvider?
    var logLevel: Logging.Logger.Level

    init(label: String, logLevel: Logging.Logger.Level = .debug) {
        self.label = label
        self.logLevel = logLevel
    }

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        let metadata = DiagnosticMetadataSanitizer.sanitized(
            DiagnosticMetadataSanitizer.merged(
                base: metadata,
                provider: metadataProvider,
                explicit: event.metadata
            )
        )
        let metadataText = metadata.isEmpty
            ? ""
            : " " + metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        let fileName = URL(fileURLWithPath: event.file).lastPathComponent
        let rendered = "\(event.message.description)\(metadataText) \(fileName):\(event.line)"
        let logger = DiagnosticOSLogCache.shared.log(for: label)

        os_log("%{public}@", log: logger, type: osLogType(for: event.level), rendered)
    }

    private func osLogType(for level: Logging.Logger.Level) -> OSLogType {
        switch level {
        case .trace, .debug:
            return .debug
        case .info, .notice:
            return .default
        case .warning, .error:
            return .error
        case .critical:
            return .fault
        }
    }
}

private final class DiagnosticOSLogCache: @unchecked Sendable {
    static let shared = DiagnosticOSLogCache()

    private let lock = NSLock()
    private var logs: [String: OSLog] = [:]

    func log(for label: String) -> OSLog {
        lock.lock()
        defer { lock.unlock() }

        if let log = logs[label] {
            return log
        }

        let log = OSLog(
            subsystem: AppDiagnostics.subsystem,
            category: DiagnosticLogRecord.category(from: label)
        )
        logs[label] = log
        return log
    }
}
