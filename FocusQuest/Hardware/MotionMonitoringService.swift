import Foundation
@preconcurrency import CoreMotion

/// Poloha telefonu pro bitvu. `lyingStill` = lezi naplocho na stole (displejem dolu i nahoru).
enum DevicePostureState: Sendable, Equatable { case lyingStill, lifted, unavailable }

protocol MotionMonitoringServiceProtocol: Sendable {
    func postureUpdates() async -> AsyncStream<DevicePostureState>
}

/// Rozhodovani nad vzorky gravitace (osa z). Oddelene od CoreMotion, aby slo testovat bez senzoru.
///
/// - Lezi: |z| > 0,9 nepretrzite aspon 1 s (displejem dolu z ≈ +1, nahoru z ≈ -1).
/// - Zvednuty: |z| < 0,7 nepretrzite aspon 0,5 s.
/// - Mezi 0,7 a 0,9 se stav nemeni (hystereze), takze drobne nakloneni nic nespusti.
struct PostureDetector {
    static let flatThreshold = 0.9
    static let liftedThreshold = 0.7
    static let flatDuration: TimeInterval = 1.0
    static let liftedDuration: TimeInterval = 0.5
    /// Casy vzorku nejsou presne po 0,1 s; tolerance zabrani zpozdeni o cely dalsi vzorek.
    static let tolerance: TimeInterval = 0.001

    private(set) var state: DevicePostureState?
    private var flatSince: TimeInterval?
    private var liftedSince: TimeInterval?

    /// Vzorek osy z gravitace (v g) v case `time` (sekundy). Vrati novy stav jen pri zmene.
    mutating func update(gravityZ: Double, at time: TimeInterval) -> DevicePostureState? {
        let z = abs(gravityZ)
        if z > Self.flatThreshold {
            liftedSince = nil
            let since = flatSince ?? time
            flatSince = since
            if time - since + Self.tolerance >= Self.flatDuration { return change(to: .lyingStill) }
        } else if z < Self.liftedThreshold {
            flatSince = nil
            let since = liftedSince ?? time
            liftedSince = since
            if time - since + Self.tolerance >= Self.liftedDuration { return change(to: .lifted) }
        } else {
            flatSince = nil
            liftedSince = nil
        }
        return nil
    }

    private mutating func change(to new: DevicePostureState) -> DevicePostureState? {
        guard new != state else { return nil }
        state = new
        return new
    }
}

/// Zadna gravitace bez deviceMotion: akcelerometr meri gravitaci + pohyb, proto se vyhlazuje.
struct GravityLowPass {
    static let factor = 0.2
    private var value: Double?

    mutating func filter(_ sample: Double) -> Double {
        let next = value.map { $0 + Self.factor * (sample - $0) } ?? sample
        value = next
        return next
    }
}

/// Drzi stav detektoru mezi vzorky. Vzorky chodi jen na hlavni frontu, takze zamek neni potreba.
private final class PostureTracker: @unchecked Sendable {
    private var detector = PostureDetector()
    private var lowPass = GravityLowPass()

    func gravity(_ z: Double, at time: TimeInterval) -> DevicePostureState? {
        detector.update(gravityZ: z, at: time)
    }

    func acceleration(_ z: Double, at time: TimeInterval) -> DevicePostureState? {
        detector.update(gravityZ: lowPass.filter(z), at: time)
    }
}

/// Snima polohu telefonu pres CMMotionManager (~10 Hz). Senzor bezi od obrazovky "Lay the phone…"
/// do konce bitvy nebo zavreni; konec streamu ho vypne. Kazde spusteni ma vlastni cislo, aby
/// opozdene vypnuti stareho streamu nezastavilo novy (driv kvuli tomu druha bitva nezacala).
actor MotionMonitoringService: MotionMonitoringServiceProtocol {
    static let updateInterval: TimeInterval = 0.1

    private let manager = CMMotionManager()
    private var generation = 0
    #if targetEnvironment(simulator)
    private var simulatedState: DevicePostureState = .lyingStill
    #endif

    func postureUpdates() async -> AsyncStream<DevicePostureState> {
        #if targetEnvironment(simulator)
        let state = simulatedState
        return AsyncStream { $0.yield(state) }
        #else
        stopSensors()
        generation += 1
        let current = generation
        let (stream, continuation) = AsyncStream<DevicePostureState>.makeStream()
        let tracker = PostureTracker()

        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = Self.updateInterval
            manager.startDeviceMotionUpdates(to: .main) { @Sendable motion, _ in
                guard let motion else { return }
                if let state = tracker.gravity(motion.gravity.z, at: motion.timestamp) { continuation.yield(state) }
            }
        } else if manager.isAccelerometerAvailable {
            manager.accelerometerUpdateInterval = Self.updateInterval
            manager.startAccelerometerUpdates(to: .main) { @Sendable data, _ in
                guard let data else { return }
                if let state = tracker.acceleration(data.acceleration.z, at: data.timestamp) { continuation.yield(state) }
            }
        } else {
            continuation.yield(.unavailable)
            continuation.finish()
            return stream
        }
        continuation.onTermination = { [weak self] _ in Task { await self?.stop(generation: current) } }
        return stream
        #endif
    }

    #if targetEnvironment(simulator)
    func setSimulatedPosture(_ posture: DevicePostureState) { simulatedState = posture }
    #endif

    /// Vypne senzor jen tehdy, kdyz mezitim nezacal novy stream.
    private func stop(generation ended: Int) {
        guard ended == generation else { return }
        stopSensors()
    }

    private func stopSensors() {
        manager.stopDeviceMotionUpdates()
        manager.stopAccelerometerUpdates()
    }
}
