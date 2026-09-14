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
        store.flushPendingWrites()

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

    func testSameTimestampRotationsRetainDeterministicNewestFirstOrder() throws {
        let uuidSequence = LockedDiagnosticUUIDSequence()
        let store = DiagnosticLogStore(
            directoryURL: rootURL.appendingPathComponent("ordered-logs", isDirectory: true),
            configuration: .init(
                maxCurrentFileBytes: 1,
                maxArchivedFileCount: 2,
                maxTotalBytes: 64 * 1_024
            ),
            dateProvider: { Date(timeIntervalSince1970: 1) },
            uuidProvider: uuidSequence.next
        )

        for index in 0..<4 {
            try store.append(record(message: "event.\(index)"))
        }

        let result = store.readNewest(configuration: .init(
            maxRecords: 10,
            maxBytes: 64 * 1_024
        ))
        XCTAssertEqual(result.records.map(\.message), ["event.3", "event.2", "event.1"])
        let archiveNames = try store.logFileURLs()
            .filter { $0.lastPathComponent.hasPrefix("diagnostics-") }
            .map(\.lastPathComponent)
        XCTAssertTrue(archiveNames[0].contains("-g00000000000000000002-"))
        XCTAssertTrue(archiveNames[1].contains("-g00000000000000000003-"))
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

    func testWriterCompactsEscapedMetadataToReadableLineLimit() throws {
        let store = makeStore(configuration: .init(
            maxCurrentFileBytes: 128 * 1_024,
            maxArchivedFileCount: 1,
            maxTotalBytes: 256 * 1_024
        ))
        var metadata: Logger.Metadata = [:]
        for index in 0..<DiagnosticLogLimits.maxMetadataEntries {
            metadata["field.\(index)"] = "\(String(repeating: "\u{0000}", count: 240))"
        }

        try store.append(DiagnosticLogRecord(
            timestamp: Date(timeIntervalSince1970: 1),
            sessionID: "session",
            level: .notice,
            label: "com.xlc.TiltArena.run",
            message: "run.metadata_heavy",
            metadata: metadata,
            source: "test",
            file: "/tmp/Test.swift",
            function: "testWriterCompactsEscapedMetadataToReadableLineLimit()",
            line: 1
        ))

        let contents = try Data(contentsOf: store.currentLogFileURL)
        let line = try XCTUnwrap(contents.split(separator: 0x0A).first)
        XCTAssertLessThanOrEqual(line.count, DiagnosticLogLimits.maxEncodedLineBytes)

        let decoded = try JSONDecoder().decode(DiagnosticLogRecord.self, from: Data(line))
        XCTAssertEqual(decoded.metadata["diagnostics.metadata_truncated"], "true")
        let readResult = DiagnosticLogReader(
            directoryURL: store.directoryURL
        ).readNewestSynchronously()
        XCTAssertEqual(readResult.records.map(\.message), ["run.metadata_heavy"])
        XCTAssertEqual(readResult.malformedLineCount, 0)
    }

    func testNegativeRetentionConfigurationCannotTrap() throws {
        let store = makeStore(configuration: .init(
            maxCurrentFileBytes: -1,
            maxArchivedFileCount: -1,
            maxTotalBytes: -1,
            maxPendingRecordCount: -1
        ))

        XCTAssertFalse(store.enqueue(record(message: "queued.drop")))
        XCTAssertNoThrow(try store.append(record(message: "direct.write")))
        XCTAssertEqual(try store.logFileURLs(), [store.currentLogFileURL])
    }

    func testMetadataFormatterPreservesKeysAndBoundsTheirLength() {
        let longSensitiveKey = "\(String(repeating: "x", count: 84))token"
        let metadata = DiagnosticMetadataFormatter.bounded([
            longSensitiveKey: "secret-token",
            "token": "secret-token",
            "userID": "abc",
            "mode": "classic"
        ])

        XCTAssertEqual(metadata[String(longSensitiveKey.prefix(80))], "secret-token")
        XCTAssertEqual(metadata["token"], "secret-token")
        XCTAssertEqual(metadata["userID"], "abc")
        XCTAssertEqual(metadata["mode"], "classic")
    }

    func testMetadataFormatterPreservesNestedDictionaryValues() {
        let metadata = DiagnosticMetadataFormatter.bounded([
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
            "mode=classic,nested=count=2,email=player@example.com,token=secret-token"
        )
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
                    audioEnabled: true,
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
        XCTAssertEqual(localOptions["audioEnabled"] as? Bool, true)
        XCTAssertEqual(localOptions["hapticsEnabled"] as? Bool, true)
        XCTAssertEqual(localOptions["theme"] as? String, "darkTacticalRadar")
        XCTAssertNil(localOptions["reducedEffects"])
    }

    func testExportMetadataIncludesOSAndLocaleContext() throws {
        let metadata = DiagnosticExportMetadataFactory.make(
            generatedAt: Date(timeIntervalSince1970: 4),
            sessionID: "session-3",
            gameplay: nil
        )
        let data = try JSONEncoder().encode(metadata)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let device = try XCTUnwrap(object["device"] as? [String: Any])

        XCTAssertEqual(device["osName"] as? String, "iOS")
        XCTAssertEqual(device["osVersion"] as? String, ProcessInfo.processInfo.operatingSystemVersionString)
        XCTAssertEqual(device["localeIdentifier"] as? String, Locale.autoupdatingCurrent.identifier)
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

private final class LockedDiagnosticUUIDSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var nextValue: UInt64 = 1

    func next() -> UUID {
        lock.withLock {
            defer { nextValue += 1 }
            let suffix = String(format: "%012llx", nextValue)
            return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
        }
    }
}
