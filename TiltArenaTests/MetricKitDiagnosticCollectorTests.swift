import Foundation
import XCTest
@testable import TiltArena

final class MetricKitDiagnosticCollectorTests: XCTestCase {
    func testMetricKitCohortSelectsNewestReportsInNewestFirstOrder() {
        let payloads = [
            DatedPayloadFixture(id: "oldest", start: 1, end: 2),
            DatedPayloadFixture(id: "newest", start: 9, end: 10),
            DatedPayloadFixture(id: "middle", start: 4, end: 5),
            DatedPayloadFixture(id: "same-end-older-start", start: 8, end: 10)
        ]

        let selected = MetricKitDiagnosticCollector.newestCohort(
            payloads,
            limit: 3,
            periodStart: \.periodStart,
            periodEnd: \.periodEnd
        )

        XCTAssertEqual(
            selected.map(\.id),
            ["newest", "same-end-older-start", "middle"]
        )
    }

    func testMetricKitSerializationSkipsNonFittingPayloadAndConsumesLaterSmallerPayload() {
        let payloads = [
            SerializedPayloadFixture(id: "newest", byteCount: 3),
            SerializedPayloadFixture(id: "middle", byteCount: 4),
            SerializedPayloadFixture(id: "oldest", byteCount: 1)
        ]
        var events: [String] = []

        let summary = MetricKitDiagnosticCollector.consumeSerializedPayloads(
            payloads,
            maxTotalBytes: 5,
            serialize: { payload in
                events.append("serialize-\(payload.id)")
                return Data(repeating: 0x78, count: payload.byteCount)
            },
            consume: { payload, _ in
                events.append("consume-\(payload.id)")
            }
        )

        XCTAssertEqual(
            events,
            [
                "serialize-newest",
                "consume-newest",
                "serialize-middle",
                "serialize-oldest",
                "consume-oldest"
            ]
        )
        XCTAssertEqual(
            summary,
            .init(
                consumedPayloadCount: 2,
                consumedBytes: 4,
                skippedPayloadCount: 1,
                didReachByteBudget: true
            )
        )
    }

    func testSerializationCountsEarlierSkipsWhenLaterPayloadExhaustsBudget() {
        var serializedSizes: [Int] = []
        var consumedSizes: [Int] = []

        let summary = MetricKitDiagnosticCollector.consumeSerializedPayloads(
            [3, 2, 1],
            maxTotalBytes: 2,
            serialize: { byteCount in
                serializedSizes.append(byteCount)
                return Data(repeating: 0x78, count: byteCount)
            },
            consume: { byteCount, _ in consumedSizes.append(byteCount) }
        )

        XCTAssertEqual(serializedSizes, [3, 2])
        XCTAssertEqual(consumedSizes, [2])
        XCTAssertEqual(
            summary,
            .init(
                consumedPayloadCount: 1,
                consumedBytes: 2,
                skippedPayloadCount: 2,
                didReachByteBudget: true
            )
        )
    }
}

private struct DatedPayloadFixture {
    let id: String
    let periodStart: Date
    let periodEnd: Date

    init(id: String, start: TimeInterval, end: TimeInterval) {
        self.id = id
        periodStart = Date(timeIntervalSince1970: start)
        periodEnd = Date(timeIntervalSince1970: end)
    }
}

private struct SerializedPayloadFixture {
    let id: String
    let byteCount: Int
}
