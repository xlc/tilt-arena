import Foundation
@preconcurrency import MetricKit
import Logging

final class MetricKitDiagnosticCollector: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    private struct PayloadBatch: @unchecked Sendable {
        let payloads: [MXDiagnosticPayload]
        let receivedPayloadCount: Int
        let source: String
    }

    struct PayloadWorkSummary: Equatable, Sendable {
        let consumedPayloadCount: Int
        let consumedBytes: Int
        let skippedPayloadCount: Int
        let didReachByteBudget: Bool
    }

    private struct RankedElement<Element> {
        let offset: Int
        let element: Element
        let start: Date
        let end: Date
    }

    private struct PayloadDiagnosticCounts {
        var crash = 0
        var hang = 0
        var cpuException = 0
        var diskWriteException = 0
        var appLaunch = 0

        mutating func add(_ payload: MXDiagnosticPayload) {
            crash = MetricKitDiagnosticCollector.saturatingSum(
                crash,
                payload.crashDiagnostics?.count ?? 0
            )
            hang = MetricKitDiagnosticCollector.saturatingSum(
                hang,
                payload.hangDiagnostics?.count ?? 0
            )
            cpuException = MetricKitDiagnosticCollector.saturatingSum(
                cpuException,
                payload.cpuExceptionDiagnostics?.count ?? 0
            )
            diskWriteException = MetricKitDiagnosticCollector.saturatingSum(
                diskWriteException,
                payload.diskWriteExceptionDiagnostics?.count ?? 0
            )
            appLaunch = MetricKitDiagnosticCollector.saturatingSum(
                appLaunch,
                payload.appLaunchDiagnostics?.count ?? 0
            )
        }
    }

    private struct PayloadPersistenceSummary {
        let receivedPayloadCount: Int
        let selectedPayloadCount: Int
        let work: PayloadWorkSummary
        let storedPayloadCount: Int
        let storedBytes: Int
        let diagnostics: PayloadDiagnosticCounts

        func metadata(source: String) -> Logging.Logger.Metadata {
            [
                "payload_source": "\(source)",
                "received_payload_count": "\(receivedPayloadCount)",
                "selected_payload_count": "\(selectedPayloadCount)",
                "cohort_skipped_payload_count": "\(max(0, receivedPayloadCount - selectedPayloadCount))",
                "processed_payload_count": "\(work.consumedPayloadCount)",
                "byte_budget_skipped_payload_count": "\(work.skippedPayloadCount)",
                "work_budget_reached": "\(work.didReachByteBudget)",
                "stored_payload_count": "\(storedPayloadCount)",
                "stored_bytes": "\(storedBytes)",
                "work_bytes": "\(work.consumedBytes)",
                "crash_count": "\(diagnostics.crash)",
                "hang_count": "\(diagnostics.hang)",
                "cpu_exception_count": "\(diagnostics.cpuException)",
                "disk_write_exception_count": "\(diagnostics.diskWriteException)",
                "app_launch_count": "\(diagnostics.appLaunch)"
            ]
        }
    }

    private let store: DiagnosticSystemReportStore
    private let logger: Logging.Logger
    private let persistenceQueue = DispatchQueue(
        label: "com.xlc.TiltArena.diagnostics.metric-kit",
        qos: .utility
    )
    private let stateLock = NSLock()
    private var isStarted = false

    init(
        store: DiagnosticSystemReportStore = .shared,
        logger: Logging.Logger = AppDiagnostics.logger(.diagnostics)
    ) {
        self.store = store
        self.logger = logger
        super.init()
    }

    func start() {
        let shouldSubscribe = stateLock.metricKitWithLock {
            guard !isStarted else {
                return false
            }
            isStarted = true
            return true
        }
        guard shouldSubscribe else {
            return
        }

        let manager = MXMetricManager.shared
        manager.add(self)
        let pastPayloads = manager.pastDiagnosticPayloads
        logger.info("diagnostics.metric_kit.subscribed", metadata: [
            "past_payload_count": "\(pastPayloads.count)"
        ])
        enqueue(pastPayloads, source: "past_payloads")
    }

    deinit {
        let shouldUnsubscribe = stateLock.metricKitWithLock { isStarted }
        if shouldUnsubscribe {
            MXMetricManager.shared.remove(self)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        enqueue(payloads, source: "subscriber_callback")
    }

    private func enqueue(_ payloads: [MXDiagnosticPayload], source: String) {
        let selectedPayloads = Self.newestCohort(
            payloads,
            limit: store.configuration.maxReportCount,
            periodStart: \.timeStampBegin,
            periodEnd: \.timeStampEnd
        )
        guard !selectedPayloads.isEmpty else {
            return
        }

        let batch = PayloadBatch(
            payloads: selectedPayloads,
            receivedPayloadCount: payloads.count,
            source: source
        )
        persistenceQueue.async { [self, batch] in
            persist(
                batch.payloads,
                receivedPayloadCount: batch.receivedPayloadCount,
                source: batch.source
            )
        }
    }

    private func persist(
        _ payloads: [MXDiagnosticPayload],
        receivedPayloadCount: Int,
        source: String
    ) {
        var storedPayloadCount = 0
        var storedBytes = 0
        var diagnosticCounts = PayloadDiagnosticCounts()
        var firstError: (any Error)?

        let workSummary = Self.consumeSerializedPayloads(
            payloads,
            maxTotalBytes: store.configuration.maxTotalBytes,
            serialize: { $0.jsonRepresentation() },
            consume: { [store] payload, jsonData in
                diagnosticCounts.add(payload)
                do {
                    try store.persist(
                        payloadJSON: jsonData,
                        periodStart: payload.timeStampBegin,
                        periodEnd: payload.timeStampEnd
                    )
                    storedPayloadCount += 1
                    storedBytes += jsonData.count
                } catch {
                    firstError = firstError ?? error
                }
            }
        )

        let metadata = PayloadPersistenceSummary(
            receivedPayloadCount: receivedPayloadCount,
            selectedPayloadCount: payloads.count,
            work: workSummary,
            storedPayloadCount: storedPayloadCount,
            storedBytes: storedBytes,
            diagnostics: diagnosticCounts
        ).metadata(source: source)

        if let firstError {
            logger.error(
                "diagnostics.system_reports.persist_failed",
                error: firstError,
                metadata: metadata
            )
        } else if workSummary.didReachByteBudget {
            logger.warning("diagnostics.system_reports.work_budget_reached", metadata: metadata)
        } else {
            logger.notice("diagnostics.system_reports.stored", metadata: metadata)
        }
    }

    static func newestCohort<Element>(
        _ elements: [Element],
        limit: Int,
        periodStart: (Element) -> Date,
        periodEnd: (Element) -> Date
    ) -> [Element] {
        guard limit > 0 else {
            return []
        }

        var selected: [RankedElement<Element>] = []
        selected.reserveCapacity(min(limit, elements.count))

        for (offset, element) in elements.enumerated() {
            selected.append(
                RankedElement(
                    offset: offset,
                    element: element,
                    start: periodStart(element),
                    end: periodEnd(element)
                )
            )
            selected.sort { lhs, rhs in
                if lhs.end != rhs.end {
                    return lhs.end > rhs.end
                }
                if lhs.start != rhs.start {
                    return lhs.start > rhs.start
                }
                return lhs.offset < rhs.offset
            }
            if selected.count > limit {
                selected.removeLast()
            }
        }

        return selected.map(\.element)
    }

    static func consumeSerializedPayloads<Element>(
        _ payloads: [Element],
        maxTotalBytes: Int,
        serialize: (Element) -> Data,
        consume: (Element, Data) -> Void
    ) -> PayloadWorkSummary {
        guard maxTotalBytes > 0 else {
            return PayloadWorkSummary(
                consumedPayloadCount: 0,
                consumedBytes: 0,
                skippedPayloadCount: payloads.count,
                didReachByteBudget: !payloads.isEmpty
            )
        }

        var consumedPayloadCount = 0
        var consumedBytes = 0
        var remainingBytes = maxTotalBytes
        var skippedPayloadCount = 0
        var didReachByteBudget = false

        for (index, payload) in payloads.enumerated() {
            guard remainingBytes > 0 else {
                skippedPayloadCount = payloads.count - index
                didReachByteBudget = true
                break
            }

            let jsonData = serialize(payload)
            guard jsonData.count <= remainingBytes else {
                skippedPayloadCount += 1
                didReachByteBudget = true
                continue
            }

            consume(payload, jsonData)
            consumedPayloadCount += 1
            consumedBytes += jsonData.count
            remainingBytes -= jsonData.count
        }

        return PayloadWorkSummary(
            consumedPayloadCount: consumedPayloadCount,
            consumedBytes: consumedBytes,
            skippedPayloadCount: skippedPayloadCount,
            didReachByteBudget: didReachByteBudget
        )
    }

    private static func saturatingSum(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }
}

private extension NSLock {
    func metricKitWithLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
