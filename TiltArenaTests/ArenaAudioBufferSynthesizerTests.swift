import AVFoundation
import XCTest
@testable import TiltArena

final class ArenaAudioBufferSynthesizerTests: XCTestCase {
    func testEffectBuffersPreserveMonoFormatDurationAndSilentEdges() throws {
        let synthesizer = try XCTUnwrap(ArenaAudioBufferSynthesizer(sampleRate: 8_000))
        let expectedFrameCounts: [ArenaAudioCueFamily: AVAudioFrameCount] = [
            .pickup: 560,
            .enemyClear: 400,
            .majorEnemyClear: 1_440,
            .comboMilestone: 880,
            .shieldWarning: 640,
            .shieldExpired: 1_040,
            .death: 2_240,
            .newBest: 1_280
        ]

        for family in ArenaAudioCueFamily.allCases {
            let buffer = try XCTUnwrap(synthesizer.makeEffectBuffer(for: family))
            let channel = try XCTUnwrap(buffer.floatChannelData?[0])

            XCTAssertEqual(buffer.frameLength, expectedFrameCounts[family])
            XCTAssertEqual(buffer.format.sampleRate, 8_000)
            XCTAssertEqual(buffer.format.channelCount, 1)
            XCTAssertEqual(buffer.format.commonFormat, .pcmFormatFloat32)
            XCTAssertEqual(channel[0], 0)
            XCTAssertEqual(channel[Int(buffer.frameLength) - 1], 0)
        }
    }

    func testEffectSamplesPreservePitchBendEnvelopeAndAmplitude() throws {
        let synthesizer = try XCTUnwrap(ArenaAudioBufferSynthesizer(sampleRate: 8_000))
        // Characterization values cover rising, falling, sweeping, and steady pitch cues.
        let expectedSamples: [ArenaAudioCueFamily: [(Int, Float)]] = [
            .pickup: [(1, 0.141960934), (186, -0.051067166), (280, 0.057701934)],
            .death: [(1, 0.054370206), (746, 0.036749426), (1_120, 0.071039319)],
            .majorEnemyClear: [(1, 0.053597189), (480, -0.163790986), (720, -0.087390378)],
            .comboMilestone: [(1, 0.193244189), (293, 0.045486577), (440, 0.110476367)]
        ]

        for (family, samples) in expectedSamples {
            let buffer = try XCTUnwrap(synthesizer.makeEffectBuffer(for: family))
            let channel = try XCTUnwrap(buffer.floatChannelData?[0])
            for (frame, expected) in samples {
                XCTAssertEqual(channel[frame], expected, accuracy: 0.000_000_1)
            }
        }
    }

    func testMusicBufferPreservesLoopLengthAndBeatSamples() throws {
        let synthesizer = try XCTUnwrap(ArenaAudioBufferSynthesizer(sampleRate: 8_000))
        let buffer = try XCTUnwrap(synthesizer.makeMusicBuffer())
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])

        XCTAssertEqual(buffer.frameLength, 16_000)
        let expectedSamples: [(Int, Float)] = [
            (0, 0),
            (1, 0.054173920),
            (537, 0.000681320),
            (1_001, 0.034745462),
            (4_001, 0.054173920),
            (15_773, 0.000088836)
        ]
        for (frame, expected) in expectedSamples {
            XCTAssertEqual(channel[frame], expected, accuracy: 0.000_000_1)
        }
    }

    func testInvalidOrUnboundedSampleRatesAreRejectedBeforeAllocation() {
        for sampleRate in [-1, 0, Double.nan, Double.infinity, Double.greatestFiniteMagnitude, 1_048_577] {
            XCTAssertNil(ArenaAudioBufferSynthesizer(sampleRate: sampleRate))
        }
        XCTAssertNotNil(ArenaAudioBufferSynthesizer(sampleRate: 1_048_576))
    }

    func testBuffersShorterThanOneFrameAreRejected() throws {
        let synthesizer = try XCTUnwrap(ArenaAudioBufferSynthesizer(sampleRate: 1))

        for family in ArenaAudioCueFamily.allCases {
            XCTAssertNil(synthesizer.makeEffectBuffer(for: family))
        }
        XCTAssertEqual(try XCTUnwrap(synthesizer.makeMusicBuffer()).frameLength, 2)
    }
}
