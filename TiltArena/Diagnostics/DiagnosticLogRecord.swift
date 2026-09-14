import Foundation
import Logging

enum DiagnosticLogLimits {
    static let maxEncodedLineBytes = 16 * 1_024
    static let maxMessageLength = 512
    static let maxMetadataEntries = 24
    static let maxMetadataKeyLength = 80
    static let maxMetadataValueLength = 240
    static let maxMetadataCollectionValues = 16
    static let maxMetadataDepth = 2
    static let maxSessionIDLength = 80
    static let maxLabelLength = 160
    static let maxSourceLength = 120
    static let maxFileLength = 120
    static let maxFunctionLength = 160

    /// Bounds persisted strings by UTF-8 bytes rather than grapheme count.
    /// A single Swift `Character` can contain an unbounded number of Unicode
    /// scalars, so `prefix(_:)` is not a storage or memory bound.
    static func bounded(_ value: String, to limit: Int) -> String {
        guard limit > 0 else {
            return ""
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(min(limit, 512))
        for scalar in value.unicodeScalars {
            let scalarBytes = String(scalar).utf8
            guard scalarBytes.count <= limit - bytes.count else {
                break
            }
            bytes.append(contentsOf: scalarBytes)
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}

struct DiagnosticLogRecord: Codable, Equatable, Sendable {
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
        self.sessionID = DiagnosticLogLimits.bounded(
            sessionID,
            to: DiagnosticLogLimits.maxSessionIDLength
        )
        self.level = level.rawValue
        let boundedLabel = DiagnosticLogLimits.bounded(label, to: DiagnosticLogLimits.maxLabelLength)
        self.label = boundedLabel
        category = DiagnosticLogRecord.category(from: boundedLabel)
        self.message = DiagnosticLogLimits.bounded(
            message.description,
            to: DiagnosticLogLimits.maxMessageLength
        )
        self.metadata = DiagnosticMetadataFormatter.bounded(metadata)
        self.source = DiagnosticLogLimits.bounded(source, to: DiagnosticLogLimits.maxSourceLength)
        self.file = DiagnosticLogLimits.bounded(
            URL(fileURLWithPath: file).lastPathComponent,
            to: DiagnosticLogLimits.maxFileLength
        )
        self.function = DiagnosticLogLimits.bounded(function, to: DiagnosticLogLimits.maxFunctionLength)
        self.line = line
    }

    static func persistenceDegraded(
        timestamp: Date,
        sessionID: String,
        queueDropCount: UInt64,
        writeFailureCount: UInt64
    ) -> DiagnosticLogRecord {
        DiagnosticLogRecord(
            timestamp: timestamp,
            sessionID: sessionID,
            level: .warning,
            label: "\(AppDiagnostics.subsystem).diagnostics",
            message: "diagnostics.persistence_degraded",
            metadata: [
                "queue_drop_count": "\(queueDropCount)",
                "write_failure_count": "\(writeFailureCount)"
            ],
            source: "TiltArena",
            file: "DiagnosticLogStore.swift",
            function: "append(_:)",
            line: 0
        )
    }

    static func category(from label: String) -> String {
        let prefix = "\(AppDiagnostics.subsystem)."
        guard label.hasPrefix(prefix) else {
            return label
        }

        return String(label.dropFirst(prefix.count))
    }

    func replacingMetadata(_ metadata: [String: String]) -> DiagnosticLogRecord {
        DiagnosticLogRecord(
            schemaVersion: schemaVersion,
            timestamp: timestamp,
            sessionID: sessionID,
            level: level,
            label: label,
            category: category,
            message: message,
            metadata: metadata,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }

    private init(
        schemaVersion: Int,
        timestamp: String,
        sessionID: String,
        level: String,
        label: String,
        category: String,
        message: String,
        metadata: [String: String],
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.schemaVersion = schemaVersion
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.level = level
        self.label = label
        self.category = category
        self.message = message
        self.metadata = metadata
        self.source = source
        self.file = file
        self.function = function
        self.line = line
    }
}

enum DiagnosticDateFormatter {
    private static let cache = DiagnosticISO8601FormatterCache()

    static func string(from date: Date) -> String {
        guard date.timeIntervalSince1970.isFinite else {
            return "invalid-date"
        }

        return cache.string(from: date)
    }

    static func fileSafeString(from date: Date) -> String {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else {
            return "invalid-date"
        }

        return String(format: "%.0f", milliseconds.rounded())
    }
}

private final class DiagnosticISO8601FormatterCache: @unchecked Sendable {
    private let lock = NSLock()
    private let formatter: ISO8601DateFormatter

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.formatter = formatter
    }

    func string(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: date)
    }
}

enum DiagnosticMetadataFormatter {
    static let errorKeys: Set<String> = [
        "error.code", "error.domain", "error.type", "error.description", "error.message"
    ]

    static func bounded(_ metadata: Logger.Metadata) -> [String: String] {
        var result: [String: String] = [:]
        let sortedPairs = metadata.sorted { lhs, rhs in
            let lhsIsTypedError = errorKeys.contains(lhs.key.lowercased())
            let rhsIsTypedError = errorKeys.contains(rhs.key.lowercased())
            if lhsIsTypedError != rhsIsTypedError {
                return lhsIsTypedError
            }
            return lhs.key < rhs.key
        }

        for pair in sortedPairs.prefix(DiagnosticLogLimits.maxMetadataEntries) {
            let key = boundedKey(pair.key)
            result[key] = boundedValue(pair.value, depth: 0)
        }

        return result
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
            let nsError = error as NSError
            merged["error.type"] = "\(String(reflecting: type(of: error)))"
            merged["error.domain"] = "\(nsError.domain)"
            merged["error.code"] = "\(nsError.code)"
            merged["error.description"] = "\(error)"
            merged["error.message"] = "\(error.localizedDescription)"
        }

        return merged
    }

    private static func boundedKey(_ key: String) -> String {
        DiagnosticLogLimits.bounded(key, to: DiagnosticLogLimits.maxMetadataKeyLength)
    }

    private static func boundedValue(
        _ value: Logger.Metadata.Value,
        depth: Int
    ) -> String {
        let rendered: String

        switch value {
        case let .string(string):
            rendered = string
        case let .stringConvertible(value):
            rendered = value.description
        case let .array(values):
            guard depth < DiagnosticLogLimits.maxMetadataDepth else {
                return "<max-depth>"
            }

            var renderedValues = values
                .prefix(DiagnosticLogLimits.maxMetadataCollectionValues)
                .map { boundedValue($0, depth: depth + 1) }
            if values.count > DiagnosticLogLimits.maxMetadataCollectionValues {
                renderedValues.append("<truncated>")
            }
            rendered = renderedValues.joined(separator: ",")
        case let .dictionary(dictionary):
            guard depth < DiagnosticLogLimits.maxMetadataDepth else {
                return "<max-depth>"
            }

            let sortedPairs = dictionary.sorted { $0.key < $1.key }
            var renderedValues = sortedPairs
                .prefix(DiagnosticLogLimits.maxMetadataCollectionValues)
                .map { pair in
                    let key = boundedKey(pair.key)
                    let value = boundedValue(
                        pair.value,
                        depth: depth + 1
                    )
                    return "\(key)=\(value)"
                }
            if dictionary.count > DiagnosticLogLimits.maxMetadataCollectionValues {
                renderedValues.append("<truncated>")
            }
            rendered = renderedValues.joined(separator: ",")
        }

        return DiagnosticLogLimits.bounded(
            rendered,
            to: DiagnosticLogLimits.maxMetadataValueLength
        )
    }
}
