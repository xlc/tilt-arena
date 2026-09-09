import Foundation
import Logging
import XCTest
@testable import TiltArena

final class DiagnosticSystemReportStoreTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DiagnosticSystemReportStoreTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        try super.tearDownWithError()
    }

    func testStorePrunesOldestReportsByCount() throws {
        let uuidSequence = LockedUUIDSequence()
        let store = makeSystemStore(
            configuration: .init(maxReportCount: 2, maxTotalBytes: 10_000),
            uuidProvider: uuidSequence.next
        )
        let firstData = Data(#"{"period":1}"#.utf8)
        let secondData = Data(#"{"period":2}"#.utf8)
        let thirdData = Data(#"{"period":3}"#.utf8)

        let firstURL = try store.persist(
            payloadJSON: firstData,
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )
        try store.persist(
            payloadJSON: secondData,
            periodStart: Date(timeIntervalSince1970: 2),
            periodEnd: Date(timeIntervalSince1970: 3)
        )
        try store.persist(
            payloadJSON: thirdData,
            periodStart: Date(timeIntervalSince1970: 3),
            periodEnd: Date(timeIntervalSince1970: 4)
        )

        let snapshot = try store.snapshot()
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertEqual(snapshot.reports.map(\.jsonData), [secondData, thirdData])
        XCTAssertEqual(snapshot.totalBytes, secondData.count + thirdData.count)
        XCTAssertEqual(snapshot.unreadableReportCount, 0)
    }

    func testStorePrunesByTotalBytesAndRejectsOversizedPayload() throws {
        let payload = Data(#"{"id":1}"#.utf8)
        let store = makeSystemStore(
            configuration: .init(
                maxReportCount: 10,
                maxTotalBytes: payload.count * 2
            )
        )

        for index in 0..<3 {
            try store.persist(
                payloadJSON: payload,
                periodStart: Date(timeIntervalSince1970: TimeInterval(index)),
                periodEnd: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }

        let snapshot = try store.snapshot()
        XCTAssertEqual(snapshot.reports.count, 2)
        XCTAssertLessThanOrEqual(snapshot.totalBytes, store.configuration.maxTotalBytes)

        let oversized = Data(repeating: 0x78, count: store.configuration.maxTotalBytes + 1)
        XCTAssertThrowsError(
            try store.persist(
                payloadJSON: oversized,
                periodStart: .distantPast,
                periodEnd: .distantFuture
            )
        ) { error in
            XCTAssertEqual(
                error as? DiagnosticSystemReportStore.StoreError,
                .payloadTooLarge(
                    actualBytes: oversized.count,
                    maximumBytes: store.configuration.maxTotalBytes
                )
            )
        }
    }

    func testStoreDeduplicatesRepeatedMetricKitPayload() throws {
        let store = makeSystemStore()
        let payload = Data(#"{"crashDiagnostics":[{"id":1}]}"#.utf8)

        let firstURL = try store.persist(
            payloadJSON: payload,
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )
        let duplicateURL = try store.persist(
            payloadJSON: payload,
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )

        XCTAssertEqual(duplicateURL, firstURL)
        XCTAssertEqual(try store.snapshot().reports.map(\.jsonData), [payload])
    }

    func testStoreRefusesNewReportWhenRequiredDeletionFails() throws {
        let configuration = DiagnosticSystemReportStore.Configuration(
            maxReportCount: 1,
            maxTotalBytes: 10_000
        )
        let originalStore = makeSystemStore(configuration: configuration)
        let originalPayload = Data(#"{"period":1}"#.utf8)
        let originalURL = try originalStore.persist(
            payloadJSON: originalPayload,
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )
        let failingFileManager = FaultInjectingFileManager(
            shouldFailRemoval: { $0 == originalURL }
        )
        let strictStore = makeSystemStore(
            configuration: configuration,
            fileManager: failingFileManager
        )

        XCTAssertThrowsError(
            try strictStore.persist(
                payloadJSON: Data(#"{"period":2}"#.utf8),
                periodStart: Date(timeIntervalSince1970: 2),
                periodEnd: Date(timeIntervalSince1970: 3)
            )
        ) { error in
            XCTAssertEqual(
                error as? DiagnosticSystemReportStore.StoreError,
                .quotaUnavailable
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertEqual(try reportFileURLs().count, 1)
    }

    func testStoreRefusesNewReportWhenExistingSizeCannotBeInspected() throws {
        let configuration = DiagnosticSystemReportStore.Configuration(
            maxReportCount: 2,
            maxTotalBytes: 10_000
        )
        let originalStore = makeSystemStore(configuration: configuration)
        let originalURL = try originalStore.persist(
            payloadJSON: Data(#"{"period":1}"#.utf8),
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )
        let failingFileManager = FaultInjectingFileManager(
            shouldFailAttributes: { $0 == originalURL.path }
        )
        let strictStore = makeSystemStore(
            configuration: configuration,
            fileManager: failingFileManager
        )

        XCTAssertThrowsError(
            try strictStore.persist(
                payloadJSON: Data(#"{"period":2}"#.utf8),
                periodStart: Date(timeIntervalSince1970: 2),
                periodEnd: Date(timeIntervalSince1970: 3)
            )
        ) { error in
            XCTAssertEqual(
                error as? DiagnosticSystemReportStore.StoreError,
                .quotaUnavailable
            )
        }

        XCTAssertEqual(try reportFileURLs().count, 1)
    }

    func testBestEffortPruneKeepsFailedDeletionInQuotaAccounting() throws {
        let initialStore = makeSystemStore(
            configuration: .init(maxReportCount: 2, maxTotalBytes: 10_000)
        )
        let firstURL = try initialStore.persist(
            payloadJSON: Data(#"{"period":1}"#.utf8),
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )
        let secondURL = try initialStore.persist(
            payloadJSON: Data(#"{"period":2}"#.utf8),
            periodStart: Date(timeIntervalSince1970: 2),
            periodEnd: Date(timeIntervalSince1970: 3)
        )
        let failingFileManager = FaultInjectingFileManager(
            shouldFailRemoval: { $0 == firstURL }
        )
        let pruningStore = makeSystemStore(
            configuration: .init(maxReportCount: 1, maxTotalBytes: 10_000),
            fileManager: failingFileManager
        )

        _ = try pruningStore.snapshot()

        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertEqual(try reportFileURLs(), [firstURL])
    }

    func testBytePrunePreservesReadableReportsUntilUnknownSizeCanBeRemoved() throws {
        let originalStore = makeSystemStore()
        let readablePayload = Data(#"{"period":1}"#.utf8)
        let readableURL = try originalStore.persist(
            payloadJSON: readablePayload,
            periodStart: Date(timeIntervalSince1970: 1),
            periodEnd: Date(timeIntervalSince1970: 2)
        )
        let unknownSizeURL = try originalStore.persist(
            payloadJSON: Data(#"{"period":2}"#.utf8),
            periodStart: Date(timeIntervalSince1970: 2),
            periodEnd: Date(timeIntervalSince1970: 3)
        )
        let configuration = DiagnosticSystemReportStore.Configuration(maxReportCount: 2, maxTotalBytes: readablePayload.count)
        let blockedStore = makeSystemStore(
            configuration: configuration,
            fileManager: FaultInjectingFileManager(
                shouldFailRemoval: { $0 == unknownSizeURL },
                shouldFailAttributes: { $0 == unknownSizeURL.path }
            )
        )

        let blockedSnapshot = try blockedStore.snapshot()
        XCTAssertEqual(try reportFileURLs(), [readableURL, unknownSizeURL])
        XCTAssertEqual(blockedSnapshot.reports.map(\.jsonData), [readablePayload])
        XCTAssertGreaterThanOrEqual(blockedSnapshot.unreadableReportCount, 2)

        let recoveredStore = makeSystemStore(
            configuration: configuration,
            fileManager: FaultInjectingFileManager(
                shouldFailAttributes: { $0 == unknownSizeURL.path }
            )
        )
        let recoveredSnapshot = try recoveredStore.snapshot()

        XCTAssertEqual(try reportFileURLs(), [readableURL])
        XCTAssertEqual(recoveredSnapshot.reports.map(\.jsonData), [readablePayload])
        XCTAssertEqual(recoveredSnapshot.totalBytes, readablePayload.count)
    }

    func testFlatReportContainsChronologicalJSONLHealthAndRawSystemReport() throws {
        let logStore = DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("logs", isDirectory: true),
            configuration: .init(
                maxCurrentFileBytes: 64 * 1_024,
                maxArchivedFileCount: 2,
                maxTotalBytes: 128 * 1_024
            )
        )
        try logStore.append(record(at: 2, message: "run.second"))
        try logStore.append(record(at: 1, message: "run.first"))
        let handle = try FileHandle(forWritingTo: logStore.currentLogFileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("not-json\n".utf8))
        try handle.close()

        let systemStore = makeSystemStore()
        let rawSystemReport = Data(#"{"crashDiagnostics":[{"fixture":"crash"}]}"#.utf8)
        try systemStore.persist(
            payloadJSON: rawSystemReport,
            periodStart: Date(timeIntervalSince1970: 3),
            periodEnd: Date(timeIntervalSince1970: 4)
        )

        let outputURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let builder = DiagnosticTextReportBuilder(
            logStore: logStore,
            systemReportStore: systemStore,
            outputDirectoryURL: outputURL,
            configuration: .init(maxReportCount: 2, maxTotalBytes: 1_024 * 1_024),
            dateProvider: { Date(timeIntervalSince1970: 10) },
            uuidProvider: {
                UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
            }
        )
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 5),
            sessionID: "test-session",
            gameplay: nil
        )

        let reportURL = try builder.makeReport(metadata: metadata)
        let report = try String(contentsOf: reportURL, encoding: .utf8)

        try assertReportSections(
            report,
            reportURL: reportURL,
            rawSystemReport: rawSystemReport
        )

        let firstRange = try XCTUnwrap(report.range(of: "run.first"))
        let secondRange = try XCTUnwrap(report.range(of: "run.second"))
        XCTAssertLessThan(firstRange.lowerBound, secondRange.lowerBound)

        try assertOneReportAndNoSnapshots(in: outputURL)
    }

    func testFlatReportPrunesOlderExports() throws {
        let logStore = DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("logs", isDirectory: true),
            configuration: .init()
        )
        let systemStore = makeSystemStore()
        let dateSequence = LockedDateSequence()
        let uuidSequence = LockedUUIDSequence()
        let outputURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let builder = DiagnosticTextReportBuilder(
            logStore: logStore,
            systemReportStore: systemStore,
            outputDirectoryURL: outputURL,
            configuration: .init(maxReportCount: 2, maxTotalBytes: 1_024 * 1_024),
            dateProvider: dateSequence.next,
            uuidProvider: uuidSequence.next
        )
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 1),
            sessionID: "test-session",
            gameplay: nil
        )

        let firstURL = try builder.makeReport(metadata: metadata)
        _ = try builder.makeReport(metadata: metadata)
        _ = try builder.makeReport(metadata: metadata)

        let reportURLs = try FileManager.default.contentsOfDirectory(
            at: outputURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "txt" }
        XCTAssertEqual(reportURLs.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
    }

    func testFlatReportPreservesNewReportWhenClockMovesBackward() throws {
        let logStore = DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("logs", isDirectory: true),
            configuration: .init()
        )
        let systemStore = makeSystemStore()
        let outputURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 1),
            sessionID: "test-session",
            gameplay: nil
        )
        let firstBuilder = DiagnosticTextReportBuilder(
            logStore: logStore,
            systemReportStore: systemStore,
            outputDirectoryURL: outputURL,
            configuration: .init(maxReportCount: 1, maxTotalBytes: 1_024 * 1_024),
            dateProvider: { Date(timeIntervalSince1970: 10) },
            uuidProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000200")! }
        )
        let rollbackBuilder = DiagnosticTextReportBuilder(
            logStore: logStore,
            systemReportStore: systemStore,
            outputDirectoryURL: outputURL,
            configuration: .init(maxReportCount: 1, maxTotalBytes: 1_024 * 1_024),
            dateProvider: { Date(timeIntervalSince1970: 5) },
            uuidProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000201")! }
        )

        let firstURL = try firstBuilder.makeReport(metadata: metadata)
        let rollbackURL = try rollbackBuilder.makeReport(metadata: metadata)

        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rollbackURL.path))
    }

    func testSnapshotToleratesUnreadableReportEntry() throws {
        let store = makeSystemStore()
        try FileManager.default.createDirectory(
            at: store.directoryURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: store.directoryURL.appendingPathComponent(
                "metric-diagnostics-00000000000000000001-unreadable.json",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )

        let snapshot = try store.snapshot()

        XCTAssertTrue(snapshot.reports.isEmpty)
        XCTAssertGreaterThanOrEqual(snapshot.unreadableReportCount, 1)
        XCTAssertEqual(snapshot.totalBytes, 0)
    }

    func testFlatReportBoundsOversizedCorruptLogAndCleansStaleSnapshot() throws {
        let logStore = DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("logs", isDirectory: true),
            configuration: .production
        )
        try FileManager.default.createDirectory(at: logStore.directoryURL, withIntermediateDirectories: true)
        let oversizedLogURL = logStore.directoryURL.appendingPathComponent("diagnostics-999-corrupt.jsonl")
        try Data(repeating: 0x78, count: 4 * 1_024 * 1_024).write(to: oversizedLogURL)

        let outputURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let staleSnapshotURL = outputURL.appendingPathComponent(".log-snapshot-stale", isDirectory: true)
        try FileManager.default.createDirectory(at: staleSnapshotURL, withIntermediateDirectories: true)
        let builder = makeReportBuilder(logStore: logStore, outputURL: outputURL)

        let reportURL = try builder.makeReport(metadata: makeMetadata())
        let report = try String(contentsOf: reportURL, encoding: .utf8)

        XCTAssertTrue(report.contains("\"didReachLogByteLimit\" : true"))
        XCTAssertTrue(report.contains("\"logBytesRead\" : 3145728"))
        XCTAssertTrue(report.contains("\"truncatedLogLineCount\" : 1"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleSnapshotURL.path))
    }

    private func makeSystemStore(
        configuration: DiagnosticSystemReportStore.Configuration = .production,
        fileManager: FileManager = .default,
        uuidProvider: @escaping @Sendable () -> UUID = UUID.init
    ) -> DiagnosticSystemReportStore {
        DiagnosticSystemReportStore(
            directoryURL: rootURL.appendingPathComponent("reports", isDirectory: true),
            configuration: configuration,
            fileManager: fileManager,
            uuidProvider: uuidProvider
        )
    }

    private func reportFileURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: rootURL.appendingPathComponent("reports", isDirectory: true),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.lastPathComponent.hasPrefix("metric-diagnostics-")
                && $0.pathExtension == "json"
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func makeReportBuilder(
        logStore: DiagnosticLogStore,
        outputURL: URL
    ) -> DiagnosticTextReportBuilder {
        DiagnosticTextReportBuilder(
            logStore: logStore,
            systemReportStore: makeSystemStore(),
            outputDirectoryURL: outputURL,
            configuration: .init(maxReportCount: 2, maxTotalBytes: 1_024 * 1_024),
            dateProvider: { Date(timeIntervalSince1970: 10) },
            uuidProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000300")! }
        )
    }

    private func makeMetadata() -> DiagnosticExportMetadata {
        DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 5),
            sessionID: "test-session",
            gameplay: nil
        )
    }

    private func assertReportSections(
        _ report: String,
        reportURL: URL,
        rawSystemReport: Data
    ) throws {
        XCTAssertEqual(reportURL.pathExtension, "txt")
        XCTAssertTrue(report.contains("[METADATA JSON]"))
        XCTAssertTrue(report.contains("[HEALTH JSON]"))
        XCTAssertTrue(report.contains("[LOG RECORDS JSONL]"))
        XCTAssertTrue(report.contains("[SYSTEM REPORT JSON]"))
        XCTAssertTrue(report.contains("\"malformedLogLineCount\" : 1"))
        XCTAssertTrue(report.contains(try XCTUnwrap(String(data: rawSystemReport, encoding: .utf8))))
    }

    private func assertOneReportAndNoSnapshots(in outputURL: URL) throws {
        let generatedItems = try FileManager.default.contentsOfDirectory(
            at: outputURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(generatedItems.filter { $0.pathExtension == "txt" }.count, 1)
        XCTAssertFalse(generatedItems.contains { $0.lastPathComponent.hasPrefix(".log-snapshot-") })
    }

    private func record(at timestamp: TimeInterval, message: Logger.Message) -> DiagnosticLogRecord {
        DiagnosticLogRecord(
            timestamp: Date(timeIntervalSince1970: timestamp),
            sessionID: "test-session",
            level: .notice,
            label: "com.xlc.TiltArena.run",
            message: message,
            metadata: ["mode": "classic"],
            source: "test",
            file: "/tmp/Test.swift",
            function: "record()",
            line: 1
        )
    }
}

private final class FaultInjectingFileManager: FileManager, @unchecked Sendable {
    private let shouldFailRemoval: (URL) -> Bool
    private let shouldFailAttributes: (String) -> Bool

    init(
        shouldFailRemoval: @escaping (URL) -> Bool = { _ in false },
        shouldFailAttributes: @escaping (String) -> Bool = { _ in false }
    ) {
        self.shouldFailRemoval = shouldFailRemoval
        self.shouldFailAttributes = shouldFailAttributes
        super.init()
    }

    override func removeItem(at URL: URL) throws {
        guard !shouldFailRemoval(URL) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.removeItem(at: URL)
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        guard !shouldFailAttributes(path) else {
            throw CocoaError(.fileReadNoPermission)
        }
        return try super.attributesOfItem(atPath: path)
    }
}

private final class LockedUUIDSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var nextValue: UInt64 = 1

    func next() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let suffix = String(format: "%012llx", nextValue)
        nextValue += 1
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }
}

private final class LockedDateSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var nextValue: TimeInterval = 1

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        let date = Date(timeIntervalSince1970: nextValue)
        nextValue += 1
        return date
    }
}
