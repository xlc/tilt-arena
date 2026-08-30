import Foundation

struct DiagnosticSystemReportSnapshot: Sendable {
    struct Report: Sendable {
        let fileName: String
        let jsonData: Data
    }

    let reports: [Report]
    let unreadableReportCount: Int
    let totalBytes: Int
}

final class DiagnosticSystemReportStore: @unchecked Sendable {
    struct Configuration: Equatable, Sendable {
        var maxReportCount: Int
        var maxTotalBytes: Int

        static let production = Configuration(
            maxReportCount: 8,
            maxTotalBytes: 8 * 1_024 * 1_024
        )
    }

    enum StoreError: Error, Equatable {
        case invalidConfiguration
        case payloadTooLarge(actualBytes: Int, maximumBytes: Int)
        case destinationAlreadyExists
        case quotaUnavailable
    }

    static let shared = DiagnosticSystemReportStore(
        directoryURL: defaultDirectoryURL(),
        configuration: .production
    )

    let directoryURL: URL
    let configuration: Configuration

    private let fileManager: FileManager
    private let lock = NSLock()
    private let uuidProvider: @Sendable () -> UUID

    init(
        directoryURL: URL,
        configuration: Configuration,
        fileManager: FileManager = .default,
        uuidProvider: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.directoryURL = directoryURL
        self.configuration = configuration
        self.fileManager = fileManager
        self.uuidProvider = uuidProvider
    }

    @discardableResult
    func persist(
        payloadJSON: Data,
        periodStart: Date,
        periodEnd: Date
    ) throws -> URL {
        try lock.diagnosticSystemReportWithLock {
            try validateConfigurationLocked()
            guard payloadJSON.count <= configuration.maxTotalBytes else {
                throw StoreError.payloadTooLarge(
                    actualBytes: payloadJSON.count,
                    maximumBytes: configuration.maxTotalBytes
                )
            }

            try prepareDirectoryLocked()
            if let existingURL = matchingReportURLLocked(
                payloadJSON: payloadJSON,
                periodStart: periodStart,
                periodEnd: periodEnd
            ) {
                return existingURL
            }
            try ensureCapacityForNewReportLocked(payloadBytes: payloadJSON.count)
            let reportURL = directoryURL.appendingPathComponent(
                reportFileName(
                    periodStart: periodStart,
                    periodEnd: periodEnd,
                    identifier: uuidProvider()
                ),
                isDirectory: false
            )
            guard !fileManager.fileExists(atPath: reportURL.path) else {
                throw StoreError.destinationAlreadyExists
            }

            do {
                try payloadJSON.write(to: reportURL, options: [.atomic])
                try markExcludedFromBackup(reportURL)
                try applyFileProtection(to: reportURL)
                return reportURL
            } catch {
                try? fileManager.removeItem(at: reportURL)
                throw error
            }
        }
    }

    func snapshot() throws -> DiagnosticSystemReportSnapshot {
        try lock.diagnosticSystemReportWithLock {
            try validateConfigurationLocked()
            try prepareDirectoryLocked()
            let maintenanceFailureCount = pruneLocked()

            var reports: [DiagnosticSystemReportSnapshot.Report] = []
            var unreadableReportCount = maintenanceFailureCount
            var totalBytes = 0

            let reportURLs: [URL]
            do {
                reportURLs = Array(try reportFileURLsLocked().suffix(configuration.maxReportCount))
            } catch {
                return DiagnosticSystemReportSnapshot(
                    reports: [],
                    unreadableReportCount: unreadableReportCount + 1,
                    totalBytes: 0
                )
            }

            for url in reportURLs {
                do {
                    let remainingBytes = max(0, configuration.maxTotalBytes - totalBytes)
                    let data = try readBoundedReport(at: url, maximumBytes: remainingBytes)
                    reports.append(.init(fileName: url.lastPathComponent, jsonData: data))
                    totalBytes += data.count
                } catch {
                    unreadableReportCount += 1
                }
            }

            return DiagnosticSystemReportSnapshot(
                reports: reports,
                unreadableReportCount: unreadableReportCount,
                totalBytes: totalBytes
            )
        }
    }

    private static func defaultDirectoryURL() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("Diagnostics", isDirectory: true)
        .appendingPathComponent("Reports", isDirectory: true)
    }

    private func validateConfigurationLocked() throws {
        guard configuration.maxReportCount > 0, configuration.maxTotalBytes > 0 else {
            throw StoreError.invalidConfiguration
        }
    }

    private func prepareDirectoryLocked() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try markExcludedFromBackup(directoryURL)
        try applyFileProtection(to: directoryURL)
    }

    private func reportFileName(
        periodStart: Date,
        periodEnd: Date,
        identifier: UUID
    ) -> String {
        reportFilePrefix(periodStart: periodStart, periodEnd: periodEnd)
            + identifier.uuidString
            + ".json"
    }

    private func reportFilePrefix(periodStart: Date, periodEnd: Date) -> String {
        let startMilliseconds = boundedMilliseconds(for: periodStart)
        let endMilliseconds = boundedMilliseconds(for: periodEnd)
        return String(
            format: "metric-diagnostics-%020lld-%020lld-",
            startMilliseconds,
            endMilliseconds
        )
    }

    private func boundedMilliseconds(for date: Date) -> Int64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else {
            return 0
        }
        if milliseconds >= Double(Int64.max) {
            return Int64.max
        }
        if milliseconds <= Double(Int64.min) {
            return Int64.min
        }
        return Int64(milliseconds.rounded())
    }

    private func reportFileURLsLocked() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.lastPathComponent.hasPrefix("metric-diagnostics-")
                && $0.pathExtension == "json"
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func matchingReportURLLocked(
        payloadJSON: Data,
        periodStart: Date,
        periodEnd: Date
    ) -> URL? {
        guard let reportURLs = try? reportFileURLsLocked() else {
            return nil
        }

        let filePrefix = reportFilePrefix(periodStart: periodStart, periodEnd: periodEnd)
        for url in reportURLs.reversed() where url.lastPathComponent.hasPrefix(filePrefix) {
            guard (try? fileSizeLocked(url)) == payloadJSON.count else {
                continue
            }
            guard let existingData = try? readBoundedReport(
                at: url,
                maximumBytes: payloadJSON.count
            ) else {
                continue
            }
            if existingData == payloadJSON {
                return url
            }
        }
        return nil
    }

    private struct ReportStorageEntry {
        let url: URL
        let bytes: Int?
    }

    private func ensureCapacityForNewReportLocked(payloadBytes: Int) throws {
        let reportURLs: [URL]
        do {
            reportURLs = try reportFileURLsLocked()
        } catch {
            throw StoreError.quotaUnavailable
        }

        var reports: [ReportStorageEntry] = []
        reports.reserveCapacity(reportURLs.count)
        for url in reportURLs {
            do {
                reports.append(
                    ReportStorageEntry(url: url, bytes: try fileSizeLocked(url))
                )
            } catch {
                throw StoreError.quotaUnavailable
            }
        }

        let availableReportCount = configuration.maxReportCount - 1
        let availableBytes = configuration.maxTotalBytes - payloadBytes
        var failedRemovals: Set<URL> = []

        while reports.count > availableReportCount
            || !reportsFitWithinByteLimit(reports, byteLimit: availableBytes) {
            guard let removalIndex = reports.firstIndex(where: {
                !failedRemovals.contains($0.url)
            }) else {
                throw StoreError.quotaUnavailable
            }

            let report = reports[removalIndex]
            if removeReportIfPossible(report.url) {
                reports.remove(at: removalIndex)
            } else {
                failedRemovals.insert(report.url)
            }
        }
    }

    private func pruneLocked() -> Int {
        guard var reportURLs = try? reportFileURLsLocked() else {
            return 1
        }

        var failedRemovals: Set<URL> = []
        var failureCount = pruneReportCountLocked(
            &reportURLs,
            failedRemovals: &failedRemovals
        )
        let sizedResult = reportStorageEntriesLocked(for: reportURLs)
        var sizedReports = sizedResult.entries
        failureCount += sizedResult.failureCount
        failureCount += pruneReportBytesLocked(
            &sizedReports,
            failedRemovals: &failedRemovals
        )
        return failureCount
    }

    private func pruneReportCountLocked(
        _ reportURLs: inout [URL],
        failedRemovals: inout Set<URL>
    ) -> Int {
        var failureCount = 0
        while reportURLs.count > configuration.maxReportCount {
            let removalIndex = reportURLs.firstIndex {
                !failedRemovals.contains($0)
            }
            guard let removalIndex else {
                break
            }
            let url = reportURLs[removalIndex]
            if removeReportIfPossible(url) {
                reportURLs.remove(at: removalIndex)
            } else {
                failedRemovals.insert(url)
                failureCount += 1
            }
        }
        return failureCount
    }

    private func reportStorageEntriesLocked(
        for reportURLs: [URL]
    ) -> (entries: [ReportStorageEntry], failureCount: Int) {
        var sizedReports: [ReportStorageEntry] = []
        sizedReports.reserveCapacity(reportURLs.count)
        var failureCount = 0
        for url in reportURLs {
            do {
                sizedReports.append(
                    ReportStorageEntry(url: url, bytes: try fileSizeLocked(url))
                )
            } catch {
                sizedReports.append(ReportStorageEntry(url: url, bytes: nil))
                failureCount += 1
            }
        }
        return (sizedReports, failureCount)
    }

    private func pruneReportBytesLocked(
        _ sizedReports: inout [ReportStorageEntry],
        failedRemovals: inout Set<URL>
    ) -> Int {
        var failureCount = 0
        while !reportsFitWithinByteLimit(
            sizedReports,
            byteLimit: configuration.maxTotalBytes
        ) {
            let unknownSizeReports = sizedReports.filter { $0.bytes == nil }
            if !unknownSizeReports.isEmpty {
                guard let removalIndex = sizedReports.firstIndex(where: {
                    $0.bytes == nil
                        && !failedRemovals.contains($0.url)
                }) else {
                    break
                }
                let report = sizedReports[removalIndex]
                if removeReportIfPossible(report.url) {
                    sizedReports.remove(at: removalIndex)
                } else {
                    failedRemovals.insert(report.url)
                    failureCount += 1
                }
                continue
            }

            let removalIndex = sizedReports.firstIndex {
                !failedRemovals.contains($0.url)
            }
            guard let removalIndex else {
                break
            }
            let oldest = sizedReports[removalIndex]
            if removeReportIfPossible(oldest.url) {
                sizedReports.remove(at: removalIndex)
            } else {
                failedRemovals.insert(oldest.url)
                failureCount += 1
            }
        }
        return failureCount
    }

    private func reportsFitWithinByteLimit(
        _ reports: [ReportStorageEntry],
        byteLimit: Int
    ) -> Bool {
        var remainingBytes = byteLimit
        for report in reports {
            guard let bytes = report.bytes, bytes <= remainingBytes else {
                return false
            }
            remainingBytes -= bytes
        }
        return true
    }

    private func removeReportIfPossible(_ url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private func readBoundedReport(at url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0 else {
            throw StoreError.payloadTooLarge(actualBytes: 1, maximumBytes: 0)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }
        let readLimit = maximumBytes == Int.max ? Int.max : maximumBytes + 1
        let data = try handle.read(upToCount: readLimit) ?? Data()
        guard data.count <= maximumBytes else {
            throw StoreError.payloadTooLarge(
                actualBytes: data.count,
                maximumBytes: maximumBytes
            )
        }
        return data
    }

    private func fileSizeLocked(_ url: URL) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.compare(NSNumber(value: 0)) != .orderedAscending,
              size.compare(NSNumber(value: Int.max)) != .orderedDescending else {
            throw StoreError.quotaUnavailable
        }
        return size.intValue
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
    func diagnosticSystemReportWithLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
