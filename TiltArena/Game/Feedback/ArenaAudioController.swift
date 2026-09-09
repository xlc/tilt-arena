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
        cue(forFamily: family(for: event))
    }

    static func cue(forFamily family: ArenaAudioCueFamily) -> ArenaAudioCue {
        switch family {
        case .pickup:
            return ArenaAudioCue(family: family, frequency: 760, duration: 0.07, volume: 0.16, cooldown: 0.04)
        case .majorEnemyClear:
            return ArenaAudioCue(family: family, frequency: 210, duration: 0.18, volume: 0.24, cooldown: 0.18)
        case .enemyClear:
            return ArenaAudioCue(family: family, frequency: 360, duration: 0.05, volume: 0.12, cooldown: 0.08)
        case .comboMilestone:
            return ArenaAudioCue(family: family, frequency: 860, duration: 0.11, volume: 0.2, cooldown: 0.16)
        case .shieldWarning:
            return ArenaAudioCue(family: family, frequency: 540, duration: 0.08, volume: 0.16, cooldown: 0.35)
        case .shieldExpired:
            return ArenaAudioCue(family: family, frequency: 260, duration: 0.13, volume: 0.2, cooldown: 0.2)
        case .death:
            return ArenaAudioCue(family: family, frequency: 120, duration: 0.28, volume: 0.34, cooldown: 0.3)
        case .newBest:
            return ArenaAudioCue(family: family, frequency: 1_280, duration: 0.16, volume: 0.22, cooldown: 0.25)
        }
    }

    private static func family(for event: ArenaAudioEvent) -> ArenaAudioCueFamily {
        switch event {
        case .pickup:
            return .pickup
        case let .enemyClear(count) where count >= 8:
            return .majorEnemyClear
        case .enemyClear:
            return .enemyClear
        case .comboMilestone:
            return .comboMilestone
        case .shieldWarning:
            return .shieldWarning
        case .shieldExpired:
            return .shieldExpired
        case .death:
            return .death
        case .newBest:
            return .newBest
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
        let synthesizer = ArenaAudioBufferSynthesizer(sampleRate: sampleRate)
        format = synthesizer?.format
        guard let synthesizer else {
            logger.error("audio.format_unavailable", metadata: [
                "sampleRate": "\(sampleRate)"
            ])
            return
        }

        buildBuffers(using: synthesizer)
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

    private func buildBuffers(using synthesizer: ArenaAudioBufferSynthesizer) {
        effectBuffers = Dictionary(uniqueKeysWithValues: ArenaAudioCueFamily.allCases.compactMap { family in
            guard let buffer = synthesizer.makeEffectBuffer(for: family) else {
                logger.error("audio.effect_buffer_unavailable", metadata: [
                    "family": "\(family.rawValue)"
                ])
                return nil
            }

            return (family, buffer)
        })
        musicBuffer = synthesizer.makeMusicBuffer()
        if musicBuffer == nil {
            logger.error("audio.music_buffer_unavailable")
        }
    }

    private func fallbackPlaybackTime() -> TimeInterval {
        if let renderTime = engine.outputNode.lastRenderTime {
            let seconds = Double(renderTime.sampleTime) / max(1, sampleRate)
            return seconds
        }

        fallbackClock += 0.03
        return fallbackClock
    }
}
