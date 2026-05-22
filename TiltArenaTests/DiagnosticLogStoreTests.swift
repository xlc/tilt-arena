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

    func testConcurrentAppendsProduceCompleteLineDelimitedRecords() throws {
        let store = makeStore(configuration: DiagnosticLogStore.Configuration(
            maxCurrentFileBytes: 128 * 1_024,
            maxArchivedFileCount: 0,
            maxTotalBytes: 256 * 1_024
        ))
        let records = (0..<80).map { index in
            record(message: "event.\(index)")
        }
        let queue = DispatchQueue(label: "DiagnosticLogStoreTests.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let errors = ConcurrentErrorRecorder()

        for record in records {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    try store.append(record)
                } catch {
                    errors.record(error)
                }
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(errors.isEmpty)

        let contents = try String(contentsOf: store.currentLogFileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        XCTAssertEqual(lines.count, records.count)

        for line in lines {
            XCTAssertNoThrow(try JSONDecoder().decode(DiagnosticLogRecord.self, from: Data(line.utf8)))
        }
    }

    func testMetadataSanitizerRedactsSensitiveKeys() {
        let longSensitiveKey = "\(String(repeating: "x", count: 84))token"
        let metadata = DiagnosticMetadataSanitizer.sanitized([
            longSensitiveKey: "secret-token",
            "token": "secret-token",
            "userID": "abc",
            "mode": "classic"
        ])

        XCTAssertEqual(metadata[String(longSensitiveKey.prefix(80))], "<redacted>")
        XCTAssertEqual(metadata["token"], "<redacted>")
        XCTAssertEqual(metadata["userID"], "<redacted>")
        XCTAssertEqual(metadata["mode"], "classic")
    }

    func testMetadataSanitizerRedactsNestedSensitiveDictionaryKeys() {
        let metadata = DiagnosticMetadataSanitizer.sanitized([
            "context": .dictionary([
                "mode": "classic",
                "nested": .dictionary([
                    "count": "2",
                    "email": "player@example.com"
                ]),
                "token": "secret-token"
            ])
        ])

        XCTAssertEqual(
            metadata["context"],
            "mode=classic,nested=count=2,email=<redacted>,token=<redacted>"
        )
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
        XCTAssertEqual(decodedMetadata.schemaVersion, DiagnosticExportMetadataFactory.currentSchemaVersion)
        XCTAssertEqual(decodedMetadata.sessionID, "session-2")
    }

    func testExportMetadataVersionTracksLocalOptionsSnapshotShape() throws {
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 5),
            sessionID: "session-4",
            gameplay: DiagnosticGameplaySnapshot(
                uiState: "options",
                selectedMode: "classic",
                runPhase: "preRun",
                score: 0,
                survivalTime: 0,
                enemyCount: 0,
                pickupCount: 0,
                localOptions: DiagnosticLocalOptionsSnapshot(
                    hapticsEnabled: true,
                    theme: "darkTacticalRadar"
                ),
                profile: DiagnosticProfileSnapshot(
                    bestScore: 0,
                    highestCombo: 0,
                    longestSurvivalTime: 0,
                    totalRuns: 0,
                    totalEnemiesDestroyed: 0,
                    unlockedWeaponCount: 3,
                    earnedAwardCount: 0
                )
            )
        )

        let data = try JSONEncoder().encode(metadata)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let gameplay = try XCTUnwrap(object["gameplay"] as? [String: Any])
        let localOptions = try XCTUnwrap(gameplay["localOptions"] as? [String: Any])

        XCTAssertEqual(object["schemaVersion"] as? Int, DiagnosticExportMetadataFactory.currentSchemaVersion)
        XCTAssertEqual(localOptions["hapticsEnabled"] as? Bool, true)
        XCTAssertEqual(localOptions["theme"] as? String, "darkTacticalRadar")
        XCTAssertNil(localOptions["audioEnabled"])
        XCTAssertNil(localOptions["reducedEffects"])
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

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}

private final class ConcurrentErrorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [any Error] = []

    var isEmpty: Bool {
        lock.withLock {
            errors.isEmpty
        }
    }

    func record(_ error: any Error) {
        lock.withLock {
            errors.append(error)
        }
    }
}
