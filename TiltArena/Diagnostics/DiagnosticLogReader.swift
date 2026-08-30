import Foundation

struct DiagnosticLogReadResult: Codable, Equatable, Sendable {
    let records: [DiagnosticLogRecord]
    let fileCount: Int
    let malformedLineCount: Int
    let truncatedLineCount: Int
    let unreadableFileCount: Int
    let bytesRead: Int
    let didReachRecordLimit: Bool
    let didReachByteLimit: Bool
}

struct DiagnosticLogReader: Sendable {
    struct Configuration: Codable, Equatable, Sendable {
        let maxRecords: Int
        let maxBytes: Int
        let maxLineBytes: Int

        static let production = Configuration(
            maxRecords: 500,
            maxBytes: 1 * 1_024 * 1_024,
            maxLineBytes: DiagnosticLogLimits.maxEncodedLineBytes
        )
        static let report = Configuration(
            maxRecords: 5_000,
            maxBytes: DiagnosticLogStore.Configuration.production.maxTotalBytes,
            maxLineBytes: DiagnosticLogLimits.maxEncodedLineBytes
        )

        init(
            maxRecords: Int,
            maxBytes: Int,
            maxLineBytes: Int = DiagnosticLogLimits.maxEncodedLineBytes
        ) {
            self.maxRecords = max(0, maxRecords)
            self.maxBytes = max(0, maxBytes)
            self.maxLineBytes = max(1, maxLineBytes)
        }
    }

    private struct TailRead {
        let data: Data
        let wasTruncated: Bool
        let startsMidLine: Bool
    }

    private struct ScanState {
        var records: [DiagnosticLogRecord] = []
        var malformedLineCount = 0
        var truncatedLineCount = 0
        var unreadableFileCount = 0
        var bytesRead = 0
        var didReachRecordLimit = false
        var didReachByteLimit = false

        mutating func scan(
            fileURLs: [URL],
            configuration: Configuration,
            fileManager: FileManager
        ) {
            didReachRecordLimit = configuration.maxRecords == 0 && !fileURLs.isEmpty
            didReachByteLimit = configuration.maxBytes == 0 && !fileURLs.isEmpty

            for fileURL in fileURLs {
                if Task.isCancelled {
                    return
                }
                if records.count >= configuration.maxRecords {
                    didReachRecordLimit = true
                    return
                }

                do {
                    let shouldContinue = try scanFile(
                        fileURL,
                        configuration: configuration,
                        fileManager: fileManager
                    )
                    if !shouldContinue {
                        return
                    }
                } catch {
                    unreadableFileCount += 1
                }
            }
        }

        mutating func result(fileCount: Int) -> DiagnosticLogReadResult {
            DiagnosticLogReadResult(
                records: records,
                fileCount: fileCount,
                malformedLineCount: malformedLineCount,
                truncatedLineCount: truncatedLineCount,
                unreadableFileCount: unreadableFileCount,
                bytesRead: bytesRead,
                didReachRecordLimit: didReachRecordLimit,
                didReachByteLimit: didReachByteLimit
            )
        }

        private mutating func scanFile(
            _ fileURL: URL,
            configuration: Configuration,
            fileManager: FileManager
        ) throws -> Bool {
            let remainingByteCount = configuration.maxBytes - bytesRead
            guard remainingByteCount > 0 else {
                didReachByteLimit = true
                return false
            }

            let tail = try DiagnosticLogReader.readTail(
                of: fileURL,
                maximumByteCount: remainingByteCount,
                fileManager: fileManager
            )
            bytesRead += tail.data.count
            didReachByteLimit = didReachByteLimit || tail.wasTruncated

            let completeLineData = trimLeadingPartialLine(from: tail)
            guard decodeLines(in: completeLineData, configuration: configuration) else {
                return false
            }
            return !tail.wasTruncated
        }

        private mutating func trimLeadingPartialLine(from tail: TailRead) -> Data {
            guard tail.startsMidLine, !tail.data.isEmpty else {
                return tail.data
            }

            truncatedLineCount += 1
            guard let newlineIndex = tail.data.firstIndex(of: 0x0A) else {
                return Data()
            }
            return Data(tail.data[tail.data.index(after: newlineIndex)...])
        }

        private mutating func decodeLines(
            in data: Data,
            configuration: Configuration
        ) -> Bool {
            let decoder = JSONDecoder()
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
            for line in lines.reversed() {
                guard records.count < configuration.maxRecords else {
                    didReachRecordLimit = true
                    return false
                }
                guard line.count <= configuration.maxLineBytes else {
                    malformedLineCount += 1
                    continue
                }

                do {
                    records.append(try decoder.decode(DiagnosticLogRecord.self, from: Data(line)))
                } catch {
                    malformedLineCount += 1
                }
            }
            return true
        }
    }

    let directoryURL: URL
    let configuration: Configuration

    init(directoryURL: URL, configuration: Configuration = .production) {
        self.directoryURL = directoryURL
        self.configuration = configuration
    }

    /// Reads file tails on a detached utility task so callers cannot
    /// accidentally perform diagnostics I/O on the main actor.
    func readNewest() async -> DiagnosticLogReadResult {
        let reader = self
        return await Task.detached(priority: .utility) {
            reader.readNewestSynchronously()
        }.value
    }

    /// Synchronous entry point for callers already isolated to a utility task,
    /// such as the immutable report builder.
    func readNewestSynchronously(fileManager: FileManager = .default) -> DiagnosticLogReadResult {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return emptyResult()
        }

        do {
            let fileURLs = try canonicalLogFileURLs(fileManager: fileManager)
            var state = ScanState()
            state.scan(
                fileURLs: fileURLs,
                configuration: configuration,
                fileManager: fileManager
            )
            return state.result(fileCount: fileURLs.count)
        } catch {
            return unreadableDirectoryResult()
        }
    }

    private func canonicalLogFileURLs(fileManager: FileManager) throws -> [URL] {
        try fileManager
            .contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            .filter(Self.isCanonicalLogFile)
            .sorted(by: Self.newestFileFirst)
    }

    private func emptyResult() -> DiagnosticLogReadResult {
        DiagnosticLogReadResult(
            records: [],
            fileCount: 0,
            malformedLineCount: 0,
            truncatedLineCount: 0,
            unreadableFileCount: 0,
            bytesRead: 0,
            didReachRecordLimit: false,
            didReachByteLimit: false
        )
    }

    private func unreadableDirectoryResult() -> DiagnosticLogReadResult {
        DiagnosticLogReadResult(
            records: [],
            fileCount: 0,
            malformedLineCount: 0,
            truncatedLineCount: 0,
            unreadableFileCount: 1,
            bytesRead: 0,
            didReachRecordLimit: false,
            didReachByteLimit: false
        )
    }

    private static func isCanonicalLogFile(_ url: URL) -> Bool {
        url.lastPathComponent == "current.jsonl"
            || (url.lastPathComponent.hasPrefix("diagnostics-") && url.pathExtension == "jsonl")
    }

    private static func newestFileFirst(_ lhs: URL, _ rhs: URL) -> Bool {
        if lhs.lastPathComponent == "current.jsonl" {
            return rhs.lastPathComponent != "current.jsonl"
        }
        if rhs.lastPathComponent == "current.jsonl" {
            return false
        }
        return lhs.lastPathComponent > rhs.lastPathComponent
    }

    private static func readTail(
        of url: URL,
        maximumByteCount: Int,
        fileManager: FileManager
    ) throws -> TailRead {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let requestedByteCount = min(UInt64(maximumByteCount), fileSize)
        let offset = fileSize - requestedByteCount

        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var startsMidLine = false
        if offset > 0 {
            try handle.seek(toOffset: offset - 1)
            startsMidLine = try handle.read(upToCount: 1)?.first != 0x0A
        }

        try handle.seek(toOffset: offset)
        return TailRead(
            data: try handle.read(upToCount: Int(requestedByteCount)) ?? Data(),
            wasTruncated: offset > 0,
            startsMidLine: startsMidLine
        )
    }
}
