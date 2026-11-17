import Foundation
@preconcurrency import CoreMotion

/// Poloha telefonu pro bitvu. `lyingStill` = displejem dolu na stole a v klidu.
enum DevicePostureState: Sendable, Equatable { case lyingStill, lifted, unavailable }

protocol MotionMonitoringServiceProtocol: Sendable {
    func postureUpdates() async -> AsyncStream<DevicePostureState>
}

/// Rozhodovani nad jednim vzorkem senzoru. Oddelene od CoreMotion, aby slo testovat.
struct PostureDetector {
    /// Displejem dolu: gravitace miri do zad telefonu (asi do 14 stupnu od vodorovne polohy).
    static let faceDownGravityZ = 0.97
    /// Telefon "lezi v klidu", kdyz se tolik vzorku po sobe skoro nehybe (0,1 s na vzorek).
    static let stillSamplesNeeded = 5
    static let maxStillAcceleration = 0.05
    static let maxStillRotation = 0.3

    private var stillSamples = 0

    /// Vrati novy stav, nebo nil, kdyz se nema nic hlasit (lezi dolu, ale jeste se hybe).
    mutating func update(gravityZ: Double, acceleration: Double, rotation: Double) -> DevicePostureState? {
        guard gravityZ > Self.faceDownGravityZ else {
            stillSamples = 0
            return .lifted
        }
        let calm = acceleration < Self.maxStillAcceleration && rotation < Self.maxStillRotation
        stillSamples = calm ? stillSamples + 1 : 0
        return stillSamples >= Self.stillSamplesNeeded ? .lyingStill : nil
    }
}

/// Drzi stav detektoru mezi vzorky. Vzorky chodi jen na hlavni frontu, takze zamek neni potreba.
private final class PostureTracker: @unchecked Sendable {
    private var detector = PostureDetector()
    private var last: DevicePostureState?

    /// Hlasi jen zmeny stavu.
    func next(gravityZ: Double, acceleration: Double, rotation: Double) -> DevicePostureState? {
        guard let state = detector.update(gravityZ: gravityZ, acceleration: acceleration, rotation: rotation), state != last else { return nil }
        last = state
        return state
    }
}

actor MotionMonitoringService:MotionMonitoringServiceProtocol {
    private let manager = CMMotionManager()
    #if targetEnvironment(simulator)
    private var simulatedState: DevicePostureState = .lyingStill
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
            let tracker = PostureTracker()
            manager.deviceMotionUpdateInterval = 0.1
            manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, _ in
                guard let motion else { continuation.yield(.unavailable); return }
                let a = motion.userAcceleration, r = motion.rotationRate
                let acceleration = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                let rotation = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
                if let state = tracker.next(gravityZ: motion.gravity.z, acceleration: acceleration, rotation: rotation) { continuation.yield(state) }
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
