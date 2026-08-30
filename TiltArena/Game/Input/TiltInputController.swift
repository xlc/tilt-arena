import CoreGraphics
import CoreMotion
import Foundation
import Logging

@MainActor
final class TiltInputController {
    private enum MotionState: String, Hashable {
        case idle
        case unavailable
        case waitingForSample = "waiting_for_sample"
        case active
        case invalidSample = "invalid_sample"
    }

    private let motionManager: CMMotionManager
    private let settingsStore: TiltSettingsStore
    private let logger: Logger
    private let uptimeProvider: () -> TimeInterval
    private var signalProcessor = TiltSignalProcessor()
    private var motionState = MotionState.idle
    private var lastLogTimeByState: [MotionState: TimeInterval] = [:]
    private var suppressedLogCountByState: [MotionState: Int] = [:]
    private static let recurringStateLogInterval: TimeInterval = 5

    init(
        motionManager: CMMotionManager = CMMotionManager(),
        settingsStore: TiltSettingsStore = TiltSettingsStore(),
        logger: Logger = AppDiagnostics.logger(.input),
        uptimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.motionManager = motionManager
        self.settingsStore = settingsStore
        self.logger = logger
        self.uptimeProvider = uptimeProvider
        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            transition(to: .unavailable, level: .warning, event: "input.motion_unavailable")
            return
        }
        guard !motionManager.isDeviceMotionActive else {
            return
        }

        motionManager.startDeviceMotionUpdates()
        transition(to: .waitingForSample, level: .info, event: "input.motion_started")
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        signalProcessor.reset()
        transition(to: .idle, level: .info, event: "input.motion_stopped")
    }

    func resetSmoothedInput() {
        signalProcessor.reset()
    }

    func recalibrateToCurrentAttitude(orientation: TiltScreenOrientation) {
        guard let rawGravity = currentGravityVector() else {
            logger.warning("input.calibration_skipped", metadata: [
                "reason": "motion_sample_unavailable"
            ])
            return
        }

        let screenGravity = TiltGravityMapper.screenGravity(
            from: rawGravity,
            orientation: orientation
        )
        settingsStore.recalibrate(using: screenGravity)
        signalProcessor.reset()
    }

    func update(deltaTime: TimeInterval, orientation: TiltScreenOrientation) -> CGVector {
        guard let rawGravity = currentGravityVector() else {
            return .zero
        }

        let screenGravity = TiltGravityMapper.screenGravity(
            from: rawGravity,
            orientation: orientation
        )
        settingsStore.ensureInitialCalibration(using: screenGravity)

        return signalProcessor.inputVector(
            gravity: screenGravity,
            settings: settingsStore.settings,
            deltaTime: deltaTime
        )
    }

    func readout(orientation: TiltScreenOrientation) -> TiltInputReadout? {
        guard let rawGravity = currentGravityVector() else {
            return nil
        }

        let settings = settingsStore.settings
        let screenGravity = TiltGravityMapper.screenGravity(
            from: rawGravity,
            orientation: orientation
        )
        let normalizedInput = signalProcessor.normalizedInputVector(
            gravity: screenGravity,
            settings: settings
        )

        return TiltInputReadout(
            orientation: orientation,
            rawGravity: rawGravity,
            screenGravity: screenGravity,
            neutralGravity: settings.calibration.neutralGravity,
            normalizedInput: normalizedInput
        )
    }

    private func currentGravityVector() -> TiltGravityVector? {
        guard let gravity = motionManager.deviceMotion?.gravity else {
            transition(to: .waitingForSample, level: .info, event: "input.motion_sample_waiting")
            return nil
        }

        let vector = TiltGravityVector(x: gravity.x, y: gravity.y)
        guard vector.isFinite else {
            transition(to: .invalidSample, level: .warning, event: "input.motion_sample_invalid")
            return nil
        }

        transition(to: .active, level: .info, event: "input.motion_sample_active")
        return vector
    }

    private func transition(to state: MotionState, level: Logger.Level, event: Logger.Message) {
        guard motionState != state else {
            return
        }

        let previousState = motionState
        motionState = state
        let now = uptimeProvider()
        if let lastLogTime = lastLogTimeByState[state],
           now.isFinite,
           now >= lastLogTime,
           now - lastLogTime < Self.recurringStateLogInterval {
            let currentCount = suppressedLogCountByState[state, default: 0]
            suppressedLogCountByState[state] = currentCount == Int.max ? Int.max : currentCount + 1
            return
        }

        var metadata: Logger.Metadata = [
            "from": "\(previousState.rawValue)",
            "to": "\(state.rawValue)"
        ]
        if let suppressedCount = suppressedLogCountByState.removeValue(forKey: state),
           suppressedCount > 0 {
            metadata["suppressedTransitions"] = "\(suppressedCount)"
        }
        if now.isFinite {
            lastLogTimeByState[state] = now
        }
        logger.log(level: level, event, metadata: metadata)
    }
}
