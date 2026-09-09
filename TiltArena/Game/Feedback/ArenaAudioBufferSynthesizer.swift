import AVFoundation
import Foundation

/// Owns procedural audio generation independently of the audio session and playback engine.
struct ArenaAudioBufferSynthesizer {
    private static let maximumGeneratedBufferBytes = 8 * 1_024 * 1_024
    private static let maximumGeneratedBufferFrames = AVAudioFrameCount(
        maximumGeneratedBufferBytes / MemoryLayout<Float>.size
    )
    private static let musicDuration: TimeInterval = 2

    let format: AVAudioFormat
    private let sampleRate: Double

    init?(sampleRate: Double) {
        let maximumSampleRate = Double(Self.maximumGeneratedBufferFrames) / Self.musicDuration
        guard
            sampleRate.isFinite,
            sampleRate > 0,
            sampleRate <= maximumSampleRate,
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else {
            return nil
        }

        self.sampleRate = sampleRate
        self.format = format
    }

    func makeEffectBuffer(for family: ArenaAudioCueFamily) -> AVAudioPCMBuffer? {
        let cue = ArenaAudioCueCatalog.cue(forFamily: family)
        guard let frameCount = audioFrameCount(duration: cue.duration) else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = Double(frame) / Double(max(1, Int(frameCount) - 1))
            let envelope = max(0, 1 - progress)
            let bend = pitchBend(for: family, progress: progress)
            let tone = sin(2 * .pi * cue.frequency * bend * time)
            let overtone = 0.35 * sin(2 * .pi * cue.frequency * 2.01 * bend * time)
            channel[frame] = Float((tone + overtone) * envelope * Double(cue.volume))
        }

        return buffer
    }

    func makeMusicBuffer() -> AVAudioPCMBuffer? {
        guard let frameCount = audioFrameCount(duration: Self.musicDuration) else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        let beatDuration = 0.125
        let bassFrequencies = [110.0, 146.83, 164.81, 196.0]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let beat = Int(time / beatDuration)
            let beatProgress = (time.truncatingRemainder(dividingBy: beatDuration)) / beatDuration
            let bass = sin(2 * .pi * bassFrequencies[beat % bassFrequencies.count] * time)
            let pulse = sin(2 * .pi * (beat.isMultiple(of: 4) ? 880 : 660) * time)
            let envelope = exp(-beatProgress * 9)
            let kick = beat.isMultiple(of: 4) ? sin(2 * .pi * 70 * time) * exp(-beatProgress * 16) : 0
            channel[frame] = Float((bass * 0.09 + pulse * 0.06 + kick * 0.16) * envelope)
        }

        return buffer
    }

    private func audioFrameCount(duration: TimeInterval) -> AVAudioFrameCount? {
        let frameCount = duration * sampleRate
        guard
            frameCount.isFinite,
            frameCount >= 1,
            frameCount <= Double(Self.maximumGeneratedBufferFrames)
        else {
            return nil
        }

        return AVAudioFrameCount(frameCount.rounded(.down))
    }

    private func pitchBend(for family: ArenaAudioCueFamily, progress: Double) -> Double {
        switch family {
        case .pickup, .newBest:
            return 1 + progress * 0.5
        case .death, .shieldExpired:
            return 1 - progress * 0.45
        case .majorEnemyClear:
            return 0.8 + progress * 0.9
        case .enemyClear, .comboMilestone, .shieldWarning:
            return 1
        }
    }
}
