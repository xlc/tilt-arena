import Foundation

struct DiagnosticGameplaySnapshot: Codable, Equatable {
    let uiState: String
    let selectedMode: String
    let runPhase: String
    let score: Int
    let survivalTime: TimeInterval
    let enemyCount: Int
    let pickupCount: Int
    let localOptions: DiagnosticLocalOptionsSnapshot
    let profile: DiagnosticProfileSnapshot
}

struct DiagnosticLocalOptionsSnapshot: Codable, Equatable {
    let audioEnabled: Bool
    let hapticsEnabled: Bool
    let reducedEffects: Bool
    let theme: String
}

struct DiagnosticProfileSnapshot: Codable, Equatable {
    let bestScore: Int
    let highestCombo: Int
    let longestSurvivalTime: TimeInterval
    let totalRuns: Int
    let totalEnemiesDestroyed: Int
    let unlockedWeaponCount: Int
    let earnedAwardCount: Int
}

struct DiagnosticExportMetadata: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: String
    let sessionID: String
    let app: DiagnosticAppMetadata
    let device: DiagnosticDeviceMetadata
    let gameplay: DiagnosticGameplaySnapshot?
}

struct DiagnosticAppMetadata: Codable, Equatable {
    let bundleID: String
    let version: String
    let build: String
}

struct DiagnosticDeviceMetadata: Codable, Equatable {
    let osName: String
    let osVersion: String
    let localeIdentifier: String
}

enum DiagnosticExportMetadataFactory {
    static func make(
        generatedAt: Date,
        sessionID: String,
        gameplay: DiagnosticGameplaySnapshot?,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        locale: Locale = .autoupdatingCurrent
    ) -> DiagnosticExportMetadata {
        DiagnosticExportMetadata(
            schemaVersion: 1,
            generatedAt: DiagnosticDateFormatter.string(from: generatedAt),
            sessionID: sessionID,
            app: DiagnosticAppMetadata(
                bundleID: bundle.bundleIdentifier ?? "unknown",
                version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
            ),
            device: DiagnosticDeviceMetadata(
                osName: "iOS",
                osVersion: processInfo.operatingSystemVersionString,
                localeIdentifier: locale.identifier
            ),
            gameplay: gameplay
        )
    }
}

struct DiagnosticBundleBuilder {
    let store: DiagnosticLogStore
    let outputDirectoryURL: URL
    let fileManager: FileManager
    let dateProvider: @Sendable () -> Date
    let uuidProvider: @Sendable () -> UUID

    init(
        store: DiagnosticLogStore = .shared,
        outputDirectoryURL: URL,
        fileManager: FileManager = .default,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        uuidProvider: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.store = store
        self.outputDirectoryURL = outputDirectoryURL
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
    }

    func makeBundle(metadata: DiagnosticExportMetadata) throws -> URL {
        try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        let bundleURL = outputDirectoryURL.appendingPathComponent(
            "TiltArenaDiagnostics-\(DiagnosticDateFormatter.fileSafeString(from: dateProvider()))-\(uuidProvider().uuidString)",
            isDirectory: true
        )
        if fileManager.fileExists(atPath: bundleURL.path) {
            try fileManager.removeItem(at: bundleURL)
        }

        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try markExcludedFromBackup(bundleURL)

        let metadataURL = bundleURL.appendingPathComponent("metadata.json", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: metadataURL, options: [.atomic])

        let logsDirectoryURL = bundleURL.appendingPathComponent("logs", isDirectory: true)
        try store.copyLogFiles(to: logsDirectoryURL)

        let readmeURL = bundleURL.appendingPathComponent("README.txt", isDirectory: false)
        try readmeText.write(to: readmeURL, atomically: true, encoding: .utf8)

        return bundleURL
    }

    private var readmeText: String {
        """
        Tilt Arena diagnostics export

        metadata.json contains app, OS, session, and gameplay snapshot fields.
        logs/*.jsonl contains line-delimited diagnostic records suitable for tail, rg, and jq.
        """
    }

    private func markExcludedFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}
