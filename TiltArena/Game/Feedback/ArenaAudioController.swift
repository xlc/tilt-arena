import AVFoundation
import Foundation
import Logging

enum ArenaAudioCueFamily: String, CaseIterable, Equatable {
    case pickup
    case enemyClear
    case majorEnemyClear
    case comboMilestone
    case shieldWarning
    case shieldExpired
    case death
    case newBest
}

struct ArenaAudioCue: Equatable {
    let family: ArenaAudioCueFamily
    let frequency: Double
    let duration: TimeInterval
    let volume: Float
    let cooldown: TimeInterval
}

enum ArenaAudioEvent: Equatable {
    case pickup
    case enemyClear(count: Int)
    case comboMilestone
    case shieldWarning
    case shieldExpired
    case death
    case newBest
}

enum ArenaAudioCueCatalog {
    static func cue(for event: ArenaAudioEvent) -> ArenaAudioCue {
        switch event {
        case .pickup:
            return ArenaAudioCue(family: .pickup, frequency: 760, duration: 0.07, volume: 0.16, cooldown: 0.04)
        case let .enemyClear(count) where count >= 8:
            return ArenaAudioCue(family: .majorEnemyClear, frequency: 210, duration: 0.18, volume: 0.24, cooldown: 0.18)
        case .enemyClear:
            return ArenaAudioCue(family: .enemyClear, frequency: 360, duration: 0.05, volume: 0.12, cooldown: 0.08)
        case .comboMilestone:
            return ArenaAudioCue(family: .comboMilestone, frequency: 860, duration: 0.11, volume: 0.2, cooldown: 0.16)
        case .shieldWarning:
            return ArenaAudioCue(family: .shieldWarning, frequency: 540, duration: 0.08, volume: 0.16, cooldown: 0.35)
        case .shieldExpired:
            return ArenaAudioCue(family: .shieldExpired, frequency: 260, duration: 0.13, volume: 0.2, cooldown: 0.2)
        case .death:
            return ArenaAudioCue(family: .death, frequency: 120, duration: 0.28, volume: 0.34, cooldown: 0.3)
        case .newBest:
            return ArenaAudioCue(family: .newBest, frequency: 1_280, duration: 0.16, volume: 0.22, cooldown: 0.25)
        }
    }
}

struct ArenaAudioPlaybackLimiter {
    private(set) var lastPlayedTimes: [ArenaAudioCueFamily: TimeInterval] = [:]

    mutating func cueIfAllowed(for event: ArenaAudioEvent, at time: TimeInterval) -> ArenaAudioCue? {
        guard time.isFinite else {
            return nil
        }

        let cue = ArenaAudioCueCatalog.cue(for: event)
        if let lastPlayedTime = lastPlayedTimes[cue.family], time - lastPlayedTime < cue.cooldown {
            return nil
        }

        lastPlayedTimes[cue.family] = time
        return cue
    }

    mutating func reset() {
        lastPlayedTimes.removeAll()
    }
}

struct ArenaAudioReadinessEpisodeGate {
    private(set) var isFailureActive = false

    mutating func beginFailureIfNeeded() -> Bool {
        guard !isFailureActive else {
            return false
        }

        isFailureActive = true
        return true
    }

    mutating func recoverIfNeeded() -> Bool {
        guard isFailureActive else {
            return false
        }

        isFailureActive = false
        return true
    }
}

@MainActor
final class ArenaAudioController {
    private static let maximumGeneratedBufferBytes = 8 * 1_024 * 1_024
    private static let maximumGeneratedBufferFrames = AVAudioFrameCount(
        maximumGeneratedBufferBytes / MemoryLayout<Float>.size
    )
    private static let longestGeneratedBufferDuration: TimeInterval = 2

    var isEnabled = true {
        didSet {
            if !isEnabled {
                effectsNode.stop()
                stopMusic()
                engine.stop()
            }
        }
    }

    private let engine = AVAudioEngine()
    private let effectsNode = AVAudioPlayerNode()
    private let musicNode = AVAudioPlayerNode()
    private let logger: Logger
    private let format: AVAudioFormat?
    private let sampleRate: Double
    private var effectBuffers: [ArenaAudioCueFamily: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var playbackLimiter = ArenaAudioPlaybackLimiter()
    private var sessionReadinessEpisode = ArenaAudioReadinessEpisodeGate()
    private var engineReadinessEpisode = ArenaAudioReadinessEpisodeGate()
    private var isConfigured = false
    private var isMusicPlaying = false
    private var isMusicScheduled = false
    private var fallbackClock: TimeInterval = 0

    init(
        sampleRate: Double = 44_100,
        logger: Logger = AppDiagnostics.logger(.app)
    ) {
        self.sampleRate = sampleRate
        self.logger = logger
        let maximumSampleRate = Double(Self.maximumGeneratedBufferFrames)
            / Self.longestGeneratedBufferDuration
        format = sampleRate.isFinite && sampleRate > 0 && sampleRate <= maximumSampleRate
            ? AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            : nil
        guard format != nil else {
            logger.error("audio.format_unavailable", metadata: [
                "sampleRate": "\(sampleRate)"
            ])
            return
        }

        buildBuffers()
    }

    func startMusic() {
        guard
            isEnabled,
            format != nil,
            configureAudioSessionIfNeeded(),
            startEngineIfNeeded()
        else {
            return
        }

        guard !isMusicPlaying else {
            return
        }

        if isMusicScheduled {
            musicNode.play()
            isMusicPlaying = true
            return
        }

        guard let musicBuffer else {
            return
        }

        musicNode.volume = 0.22
        musicNode.scheduleBuffer(musicBuffer, at: nil, options: [.loops])
        musicNode.play()
        isMusicScheduled = true
        isMusicPlaying = true
    }

    func pauseMusic() {
        guard isMusicPlaying else {
            return
        }

        musicNode.pause()
        isMusicPlaying = false
    }

    func stopMusic() {
        musicNode.stop()
        isMusicPlaying = false
        isMusicScheduled = false
    }

    func resetEventLimiter() {
        playbackLimiter.reset()
    }

    func play(_ event: ArenaAudioEvent, at time: TimeInterval? = nil) {
        guard
            isEnabled,
            format != nil,
            configureAudioSessionIfNeeded(),
            startEngineIfNeeded()
        else {
            return
        }

        let playbackTime = time ?? fallbackPlaybackTime()
        guard
            let cue = playbackLimiter.cueIfAllowed(for: event, at: playbackTime),
            let buffer = effectBuffers[cue.family]
        else {
            return
        }

        effectsNode.scheduleBuffer(buffer, at: nil, options: [])
        effectsNode.play()
    }

    private func configureAudioSessionIfNeeded() -> Bool {
        guard !isConfigured else {
            return true
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            if sessionReadinessEpisode.recoverIfNeeded() {
                logger.info("audio.session_recovered")
            }
            guard configureEngineIfNeeded() else {
                return false
            }

            isConfigured = true
            return true
        } catch {
            if sessionReadinessEpisode.beginFailureIfNeeded() {
                logger.warning("audio.session_failed", error: error)
            }
            return false
        }
    }

    private func configureEngineIfNeeded() -> Bool {
        guard effectsNode.engine == nil else {
            return true
        }
        guard let format else {
            return false
        }

        engine.attach(effectsNode)
        engine.attach(musicNode)
        engine.connect(effectsNode, to: engine.mainMixerNode, format: format)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)
        effectsNode.volume = 1
        engine.prepare()
        return true
    }

    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else {
            if engineReadinessEpisode.recoverIfNeeded() {
                logger.info("audio.engine_recovered")
            }
            return true
        }

        do {
            try engine.start()
            if engineReadinessEpisode.recoverIfNeeded() {
                logger.info("audio.engine_recovered")
            }
            return true
        } catch {
            if engineReadinessEpisode.beginFailureIfNeeded() {
                logger.warning("audio.engine_failed", error: error)
            }
            return false
        }
    }

    private func buildBuffers() {
        effectBuffers = Dictionary(uniqueKeysWithValues: ArenaAudioCueFamily.allCases.compactMap { family in
            guard let buffer = makeEffectBuffer(for: family) else {
                logger.error("audio.effect_buffer_unavailable", metadata: [
                    "family": "\(family.rawValue)"
                ])
                return nil
            }

            return (family, buffer)
        })
        musicBuffer = makeMusicBuffer()
        if musicBuffer == nil {
            logger.error("audio.music_buffer_unavailable")
        }
    }

    private func makeEffectBuffer(for family: ArenaAudioCueFamily) -> AVAudioPCMBuffer? {
        guard let format else {
            return nil
        }

        let cue = catalogCue(for: family)
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

    private func makeMusicBuffer() -> AVAudioPCMBuffer? {
        guard let format else {
            return nil
        }

        let duration = 2.0
        guard let frameCount = audioFrameCount(duration: duration) else {
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

    private func fallbackPlaybackTime() -> TimeInterval {
        if let renderTime = engine.outputNode.lastRenderTime {
            let seconds = Double(renderTime.sampleTime) / max(1, sampleRate)
            return seconds
        }

        fallbackClock += 0.03
        return fallbackClock
    }

    private func catalogCue(for family: ArenaAudioCueFamily) -> ArenaAudioCue {
        switch family {
        case .pickup:
            return ArenaAudioCueCatalog.cue(for: .pickup)
        case .enemyClear:
            return ArenaAudioCueCatalog.cue(for: .enemyClear(count: 1))
        case .majorEnemyClear:
            return ArenaAudioCueCatalog.cue(for: .enemyClear(count: 8))
        case .comboMilestone:
            return ArenaAudioCueCatalog.cue(for: .comboMilestone)
        case .shieldWarning:
            return ArenaAudioCueCatalog.cue(for: .shieldWarning)
        case .shieldExpired:
            return ArenaAudioCueCatalog.cue(for: .shieldExpired)
        case .death:
            return ArenaAudioCueCatalog.cue(for: .death)
        case .newBest:
            return ArenaAudioCueCatalog.cue(for: .newBest)
        }
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
