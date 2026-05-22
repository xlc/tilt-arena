import Foundation
import Logging
import XCTest
@testable import TiltArena

final class DiagnosticLogStoreTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticLogStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let rootURL, FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        rootURL = nil
        try super.tearDownWithError()
    }

    func testJSONLHandlerWritesStableLineDelimitedRecord() throws {
        let store = makeStore()
        var handler = DiagnosticJSONLLogHandler(
            label: "com.xlc.TiltArena.run",
            store: store,
            sessionID: "session-1",
            dateProvider: { Date(timeIntervalSince1970: 1) }
        )
        handler[metadataKey: "mode"] = "classic"

        handler.log(event: LogEvent(
            level: .notice,
            message: "run.started",
            metadata: ["score": "10"],
            source: "test",
            file: "/tmp/ArenaScene.swift",
            function: "test()",
            line: 42
        ))

        let contents = try String(contentsOf: store.currentLogFileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)

        let record = try JSONDecoder().decode(
            DiagnosticLogRecord.self,
            from: Data(lines[0].utf8)
        )
        XCTAssertEqual(record.schemaVersion, 1)
        XCTAssertEqual(record.timestamp, "1970-01-01T00:00:01.000Z")
        XCTAssertEqual(record.sessionID, "session-1")
        XCTAssertEqual(record.level, "notice")
        XCTAssertEqual(record.category, "run")
        XCTAssertEqual(record.message, "run.started")
        XCTAssertEqual(record.metadata["mode"], "classic")
        XCTAssertEqual(record.metadata["score"], "10")
        XCTAssertEqual(record.file, "ArenaScene.swift")
        XCTAssertEqual(record.line, 42)
    }

    func testRotationCapsArchivedFileCount() throws {
        let store = makeStore(configuration: DiagnosticLogStore.Configuration(
            maxCurrentFileBytes: 260,
            maxArchivedFileCount: 2,
            maxTotalBytes: 20_000
        ))
        let longMessage = String(repeating: "x", count: 180)

        for index in 0..<12 {
            try store.append(record(message: "event.\(index).\(longMessage)"))
        }

        let logFiles = try store.logFileURLs()
        let archivedFiles = logFiles.filter { $0.lastPathComponent.hasPrefix("diagnostics-") }
        XCTAssertLessThanOrEqual(archivedFiles.count, 2)
        XCTAssertTrue(logFiles.contains(store.currentLogFileURL))
    }

    func testMetadataSanitizerRedactsSensitiveKeys() {
        let metadata = DiagnosticMetadataSanitizer.sanitized([
            "token": "secret-token",
            "userID": "abc",
            "mode": "classic"
        ])

        XCTAssertEqual(metadata["token"], "<redacted>")
        XCTAssertEqual(metadata["userID"], "<redacted>")
        XCTAssertEqual(metadata["mode"], "classic")
    }

    func testJSONLHandlerIncludesSwiftLogErrorMetadata() throws {
        let store = makeStore()
        let handler = DiagnosticJSONLLogHandler(
            label: "com.xlc.TiltArena.app",
            store: store,
            sessionID: "session-error",
            dateProvider: { Date(timeIntervalSince1970: 1) }
        )

        handler.log(event: LogEvent(
            level: .error,
            message: "diagnostics.export.failed",
            error: TestDiagnosticError(),
            metadata: ["action": "export"],
            source: "test",
            file: "/tmp/GameViewController.swift",
            function: "test()",
            line: 7
        ))

        let contents = try String(contentsOf: store.currentLogFileURL, encoding: .utf8)
        let line = try XCTUnwrap(contents.split(separator: "\n").first)
        let record = try JSONDecoder().decode(DiagnosticLogRecord.self, from: Data(line.utf8))

        XCTAssertEqual(record.level, "error")
        XCTAssertEqual(record.message, "diagnostics.export.failed")
        XCTAssertEqual(record.metadata["action"], "export")
        XCTAssertEqual(record.metadata["error.message"], "test failure")
        XCTAssertTrue(record.metadata["error.type"]?.contains("TestDiagnosticError") == true)
    }

    func testExportBundleContainsMetadataReadmeAndCopiedLogs() throws {
        let store = makeStore()
        try store.append(record(message: "run.finished"))
        let builder = DiagnosticBundleBuilder(
            store: store,
            outputDirectoryURL: rootURL.appendingPathComponent("exports", isDirectory: true),
            dateProvider: { Date(timeIntervalSince1970: 2) },
            uuidProvider: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }
        )
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 3),
            sessionID: "session-2",
            gameplay: nil
        )

        let bundleURL = try builder.makeBundle(metadata: metadata)

        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("README.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("metadata.json").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: bundleURL
                .appendingPathComponent("logs", isDirectory: true)
                .appendingPathComponent("current.jsonl")
                .path
        ))

        let decodedMetadata = try JSONDecoder().decode(
            DiagnosticExportMetadata.self,
            from: Data(contentsOf: bundleURL.appendingPathComponent("metadata.json"))
        )
        XCTAssertEqual(decodedMetadata.schemaVersion, 1)
        XCTAssertEqual(decodedMetadata.sessionID, "session-2")
    }

    func testExportMetadataOmitsDeviceNameVendorIdentifierAndModelIdentifier() throws {
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 4),
            sessionID: "session-3",
            gameplay: nil
        )
        let data = try JSONEncoder().encode(metadata)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let device = try XCTUnwrap(object["device"] as? [String: Any])

        XCTAssertNil(device["modelIdentifier"])
        XCTAssertNil(device["name"])
        XCTAssertNil(device["identifierForVendor"])
    }

    private func makeStore(
        configuration: DiagnosticLogStore.Configuration = DiagnosticLogStore.Configuration(
            maxCurrentFileBytes: 512 * 1_024,
            maxArchivedFileCount: 5,
            maxTotalBytes: 3 * 1_024 * 1_024
        )
    ) -> DiagnosticLogStore {
        DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("logs", isDirectory: true),
            configuration: configuration,
            dateProvider: { Date(timeIntervalSince1970: 1) }
        )
    }

    private func record(message: Logger.Message) -> DiagnosticLogRecord {
        DiagnosticLogRecord(
            timestamp: Date(timeIntervalSince1970: 1),
            sessionID: "session",
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

private struct TestDiagnosticError: Error, CustomStringConvertible {
    var description: String {
        "test failure"
    }
}
