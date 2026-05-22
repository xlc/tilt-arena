import AVFoundation
import Foundation

enum ArenaAudioCueFamily: String, CaseIterable, Equatable {
    case pickup
    case dangerPickup
    case enemyClear
    case majorEnemyClear
    case comboMilestone
    case nearMiss
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
    case dangerPickup
    case enemyClear(count: Int)
    case comboMilestone
    case nearMiss
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
        case .dangerPickup:
            return ArenaAudioCue(family: .dangerPickup, frequency: 420, duration: 0.12, volume: 0.22, cooldown: 0.08)
        case let .enemyClear(count) where count >= 8:
            return ArenaAudioCue(family: .majorEnemyClear, frequency: 210, duration: 0.18, volume: 0.24, cooldown: 0.18)
        case .enemyClear:
            return ArenaAudioCue(family: .enemyClear, frequency: 360, duration: 0.05, volume: 0.12, cooldown: 0.08)
        case .comboMilestone:
            return ArenaAudioCue(family: .comboMilestone, frequency: 860, duration: 0.11, volume: 0.2, cooldown: 0.16)
        case .nearMiss:
            return ArenaAudioCue(family: .nearMiss, frequency: 1_140, duration: 0.045, volume: 0.09, cooldown: 0.2)
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

@MainActor
final class ArenaAudioController {
    var isEnabled = true {
        didSet {
            if !isEnabled {
                stopMusic()
            }
        }
    }

    private let engine = AVAudioEngine()
    private let effectsNode = AVAudioPlayerNode()
    private let musicNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let sampleRate: Double
    private var effectBuffers: [ArenaAudioCueFamily: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var playbackLimiter = ArenaAudioPlaybackLimiter()
    private var isConfigured = false
    private var isMusicPlaying = false
    private var isMusicScheduled = false
    private var fallbackClock: TimeInterval = 0

    init(sampleRate: Double = 44_100) {
        self.sampleRate = sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            fatalError("Unable to create procedural audio format.")
        }
        self.format = format
        buildBuffers()
    }

    func startMusic() {
        guard
            isEnabled,
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
            configureEngineIfNeeded()
            isConfigured = true
            return true
        } catch {
            AppDiagnostics.logger(.app).warning("audio.session_failed", error: error)
            return false
        }
    }

    private func configureEngineIfNeeded() {
        guard effectsNode.engine == nil else {
            return
        }

        engine.attach(effectsNode)
        engine.attach(musicNode)
        engine.connect(effectsNode, to: engine.mainMixerNode, format: format)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)
        effectsNode.volume = 1
        engine.prepare()
    }

    private func startEngineIfNeeded() -> Bool {
        guard !engine.isRunning else {
            return true
        }

        do {
            try engine.start()
            return true
        } catch {
            AppDiagnostics.logger(.app).warning("audio.engine_failed", error: error)
            return false
        }
    }

    private func buildBuffers() {
        effectBuffers = Dictionary(
            uniqueKeysWithValues: ArenaAudioCueFamily.allCases.map { family in
                (family, makeEffectBuffer(for: family))
            }
        )
        musicBuffer = makeMusicBuffer()
    }

    private func makeEffectBuffer(for family: ArenaAudioCueFamily) -> AVAudioPCMBuffer {
        let cue = catalogCue(for: family)
        let frameCount = AVAudioFrameCount(max(1, Int(cue.duration * sampleRate)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Unable to create procedural SFX buffer.")
        }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else {
            return buffer
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

    private func makeMusicBuffer() -> AVAudioPCMBuffer {
        let duration = 2.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Unable to create procedural music buffer.")
        }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else {
            return buffer
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
        case .dangerPickup:
            return ArenaAudioCueCatalog.cue(for: .dangerPickup)
        case .enemyClear:
            return ArenaAudioCueCatalog.cue(for: .enemyClear(count: 1))
        case .majorEnemyClear:
            return ArenaAudioCueCatalog.cue(for: .enemyClear(count: 8))
        case .comboMilestone:
            return ArenaAudioCueCatalog.cue(for: .comboMilestone)
        case .nearMiss:
            return ArenaAudioCueCatalog.cue(for: .nearMiss)
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
        case .dangerPickup, .death, .shieldExpired:
            return 1 - progress * 0.45
        case .majorEnemyClear:
            return 0.8 + progress * 0.9
        case .enemyClear, .comboMilestone, .nearMiss, .shieldWarning:
            return 1
        }
    }
}
