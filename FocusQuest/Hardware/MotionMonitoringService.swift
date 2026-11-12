import Foundation
@preconcurrency import CoreMotion

enum DevicePostureState: Sendable, Equatable { case flatFaceUp, liftedOrTilted, unavailable }

protocol MotionMonitoringServiceProtocol: Sendable {
    func postureUpdates() async -> AsyncStream<DevicePostureState>
}

actor MotionMonitoringService: MotionMonitoringServiceProtocol {
    private let manager = CMMotionManager()
    #if targetEnvironment(simulator)
    private var simulatedState: DevicePostureState = .flatFaceUp
    #endif

    func postureUpdates() async -> AsyncStream<DevicePostureState> {
        AsyncStream { continuation in
            #if targetEnvironment(simulator)
            continuation.yield(simulatedState)
            #else
            guard manager.isDeviceMotionAvailable else {
                continuation.yield(.unavailable)
                continuation.finish()
                return
            }
            manager.deviceMotionUpdateInterval = 0.1
            manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, _ in
                guard let motion else { continuation.yield(.unavailable); return }
                let attitude = motion.attitude
                let flat = abs(attitude.pitch) < 0.15 && abs(attitude.roll) < 0.15 && motion.gravity.z < -0.92
                continuation.yield(flat ? .flatFaceUp : .liftedOrTilted)
            }
            continuation.onTermination = { [weak self] _ in Task { await self?.stop() } }
            #endif
        }
    }

    #if targetEnvironment(simulator)
    func setSimulatedPosture(_ posture: DevicePostureState) { simulatedState = posture }
    #endif

    private func stop() { manager.stopDeviceMotionUpdates() }
}