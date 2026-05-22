import Foundation

final class DiagnosticLogStore: @unchecked Sendable {
    struct Configuration: Equatable {
        var maxCurrentFileBytes = 512 * 1_024
        var maxArchivedFileCount = 5
        var maxTotalBytes = 3 * 1_024 * 1_024

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
    private let dateProvider: @Sendable () -> Date
    private let uuidProvider: @Sendable () -> UUID
    private let encoder: JSONEncoder

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
    }

    var currentLogFileURL: URL {
        directoryURL.appendingPathComponent("current.jsonl", isDirectory: false)
    }

    func append(_ record: DiagnosticLogRecord) throws {
        let data = try encodedLine(for: record)

        try lock.withLock {
            try prepareDirectoryLocked()
            if try shouldRotateCurrentLogLocked(appendingByteCount: data.count) {
                try rotateCurrentLogLocked()
            }

            try appendLocked(data, to: currentLogFileURL)
            try pruneArchivesLocked()
        }
    }

    func logFileURLs() throws -> [URL] {
        try lock.withLock {
            try prepareDirectoryLocked()
            let archiveURLs = try archiveLogFileURLsLocked()
            guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
                return archiveURLs
            }

            return archiveURLs + [currentLogFileURL]
        }
    }

    func copyLogFiles(to destinationDirectoryURL: URL) throws {
        try lock.withLock {
            try prepareDirectoryLocked()
            try fileManager.createDirectory(
                at: destinationDirectoryURL,
                withIntermediateDirectories: true
            )

            for sourceURL in try logFileURLsLocked() {
                let destinationURL = destinationDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }
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

    private func encodedLine(for record: DiagnosticLogRecord) throws -> Data {
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    private func prepareDirectoryLocked() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try markExcludedFromBackup(directoryURL)
        try applyFileProtection(to: directoryURL)
    }

    private func shouldRotateCurrentLogLocked(appendingByteCount: Int) throws -> Bool {
        guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
            return false
        }

        let currentSize = try fileSizeLocked(currentLogFileURL)
        return currentSize > 0 && currentSize + appendingByteCount > configuration.maxCurrentFileBytes
    }

    private func rotateCurrentLogLocked() throws {
        guard fileManager.fileExists(atPath: currentLogFileURL.path) else {
            return
        }

        let archiveName = [
            "diagnostics",
            DiagnosticDateFormatter.fileSafeString(from: dateProvider()),
            uuidProvider().uuidString
        ].joined(separator: "-") + ".jsonl"
        let archiveURL = directoryURL.appendingPathComponent(archiveName, isDirectory: false)
        try fileManager.moveItem(at: currentLogFileURL, to: archiveURL)
    }

    private func appendLocked(_ data: Data, to url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
            try applyFileProtection(to: url)
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
        while archives.count > configuration.maxArchivedFileCount {
            try fileManager.removeItem(at: archives.removeFirst())
        }

        var totalBytes = try logFileURLsLocked().reduce(0) { total, url in
            try total + fileSizeLocked(url)
        }

        archives = try archiveLogFileURLsLocked()
        while totalBytes > configuration.maxTotalBytes, let oldestArchive = archives.first {
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

    private func markExcludedFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }

    private func applyFileProtection(to url: URL) throws {
        #if os(iOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #else
        _ = url
        #endif
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
