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

        let boundedValues = DiagnosticMetadataSanitizer.sanitized([
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

    func testTypedErrorsOmitDescriptions() throws {
        let secretDescription = "SECRET ERROR DESCRIPTION"
        let merged = typedErrorMetadata(secretDescription: secretDescription)
        let errorRecord = record(message: "operation.failed", metadata: merged)

        XCTAssertNotNil(errorRecord.metadata["error.type"])
        XCTAssertEqual(errorRecord.metadata["error.domain"], "com.example.persistence")
        XCTAssertEqual(errorRecord.metadata["error.code"], "42")
        XCTAssertNil(errorRecord.metadata["error.message"])
        XCTAssertNil(errorRecord.metadata["error.debugDescription"])
        XCTAssertNil(errorRecord.metadata["error.localizedFailureReason"])
        XCTAssertNil(errorRecord.metadata["error.localized_description"])
        XCTAssertNil(errorRecord.metadata["error_message"])
        XCTAssertFalse(try XCTUnwrap(String(data: JSONEncoder().encode(errorRecord), encoding: .utf8))
            .contains(secretDescription))
    }

    func testCallerSuppliedErrorNamespaceIsRemovedWithoutActualError() {
        let merged = DiagnosticMetadataSanitizer.merged(
            base: [
                "error": "base-secret",
                "error.type": "base-secret",
                "error-domain": "base-secret",
                "normal.base": "kept"
            ],
            provider: Logger.MetadataProvider {
                [
                    "ERROR.DOMAIN": "provider-secret",
                    "error_debugDescription": "provider-secret",
                    "normal.provider": "kept"
                ]
            },
            explicit: [
                "error.code": "999",
                "error-message": "explicit-secret",
                "normal.explicit": "kept"
            ]
        )

        XCTAssertFalse(merged.keys.contains(where: isErrorMetadataKey))
        let sanitized = DiagnosticMetadataSanitizer.sanitized(merged)
        XCTAssertEqual(sanitized["normal.base"], "kept")
        XCTAssertEqual(sanitized["normal.provider"], "kept")
        XCTAssertEqual(sanitized["normal.explicit"], "kept")
    }

    func testActualErrorReplacesCallerSuppliedTypedErrorFields() {
        let error = NSError(domain: "com.example.actual", code: 42)
        let merged = DiagnosticMetadataSanitizer.merged(
            base: [
                "error.type": "spoofed-base-type",
                "normal.base": "kept"
            ],
            provider: Logger.MetadataProvider {
                [
                    "ERROR.DOMAIN": "spoofed-provider-domain",
                    "normal.provider": "kept"
                ]
            },
            explicit: [
                "error.code": "999",
                "error.message": "spoofed-explicit-message",
                "normal.explicit": "kept"
            ],
            error: error
        )

        let sanitized = DiagnosticMetadataSanitizer.sanitized(merged)
        XCTAssertEqual(sanitized["error.type"], String(reflecting: NSError.self))
        XCTAssertEqual(sanitized["error.domain"], "com.example.actual")
        XCTAssertEqual(sanitized["error.code"], "42")
        XCTAssertNil(sanitized["ERROR.DOMAIN"])
        XCTAssertNil(sanitized["error.message"])
        XCTAssertEqual(sanitized["normal.base"], "kept")
        XCTAssertEqual(sanitized["normal.provider"], "kept")
        XCTAssertEqual(sanitized["normal.explicit"], "kept")
    }

    func testTypedErrorFieldsSurviveMetadataEntryLimit() {
        let merged = typedErrorMetadata(secretDescription: "secret")
        var crowdedMetadata: Logger.Metadata = [:]
        for index in 0..<40 {
            crowdedMetadata[String(format: "a.%02d", index)] = "value"
        }
        crowdedMetadata.merge(merged, uniquingKeysWith: { _, newValue in newValue })
        let crowdedRecord = record(message: "operation.failed", metadata: crowdedMetadata)
        XCTAssertEqual(crowdedRecord.metadata["error.domain"], "com.example.persistence")
        XCTAssertEqual(crowdedRecord.metadata["error.code"], "42")
        XCTAssertNotNil(crowdedRecord.metadata["error.type"])
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

    private func typedErrorMetadata(secretDescription: String) -> Logger.Metadata {
        let error = NSError(
            domain: "com.example.persistence",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: secretDescription]
        )
        return DiagnosticMetadataSanitizer.merged(
            base: [
                "error.debugDescription": "\(secretDescription)",
                "error.message": "\(secretDescription)",
                "error_message": "\(secretDescription)"
            ],
            provider: nil,
            explicit: [
                "error.localizedFailureReason": "\(secretDescription)",
                "error.localized_description": "\(secretDescription)"
            ],
            error: error
        )
    }

    private func isErrorMetadataKey(_ key: String) -> Bool {
        let lowercasedKey = key.lowercased()
        return lowercasedKey == "error"
            || lowercasedKey.hasPrefix("error.")
            || lowercasedKey.hasPrefix("error_")
            || lowercasedKey.hasPrefix("error-")
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
