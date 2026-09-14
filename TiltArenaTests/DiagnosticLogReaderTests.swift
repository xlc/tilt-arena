import Foundation
import Logging
import XCTest
@testable import TiltArena

final class DiagnosticLogReaderTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticLogReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        try super.tearDownWithError()
    }

    func testReadNewestReturnsCurrentThenArchivesAndToleratesMalformedLines() async throws {
        try writeLines(
            [
                try encoded(record(message: "archive.old")),
                try encoded(record(message: "archive.new"))
            ],
            to: rootURL.appendingPathComponent("diagnostics-100-old.jsonl")
        )
        try writeLines(
            [
                try encoded(record(message: "current.old")),
                Data("not-json".utf8),
                try encoded(record(message: "current.new"))
            ],
            to: rootURL.appendingPathComponent("current.jsonl")
        )
        try writeLines(
            [try encoded(record(message: "ignored"))],
            to: rootURL.appendingPathComponent("notes.jsonl")
        )

        let result = await DiagnosticLogReader(directoryURL: rootURL).readNewest()

        XCTAssertEqual(
            result.records.map(\.message),
            ["current.new", "current.old", "archive.new", "archive.old"]
        )
        XCTAssertEqual(result.malformedLineCount, 1)
        XCTAssertEqual(result.truncatedLineCount, 0)
        XCTAssertEqual(result.unreadableFileCount, 0)
        XCTAssertEqual(result.fileCount, 2)
        XCTAssertFalse(result.didReachRecordLimit)
        XCTAssertFalse(result.didReachByteLimit)
    }

    func testReadNewestHonorsRecordAndByteBounds() async throws {
        let records = (0..<8).map { record(message: "event.\($0)") }
        try writeLines(try records.map(encoded), to: rootURL.appendingPathComponent("current.jsonl"))

        let recordLimited = await DiagnosticLogReader(
            directoryURL: rootURL,
            configuration: .init(maxRecords: 3, maxBytes: 1_024 * 1_024)
        ).readNewest()
        XCTAssertEqual(recordLimited.records.map(\.message), ["event.7", "event.6", "event.5"])
        XCTAssertTrue(recordLimited.didReachRecordLimit)
        XCTAssertLessThanOrEqual(recordLimited.records.count, 3)

        let finalLineByteCount = try XCTUnwrap(try records.last.map(encoded)).count + 1
        let byteLimited = await DiagnosticLogReader(
            directoryURL: rootURL,
            configuration: .init(maxRecords: 100, maxBytes: finalLineByteCount)
        ).readNewest()
        XCTAssertEqual(byteLimited.records.map(\.message), ["event.7"])
        XCTAssertTrue(byteLimited.didReachByteLimit)
        XCTAssertLessThanOrEqual(byteLimited.bytesRead, finalLineByteCount)
        XCTAssertEqual(byteLimited.truncatedLineCount, 0)
    }

    func testMetadataAndMessagesAreBounded() throws {
        var excessiveMetadata: Logger.Metadata = [:]
        for index in 0..<40 {
            excessiveMetadata[String(format: "key.%02d", index)] = "value"
        }
        let boundedRecord = record(
            message: String(repeating: "m", count: 1_000),
            metadata: excessiveMetadata
        )
        XCTAssertEqual(boundedRecord.message.count, DiagnosticLogLimits.maxMessageLength)
        XCTAssertEqual(boundedRecord.metadata.count, DiagnosticLogLimits.maxMetadataEntries)

        let boundedValues = DiagnosticMetadataFormatter.bounded([
            "array": .array(Array(
                repeating: Logger.Metadata.Value.string("v"),
                count: DiagnosticLogLimits.maxMetadataCollectionValues + 5
            )),
            "deep": .dictionary([
                "one": .dictionary([
                    "two": .dictionary(["three": "value"])
                ])
            ]),
            "long": "\(String(repeating: "v", count: 1_000))"
        ])
        XCTAssertTrue(try XCTUnwrap(boundedValues["array"]).contains("<truncated>"))
        XCTAssertEqual(boundedValues["deep"], "one=two=<max-depth>")
        XCTAssertEqual(boundedValues["long"]?.count, DiagnosticLogLimits.maxMetadataValueLength)
    }

    func testMessageBoundUsesUTF8BytesForPathologicalSingleGrapheme() {
        let pathologicalGrapheme = "a" + String(repeating: "\u{0301}", count: 20_000)

        let boundedRecord = record(message: "\(pathologicalGrapheme)")

        XCTAssertLessThanOrEqual(
            boundedRecord.message.utf8.count,
            DiagnosticLogLimits.maxMessageLength
        )
        XCTAssertLessThan(
            boundedRecord.message.unicodeScalars.count,
            pathologicalGrapheme.unicodeScalars.count
        )
    }

    func testTypedErrorsRetainDescriptionsAndCallerContext() throws {
        let message = "Profile could not be read"
        let errorRecord = record(message: "operation.failed", metadata: typedErrorMetadata(description: message))
        XCTAssertNotNil(errorRecord.metadata["error.type"])
        XCTAssertEqual(errorRecord.metadata["error.domain"], "com.example.persistence")
        XCTAssertEqual(errorRecord.metadata["error.code"], "42")
        XCTAssertEqual(errorRecord.metadata["error.message"], message)
        XCTAssertTrue(try XCTUnwrap(errorRecord.metadata["error.description"]).contains(message))
        XCTAssertEqual(errorRecord.metadata["error.debugDescription"], message)
    }

    func testMetadataMergesNormallyWithoutFilteringErrorFields() {
        let merged = DiagnosticMetadataFormatter.merged(
            base: ["error.message": "base", "base": "kept"],
            provider: Logger.MetadataProvider { ["error.message": "provider", "provider": "kept"] },
            explicit: ["error.message": "explicit", "resource.identifier": "profile"]
        )
        let metadata = DiagnosticMetadataFormatter.bounded(merged)
        XCTAssertEqual(metadata["error.message"], "explicit")
        XCTAssertEqual(metadata["base"], "kept")
        XCTAssertEqual(metadata["provider"], "kept")
        XCTAssertEqual(metadata["resource.identifier"], "profile")
    }

    func testActualErrorSuppliesItsFieldsAlongsideCallerContext() {
        let error = NSError(domain: "com.example.actual", code: 42,
                            userInfo: [NSLocalizedDescriptionKey: "Could not read profile"])
        let merged = DiagnosticMetadataFormatter.merged(
            base: ["error.type": "base", "normal.base": "kept"],
            provider: Logger.MetadataProvider { ["normal.provider": "kept"] },
            explicit: ["error.code": "999", "error.context": "Loading profile"],
            error: error
        )
        let metadata = DiagnosticMetadataFormatter.bounded(merged)
        XCTAssertEqual(metadata["error.type"], String(reflecting: NSError.self))
        XCTAssertEqual(metadata["error.domain"], "com.example.actual")
        XCTAssertEqual(metadata["error.code"], "42")
        XCTAssertEqual(metadata["error.message"], "Could not read profile")
        XCTAssertEqual(metadata["error.context"], "Loading profile")
        XCTAssertEqual(metadata["normal.base"], "kept")
        XCTAssertEqual(metadata["normal.provider"], "kept")
    }

    func testSwiftLogPersistsDecodingErrorPathAndExplanation() throws {
        struct Payload: Decodable { let count: Int }
        let store = makeStore(maxPendingRecordCount: 1)
        let logger = Logger(label: "com.xlc.TiltArena.app") { label in
            DiagnosticJSONLLogHandler(label: label, store: store, sessionID: "decode-test")
        }
        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data(#"{"count":"invalid"}"#.utf8))
            XCTFail("Expected the invalid payload to fail decoding")
        } catch {
            logger.error("profile.load_failed", error: error)
        }
        store.flushPendingWrites()
        let contents = try Data(contentsOf: store.currentLogFileURL)
        let record = try JSONDecoder().decode(DiagnosticLogRecord.self, from: contents)
        let description = try XCTUnwrap(record.metadata["error.description"])
        XCTAssertTrue(description.contains("count"))
        XCTAssertTrue(description.contains("Expected to decode Int"))
        XCTAssertEqual(record.message, "profile.load_failed")
        XCTAssertLessThanOrEqual(contents.count, DiagnosticLogLimits.maxEncodedLineBytes + 1)
    }

    func testTypedErrorFieldsSurviveMetadataEntryLimit() {
        let merged = typedErrorMetadata(description: "secret")
        var crowdedMetadata: Logger.Metadata = [:]
        for index in 0..<40 {
            crowdedMetadata[String(format: "a.%02d", index)] = "value"
        }
        crowdedMetadata.merge(merged, uniquingKeysWith: { _, newValue in newValue })
        let crowdedRecord = record(message: "operation.failed", metadata: crowdedMetadata)
        XCTAssertEqual(crowdedRecord.metadata["error.domain"], "com.example.persistence")
        XCTAssertEqual(crowdedRecord.metadata["error.code"], "42")
        XCTAssertNotNil(crowdedRecord.metadata["error.type"])
        XCTAssertNotNil(crowdedRecord.metadata["error.description"])
        XCTAssertNotNil(crowdedRecord.metadata["error.message"])
    }

    func testQueueDropsAreCoalescedIntoOneRecoveryRecordAndHealthIsCodable() async throws {
        let store = makeStore(maxPendingRecordCount: 0)

        XCTAssertFalse(store.enqueue(record(message: "dropped.one")))
        XCTAssertFalse(store.enqueue(record(message: "dropped.two")))
        XCTAssertEqual(store.healthSnapshot.queueDropCount, 2)
        XCTAssertEqual(store.healthSnapshot.unreportedQueueDropCount, 2)

        try store.append(record(message: "persistence.recovered"))

        let health = store.healthSnapshot
        XCTAssertEqual(health.queueDropCount, 2)
        XCTAssertEqual(health.unreportedQueueDropCount, 0)
        XCTAssertEqual(health.writeFailureCount, 0)
        XCTAssertEqual(health.degradationRecordCount, 1)
        XCTAssertEqual(try JSONDecoder().decode(
            DiagnosticLogHealthSnapshot.self,
            from: JSONEncoder().encode(health)
        ), health)

        let result = await DiagnosticLogReader(directoryURL: store.directoryURL).readNewest()
        XCTAssertEqual(result.records.map(\.message), [
            "diagnostics.persistence_degraded",
            "persistence.recovered"
        ])
        XCTAssertEqual(result.records.first?.metadata["queue_drop_count"], "2")
        XCTAssertEqual(result.records.first?.metadata["write_failure_count"], "0")

        try store.append(record(message: "persistence.stable"))
        XCTAssertEqual(store.healthSnapshot.degradationRecordCount, 1)
    }

    func testWriteFailureIsCountedAndReportedAfterPersistenceRecovers() async throws {
        let blockedDirectoryURL = rootURL.appendingPathComponent("blocked", isDirectory: false)
        try Data("file-blocks-directory".utf8).write(to: blockedDirectoryURL)
        let store = DiagnosticLogStore(
            directoryURL: blockedDirectoryURL,
            configuration: .production,
            dateProvider: { Date(timeIntervalSince1970: 1) }
        )

        XCTAssertThrowsError(try store.append(record(message: "write.failed")))
        XCTAssertEqual(store.healthSnapshot.writeFailureCount, 1)
        XCTAssertEqual(store.healthSnapshot.unreportedWriteFailureCount, 1)

        try FileManager.default.removeItem(at: blockedDirectoryURL)
        try store.append(record(message: "write.recovered"))

        let health = store.healthSnapshot
        XCTAssertEqual(health.writeFailureCount, 1)
        XCTAssertEqual(health.unreportedWriteFailureCount, 0)
        XCTAssertEqual(health.degradationRecordCount, 1)

        let result = await DiagnosticLogReader(directoryURL: blockedDirectoryURL).readNewest()
        XCTAssertEqual(result.records.map(\.message), [
            "diagnostics.persistence_degraded",
            "write.recovered"
        ])
        XCTAssertEqual(result.records.first?.metadata["queue_drop_count"], "0")
        XCTAssertEqual(result.records.first?.metadata["write_failure_count"], "1")
    }

    private func makeStore(maxPendingRecordCount: Int) -> DiagnosticLogStore {
        DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("store", isDirectory: true),
            configuration: .init(
                maxCurrentFileBytes: 512 * 1_024,
                maxArchivedFileCount: 5,
                maxTotalBytes: 3 * 1_024 * 1_024,
                maxPendingRecordCount: maxPendingRecordCount
            ),
            dateProvider: { Date(timeIntervalSince1970: 1) }
        )
    }

    private func typedErrorMetadata(description: String) -> Logger.Metadata {
        let error = NSError(
            domain: "com.example.persistence",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
        return DiagnosticMetadataFormatter.merged(
            base: [
                "error.debugDescription": "\(description)",
                "error.message": "\(description)",
                "error_message": "\(description)"
            ],
            provider: nil,
            explicit: [
                "error.localizedFailureReason": "\(description)",
                "error.localized_description": "\(description)"
            ],
            error: error
        )
    }

    private func record(
        message: String,
        metadata: Logger.Metadata = ["mode": "classic"]
    ) -> DiagnosticLogRecord {
        let loggerMessage: Logger.Message = "\(message)"
        return DiagnosticLogRecord(
            timestamp: Date(timeIntervalSince1970: 1),
            sessionID: "session",
            level: .notice,
            label: "com.xlc.TiltArena.run",
            message: loggerMessage,
            metadata: metadata,
            source: "test",
            file: "/tmp/Test.swift",
            function: "record()",
            line: 1
        )
    }

    private func encoded(_ record: DiagnosticLogRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(record)
    }

    private func writeLines(_ lines: [Data], to url: URL) throws {
        var data = Data()
        for line in lines {
            data.append(line)
            data.append(0x0A)
        }
        try data.write(to: url, options: [.atomic])
    }
}
