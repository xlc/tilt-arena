import Foundation

struct DiagnosticLogHealthSnapshot: Codable, Equatable, Sendable {
    let pendingRecordCount: Int
    let queueDropCount: UInt64
    let writeFailureCount: UInt64
    let degradationRecordCount: UInt64
    let unreportedQueueDropCount: UInt64
    let unreportedWriteFailureCount: UInt64
}

final class DiagnosticLogStore: @unchecked Sendable {
    enum StoreError: Error, Equatable {
        case encodedRecordTooLarge(actualBytes: Int, maximumBytes: Int)
    }

    struct Configuration: Equatable, Sendable {
        var maxCurrentFileBytes = 512 * 1_024
        var maxArchivedFileCount = 5
        var maxTotalBytes = 3 * 1_024 * 1_024
        var maxPendingRecordCount = 256

        static let production = Configuration()
    }

    static let shared = DiagnosticLogStore(
        directoryURL: DiagnosticLogStore.defaultDirectoryURL(),
        configuration: .production
    )

    let directoryURL: URL
    let configuration: Configuration
    private let fileManager: FileManager
    private let lock = NSLock()
    private let healthLock = NSLock()
    private let writeQueue = DispatchQueue(
        label: "com.xlc.TiltArena.diagnostics.writer",
        qos: .utility
    )
    private let writeQueueKey = DispatchSpecificKey<UInt8>()
    private let dateProvider: @Sendable () -> Date
    private let uuidProvider: @Sendable () -> UUID
    private let encoder: JSONEncoder
    private var healthState = HealthState()
    private var archiveGeneration: UInt64?

    private struct HealthState {
        var pendingRecordCount = 0
        var queueDropCount: UInt64 = 0
        var writeFailureCount: UInt64 = 0
        var degradationRecordCount: UInt64 = 0
        var unreportedQueueDropCount: UInt64 = 0
        var unreportedWriteFailureCount: UInt64 = 0
    }

    private struct PendingDegradation {
        let queueDropCount: UInt64
        let writeFailureCount: UInt64
    }

    init(
        directoryURL: URL,
        configuration: Configuration,
        fileManager: FileManager = .default,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        uuidProvider: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.directoryURL = directoryURL
        self.configuration = configuration
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        writeQueue.setSpecific(key: writeQueueKey, value: 1)
    }

    var currentLogFileURL: URL {
        directoryURL.appendingPathComponent("current.jsonl", isDirectory: false)
    }

    var healthSnapshot: DiagnosticLogHealthSnapshot {
        healthLock.withLock {
            DiagnosticLogHealthSnapshot(
                pendingRecordCount: healthState.pendingRecordCount,
                queueDropCount: healthState.queueDropCount,
                writeFailureCount: healthState.writeFailureCount,
                degradationRecordCount: healthState.degradationRecordCount,
                unreportedQueueDropCount: healthState.unreportedQueueDropCount,
                unreportedWriteFailureCount: healthState.unreportedWriteFailureCount
            )
        }
    }

    func append(_ record: DiagnosticLogRecord) throws {
        do {
            try appendRecord(record)
        } catch {
            recordWriteFailure()
            throw error
        }

        emitPendingDegradationIfNeeded(sessionID: record.sessionID)
    }

    /// Queues routine persistence away from gameplay's main-thread render loop.
    /// The queue is deliberately bounded: diagnostics are best-effort and must
    /// be dropped rather than allowing slow storage to create unbounded work.
    @discardableResult
    func enqueue(_ record: DiagnosticLogRecord) -> Bool {
        guard reservePendingWrite() else {
            return false
        }

        writeQueue.async { [self] in
            defer { releasePendingWrite() }
            try? append(record)
        }
        return true
    }

    /// Waits for records accepted before this call. Intended for tests and
    /// background export work, never for the gameplay render path.
    func flushPendingWrites() {
        guard DispatchQueue.getSpecific(key: writeQueueKey) == nil else {
            return
        }

        writeQueue.sync {}
    }

    func logFileURLs() throws -> [URL] {
        flushPendingWrites()
        return try lock.withLock {
            try prepareDirectoryLocked()
            let archiveURLs = try archiveLogFileURLsLocked()
            guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
                return archiveURLs
            }

            return archiveURLs + [currentLogFileURL]
        }
    }

    /// Reads a consistent, bounded view without copying whole log files.
    /// The store lock prevents rotation while the tail reader is scanning;
    /// gameplay logging remains nonblocking because producers only enqueue.
    func readNewest(
        configuration: DiagnosticLogReader.Configuration
    ) -> DiagnosticLogReadResult {
        flushPendingWrites()
        return lock.withLock {
            DiagnosticLogReader(
                directoryURL: directoryURL,
                configuration: configuration
            ).readNewestSynchronously(fileManager: fileManager)
        }
    }

    private static let metadataTruncatedKey = "diagnostics.metadata_truncated"

    private func metadataRemovalOrder(_ metadata: [String: String]) -> [String] {
        metadata.keys.sorted { lhs, rhs in
            let lhsIsTypedError = DiagnosticMetadataFormatter.errorKeys.contains(lhs)
            let rhsIsTypedError = DiagnosticMetadataFormatter.errorKeys.contains(rhs)
            if lhsIsTypedError != rhsIsTypedError {
                return !lhsIsTypedError
            }

            let lhsBytes = metadata[lhs]?.utf8.count ?? 0
            let rhsBytes = metadata[rhs]?.utf8.count ?? 0
            if lhsBytes != rhsBytes {
                return lhsBytes > rhsBytes
            }
            return lhs > rhs
        }
    }

    private func boundedEncodedRecord(_ record: DiagnosticLogRecord) throws -> Data {
        var metadata = record.metadata
        var candidate = record
        var data = try encoder.encode(candidate)
        guard data.count > DiagnosticLogLimits.maxEncodedLineBytes else {
            return data
        }

        for key in metadataRemovalOrder(metadata) {
            metadata.removeValue(forKey: key)
            metadata[Self.metadataTruncatedKey] = "true"
            candidate = record.replacingMetadata(metadata)
            data = try encoder.encode(candidate)
            if data.count <= DiagnosticLogLimits.maxEncodedLineBytes {
                return data
            }
        }

        throw StoreError.encodedRecordTooLarge(
            actualBytes: data.count,
            maximumBytes: DiagnosticLogLimits.maxEncodedLineBytes
        )
    }

    private static func defaultDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return baseURL
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    private func appendRecord(_ record: DiagnosticLogRecord) throws {
        try lock.withLock {
            let data = try encodedLine(for: record)
            try prepareDirectoryLocked()
            if try shouldRotateCurrentLogLocked(appendingByteCount: data.count) {
                try rotateCurrentLogLocked()
            }

            try appendLocked(data, to: currentLogFileURL)
            try pruneArchivesLocked()
        }
    }

    private func encodedLine(for record: DiagnosticLogRecord) throws -> Data {
        var data = try boundedEncodedRecord(record)
        data.append(0x0A)
        return data
    }

    private func prepareDirectoryLocked() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func shouldRotateCurrentLogLocked(appendingByteCount: Int) throws -> Bool {
        guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
            return false
        }

        let currentSize = try fileSizeLocked(currentLogFileURL)
        let maximumBytes = max(1, configuration.maxCurrentFileBytes)
        let wouldOverflow = appendingByteCount > Int.max - currentSize
        return currentSize > 0 && (wouldOverflow || currentSize + appendingByteCount > maximumBytes)
    }

    private func rotateCurrentLogLocked() throws {
        guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
            return
        }

        let archiveName = [
            "diagnostics",
            "g\(String(format: "%020llu", try nextArchiveGenerationLocked()))",
            DiagnosticDateFormatter.fileSafeString(from: dateProvider()),
            uuidProvider().uuidString
        ].joined(separator: "-") + ".jsonl"
        let archiveURL = directoryURL.appendingPathComponent(archiveName, isDirectory: false)
        try fileManager.moveItem(at: currentLogFileURL, to: archiveURL)
    }

    private func nextArchiveGenerationLocked() throws -> UInt64 {
        if let archiveGeneration {
            let nextGeneration = archiveGeneration == UInt64.max
                ? UInt64.max
                : archiveGeneration + 1
            self.archiveGeneration = nextGeneration
            return nextGeneration
        }

        let latestGeneration = try archiveLogFileURLsLocked()
            .compactMap(Self.archiveGeneration(from:))
            .max() ?? 0
        let nextGeneration = latestGeneration == UInt64.max
            ? UInt64.max
            : latestGeneration + 1
        archiveGeneration = nextGeneration
        return nextGeneration
    }

    private static func archiveGeneration(from url: URL) -> UInt64? {
        let components = url.deletingPathExtension().lastPathComponent.split(separator: "-")
        guard components.count >= 2, components[1].hasPrefix("g") else {
            return nil
        }
        return UInt64(components[1].dropFirst())
    }

    private func appendLocked(_ data: Data, to url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private func logFileURLsLocked() throws -> [URL] {
        let archiveURLs = try archiveLogFileURLsLocked()
        guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
            return archiveURLs
        }

        return archiveURLs + [currentLogFileURL]
    }

    private func archiveLogFileURLsLocked() throws -> [URL] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        return try fileManager
            .contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            .filter {
                $0.lastPathComponent.hasPrefix("diagnostics-")
                    && $0.pathExtension == "jsonl"
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func pruneArchivesLocked() throws {
        var archives = try archiveLogFileURLsLocked()
        while archives.count > max(0, configuration.maxArchivedFileCount) {
            try fileManager.removeItem(at: archives.removeFirst())
        }

        var totalBytes = try logFileURLsLocked().reduce(0) { total, url in
            let fileBytes = try fileSizeLocked(url)
            return fileBytes > Int.max - total ? Int.max : total + fileBytes
        }

        archives = try archiveLogFileURLsLocked()
        let maximumTotalBytes = max(0, configuration.maxTotalBytes)
        while totalBytes > maximumTotalBytes, let oldestArchive = archives.first {
            let removedSize = try fileSizeLocked(oldestArchive)
            try fileManager.removeItem(at: oldestArchive)
            totalBytes -= removedSize
            archives.removeFirst()
        }
    }

    private func fileSizeLocked(_ url: URL) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }

    private func reservePendingWrite() -> Bool {
        healthLock.withLock {
            guard healthState.pendingRecordCount < max(0, configuration.maxPendingRecordCount) else {
                Self.saturatingIncrement(&healthState.queueDropCount)
                Self.saturatingIncrement(&healthState.unreportedQueueDropCount)
                return false
            }

            healthState.pendingRecordCount += 1
            return true
        }
    }

    private func releasePendingWrite() {
        healthLock.withLock {
            healthState.pendingRecordCount = max(0, healthState.pendingRecordCount - 1)
        }
    }

    private func recordWriteFailure() {
        healthLock.withLock {
            Self.saturatingIncrement(&healthState.writeFailureCount)
            Self.saturatingIncrement(&healthState.unreportedWriteFailureCount)
        }
    }

    private func emitPendingDegradationIfNeeded(sessionID: String) {
        guard let degradation = takePendingDegradation() else {
            return
        }

        let record = DiagnosticLogRecord.persistenceDegraded(
            timestamp: dateProvider(),
            sessionID: sessionID,
            queueDropCount: degradation.queueDropCount,
            writeFailureCount: degradation.writeFailureCount
        )

        do {
            try appendRecord(record)
            healthLock.withLock {
                Self.saturatingIncrement(&healthState.degradationRecordCount)
            }
        } catch {
            restorePendingDegradationAfterWriteFailure(degradation)
        }
    }

    private func takePendingDegradation() -> PendingDegradation? {
        healthLock.withLock {
            let degradation = PendingDegradation(
                queueDropCount: healthState.unreportedQueueDropCount,
                writeFailureCount: healthState.unreportedWriteFailureCount
            )
            guard degradation.queueDropCount > 0 || degradation.writeFailureCount > 0 else {
                return nil
            }

            healthState.unreportedQueueDropCount = 0
            healthState.unreportedWriteFailureCount = 0
            return degradation
        }
    }

    private func restorePendingDegradationAfterWriteFailure(_ degradation: PendingDegradation) {
        healthLock.withLock {
            Self.saturatingAdd(degradation.queueDropCount, to: &healthState.unreportedQueueDropCount)
            Self.saturatingAdd(degradation.writeFailureCount, to: &healthState.unreportedWriteFailureCount)
            Self.saturatingIncrement(&healthState.writeFailureCount)
            Self.saturatingIncrement(&healthState.unreportedWriteFailureCount)
        }
    }

    private static func saturatingIncrement(_ value: inout UInt64) {
        saturatingAdd(1, to: &value)
    }

    private static func saturatingAdd(_ amount: UInt64, to value: inout UInt64) {
        if amount > UInt64.max - value {
            value = UInt64.max
        } else {
            value += amount
        }
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
