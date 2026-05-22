import Foundation
import Logging

struct DiagnosticLogRecord: Codable, Equatable {
    let schemaVersion: Int
    let timestamp: String
    let sessionID: String
    let level: String
    let label: String
    let category: String
    let message: String
    let metadata: [String: String]
    let source: String
    let file: String
    let function: String
    let line: UInt

    init(
        timestamp: Date,
        sessionID: String,
        level: Logger.Level,
        label: String,
        message: Logger.Message,
        metadata: Logger.Metadata,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        schemaVersion = 1
        self.timestamp = DiagnosticDateFormatter.string(from: timestamp)
        self.sessionID = sessionID
        self.level = level.rawValue
        self.label = label
        category = DiagnosticLogRecord.category(from: label)
        self.message = message.description
        self.metadata = DiagnosticMetadataSanitizer.sanitized(metadata)
        self.source = source
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
    }

    static func category(from label: String) -> String {
        let prefix = "\(AppDiagnostics.subsystem)."
        guard label.hasPrefix(prefix) else {
            return label
        }

        return String(label.dropFirst(prefix.count))
    }
}

enum DiagnosticDateFormatter {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func fileSafeString(from date: Date) -> String {
        let milliseconds = Int((date.timeIntervalSince1970 * 1_000).rounded())
        return "\(milliseconds)"
    }
}

enum DiagnosticMetadataSanitizer {
    private static let redactedKeyFragments = [
        "email",
        "password",
        "secret",
        "token",
        "userid",
        "user_id",
        "vendor",
        "identifier"
    ]

    static func sanitized(_ metadata: Logger.Metadata) -> [String: String] {
        metadata.reduce(into: [String: String]()) { result, pair in
            let key = sanitizedKey(pair.key)
            result[key] = sanitizedValue(pair.value, redactionKey: pair.key)
        }
    }

    static func merged(
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?,
        error: (any Error)? = nil
    ) -> Logger.Metadata {
        var merged = base

        if let provided = provider?.get() {
            merged.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit {
            merged.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        if let error {
            merged["error.message"] = "\(error)"
            merged["error.type"] = "\(String(reflecting: type(of: error)))"
        }

        return merged
    }

    private static func sanitizedKey(_ key: String) -> String {
        String(key.prefix(80))
    }

    private static func sanitizedValue(_ value: Logger.Metadata.Value, redactionKey: String? = nil) -> String {
        if let redactionKey, shouldRedact(key: redactionKey) {
            return "<redacted>"
        }

        let rendered: String

        switch value {
        case let .string(string):
            rendered = string
        case let .stringConvertible(value):
            rendered = value.description
        case let .array(values):
            rendered = values.map { sanitizedValue($0) }.joined(separator: ",")
        case let .dictionary(dictionary):
            rendered = dictionary
                .map { pair in
                    let key = sanitizedKey(pair.key)
                    return "\(key)=\(sanitizedValue(pair.value, redactionKey: pair.key))"
                }
                .sorted()
                .joined(separator: ",")
        }

        return String(rendered.prefix(240))
    }

    private static func shouldRedact(key: String) -> Bool {
        let lowercasedKey = key.lowercased()
        return redactedKeyFragments.contains { lowercasedKey.contains($0) }
    }
}
