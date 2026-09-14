import Foundation

struct DiagnosticGameplaySnapshot: Codable, Equatable, Sendable {
    let uiState: String
    let selectedMode: String
    let runPhase: String
    let score: Int
    let survivalTime: TimeInterval
    let enemyCount: Int
    let pickupCount: Int
    let localOptions: DiagnosticLocalOptionsSnapshot
    let profile: DiagnosticProfileSnapshot
}

struct DiagnosticLocalOptionsSnapshot: Codable, Equatable, Sendable {
    let audioEnabled: Bool
    let hapticsEnabled: Bool
    let theme: String
}

struct DiagnosticProfileSnapshot: Codable, Equatable, Sendable {
    let bestScore: Int
    let highestCombo: Int
    let longestSurvivalTime: TimeInterval
    let totalRuns: Int
    let totalEnemiesDestroyed: Int
    let unlockedWeaponCount: Int
    let earnedAwardCount: Int
}

struct DiagnosticExportMetadata: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let sessionID: String
    let app: DiagnosticAppMetadata
    let device: DiagnosticDeviceMetadata
    let gameplay: DiagnosticGameplaySnapshot?
}

struct DiagnosticAppMetadata: Codable, Equatable, Sendable {
    let bundleID: String
    let version: String
    let build: String
}

struct DiagnosticDeviceMetadata: Codable, Equatable, Sendable {
    let osName: String
    let osVersion: String
    let localeIdentifier: String
}

enum DiagnosticExportMetadataFactory {
    static let currentSchemaVersion = 4

    static func make(
        generatedAt: Date,
        sessionID: String,
        gameplay: DiagnosticGameplaySnapshot?,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        locale: Locale = .autoupdatingCurrent
    ) -> DiagnosticExportMetadata {
        DiagnosticExportMetadata(
            schemaVersion: currentSchemaVersion,
            generatedAt: DiagnosticDateFormatter.string(from: generatedAt),
            sessionID: sessionID,
            app: DiagnosticAppMetadata(
                bundleID: bundle.bundleIdentifier ?? "unknown",
                version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
            ),
            device: DiagnosticDeviceMetadata(
                osName: "iOS",
                osVersion: processInfo.operatingSystemVersionString,
                localeIdentifier: locale.identifier
            ),
            gameplay: gameplay
        )
    }
}

struct DiagnosticReportHealth: Codable, Equatable, Sendable {
    let logFileCount: Int
    let logBytesRead: Int
    let logRecordCount: Int
    let malformedLogLineCount: Int
    let truncatedLogLineCount: Int
    let unreadableLogFileCount: Int
    let didReachLogRecordLimit: Bool
    let didReachLogByteLimit: Bool
    let systemReportFileCount: Int
    let systemReportBytes: Int
    let unreadableSystemReportCount: Int
    let persistence: DiagnosticLogHealthSnapshot
}

struct DiagnosticTextReportBuilder {
    struct Configuration: Equatable, Sendable {
        var maxReportCount: Int
        var maxTotalBytes: Int

        static let production = Configuration(
            maxReportCount: 3,
            maxTotalBytes: 32 * 1_024 * 1_024
        )
    }

    enum ReportError: Error, Equatable {
        case invalidConfiguration
        case reportTooLarge(actualBytes: Int, maximumBytes: Int)
        case destinationAlreadyExists
    }

    private struct IndexedRecord {
        let record: DiagnosticLogRecord
        let sourceOrder: Int
    }

    let logStore: DiagnosticLogStore
    let systemReportStore: DiagnosticSystemReportStore
    let outputDirectoryURL: URL
    let configuration: Configuration
    let fileManager: FileManager
    let dateProvider: @Sendable () -> Date
    let uuidProvider: @Sendable () -> UUID

    init(
        logStore: DiagnosticLogStore = .shared,
        systemReportStore: DiagnosticSystemReportStore = .shared,
        outputDirectoryURL: URL,
        configuration: Configuration = .production,
        fileManager: FileManager = .default,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        uuidProvider: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.logStore = logStore
        self.systemReportStore = systemReportStore
        self.outputDirectoryURL = outputDirectoryURL
        self.configuration = configuration
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
    }

    func makeReport(metadata: DiagnosticExportMetadata) throws -> URL {
        try DiagnosticTextReportLock.shared.withLock {
            try makeReportLocked(metadata: metadata)
        }
    }

    private func makeReportLocked(metadata: DiagnosticExportMetadata) throws -> URL {
        guard configuration.maxReportCount > 0, configuration.maxTotalBytes > 0 else {
            throw ReportError.invalidConfiguration
        }

        try prepareOutputDirectoryLocked()

        let identifier = uuidProvider()
        let reportData = try makeReportData(metadata: metadata)
        guard reportData.count <= configuration.maxTotalBytes else {
            throw ReportError.reportTooLarge(
                actualBytes: reportData.count,
                maximumBytes: configuration.maxTotalBytes
            )
        }

        let reportURL = generatedReportURL(identifier: identifier)
        guard !fileManager.fileExists(atPath: reportURL.path) else {
            throw ReportError.destinationAlreadyExists
        }

        do {
            try reportData.write(to: reportURL, options: [.atomic])
            try pruneGeneratedReportsLocked(preserving: reportURL)
            guard fileManager.fileExists(atPath: reportURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return reportURL
        } catch {
            try? fileManager.removeItem(at: reportURL)
            throw error
        }
    }

    private func prepareOutputDirectoryLocked() throws {
        try fileManager.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )
        removeStaleLogSnapshotsLocked()
    }

    private func removeStaleLogSnapshotsLocked() {
        guard let itemURLs = try? fileManager.contentsOfDirectory(
            at: outputDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return
        }

        for itemURL in itemURLs where itemURL.lastPathComponent.hasPrefix(".log-snapshot-") {
            try? fileManager.removeItem(at: itemURL)
        }
    }

    private func makeReportData(metadata: DiagnosticExportMetadata) throws -> Data {
        let logRead = logStore.readNewest(configuration: .report)
        let records = chronologicalRecords(fromNewestFirst: logRead.records)
        let systemReports = try systemReportStore.snapshot()
        let health = makeHealth(
            logRead: logRead,
            recordCount: records.count,
            systemReports: systemReports
        )
        return try renderReport(
            metadata: metadata,
            health: health,
            records: records,
            systemReports: systemReports.reports
        )
    }

    private func chronologicalRecords(
        fromNewestFirst records: [DiagnosticLogRecord]
    ) -> [DiagnosticLogRecord] {
        records.enumerated().map { index, record in
            IndexedRecord(record: record, sourceOrder: index)
        }.sorted { lhs, rhs in
            if lhs.record.timestamp == rhs.record.timestamp {
                return lhs.sourceOrder > rhs.sourceOrder
            }
            return lhs.record.timestamp < rhs.record.timestamp
        }.map(\.record)
    }

    private func makeHealth(
        logRead: DiagnosticLogReadResult,
        recordCount: Int,
        systemReports: DiagnosticSystemReportSnapshot
    ) -> DiagnosticReportHealth {
        DiagnosticReportHealth(
            logFileCount: logRead.fileCount,
            logBytesRead: logRead.bytesRead,
            logRecordCount: recordCount,
            malformedLogLineCount: logRead.malformedLineCount,
            truncatedLogLineCount: logRead.truncatedLineCount,
            unreadableLogFileCount: logRead.unreadableFileCount,
            didReachLogRecordLimit: logRead.didReachRecordLimit,
            didReachLogByteLimit: logRead.didReachByteLimit,
            systemReportFileCount: systemReports.reports.count,
            systemReportBytes: systemReports.totalBytes,
            unreadableSystemReportCount: systemReports.unreadableReportCount,
            persistence: logStore.healthSnapshot
        )
    }

    private func generatedReportURL(identifier: UUID) -> URL {
        outputDirectoryURL.appendingPathComponent(
            "TiltArenaDiagnostics-\(DiagnosticDateFormatter.fileSafeString(from: dateProvider()))-\(identifier.uuidString).txt",
            isDirectory: false
        )
    }

    private func renderReport(
        metadata: DiagnosticExportMetadata,
        health: DiagnosticReportHealth,
        records: [DiagnosticLogRecord],
        systemReports: [DiagnosticSystemReportSnapshot.Report]
    ) throws -> Data {
        let prettyEncoder = JSONEncoder()
        prettyEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let lineEncoder = JSONEncoder()
        lineEncoder.outputFormatting = [.sortedKeys]

        var result = Data()
        append("TILT ARENA DIAGNOSTIC REPORT\n", to: &result)
        append("This file may contain gameplay state and technical crash diagnostics.\n\n", to: &result)

        append("[METADATA JSON]\n", to: &result)
        result.append(try prettyEncoder.encode(metadata))
        append("\n\n[HEALTH JSON]\n", to: &result)
        result.append(try prettyEncoder.encode(health))
        append("\n\n[LOG RECORDS JSONL]\n", to: &result)
        for record in records {
            result.append(try lineEncoder.encode(record))
            result.append(0x0A)
        }

        append("\n[SYSTEM REPORT JSON]\n", to: &result)
        if systemReports.isEmpty {
            append("No stored MetricKit diagnostic payloads.\n", to: &result)
        } else {
            for (index, report) in systemReports.enumerated() {
                append("--- SYSTEM REPORT \(index + 1): \(report.fileName) ---\n", to: &result)
                result.append(report.jsonData)
                if report.jsonData.last != 0x0A {
                    result.append(0x0A)
                }
            }
        }

        return result
    }

    private func append(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private func generatedReportURLsLocked() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: outputDirectoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.lastPathComponent.hasPrefix("TiltArenaDiagnostics-")
                && $0.pathExtension == "txt"
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func pruneGeneratedReportsLocked(preserving currentReportURL: URL) throws {
        var reportURLs = try generatedReportURLsLocked()
        while reportURLs.count > configuration.maxReportCount {
            let removalIndex = reportURLs.firstIndex { $0 != currentReportURL }
            guard let removalIndex else {
                break
            }
            try fileManager.removeItem(at: reportURLs.remove(at: removalIndex))
        }

        var sizedReports = try reportURLs.map { url in
            (url: url, bytes: try fileSize(url))
        }
        var totalBytes = sizedReports.reduce(0) { $0 + $1.bytes }
        while totalBytes > configuration.maxTotalBytes, !sizedReports.isEmpty {
            let removalIndex = sizedReports.firstIndex { $0.url != currentReportURL }
            guard let removalIndex else {
                break
            }
            let oldest = sizedReports.remove(at: removalIndex)
            try fileManager.removeItem(at: oldest.url)
            totalBytes -= oldest.bytes
        }
    }

    private func fileSize(_ url: URL) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }
}

private final class DiagnosticTextReportLock: @unchecked Sendable {
    static let shared = DiagnosticTextReportLock()

    private let lock = NSLock()

    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
