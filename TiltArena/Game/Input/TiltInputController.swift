import CoreMotion
import CoreGraphics
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

    func recalibrateToCurrentAttitude() {
        guard let gravity = currentGravityVector() else {
            return
        }

        settingsStore.recalibrate(using: gravity)
        signalProcessor.reset()
    }

    func update(deltaTime: TimeInterval) -> CGVector {
        guard let gravity = currentGravityVector() else {
            return .zero
        }

        settingsStore.ensureInitialCalibration(using: gravity)

        return signalProcessor.inputVector(
            gravity: gravity,
            settings: settingsStore.settings,
            deltaTime: deltaTime
        )
    }

    private func currentGravityVector() -> TiltGravityVector? {
        guard let gravity = motionManager.deviceMotion?.gravity else {
            return nil
        }

        return TiltGravityVector(x: gravity.x, y: gravity.y)
    }
}
