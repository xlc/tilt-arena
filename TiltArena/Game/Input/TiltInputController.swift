import CoreGraphics
import CoreMotion
import Foundation

@MainActor
final class TiltInputController {
    private let motionManager: CMMotionManager
    private let settingsStore: TiltSettingsStore
    private var signalProcessor = TiltSignalProcessor()

    init(
        motionManager: CMMotionManager = CMMotionManager(),
        settingsStore: TiltSettingsStore = TiltSettingsStore()
    ) {
        self.motionManager = motionManager
        self.settingsStore = settingsStore
        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else {
            return
        }

        motionManager.startDeviceMotionUpdates()
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        signalProcessor.reset()
    }

    func resetSmoothedInput() {
        signalProcessor.reset()
    }

    func recalibrateToCurrentAttitude(orientation: TiltScreenOrientation) {
        guard let rawGravity = currentGravityVector() else {
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
            return nil
        }

        return TiltGravityVector(x: gravity.x, y: gravity.y)
    }
}
