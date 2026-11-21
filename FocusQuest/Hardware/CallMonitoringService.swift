import CallKit
import Foundation
import UIKit

/// Hlida telefonni hovory (i FaceTime a VoIP pres CallKit) behem bitvy.
/// Stream hlasi `true`, kdyz nejaky hovor zvoni nebo bezi, a `false`, kdyz vsechny skoncily.
@MainActor
protocol CallMonitoringServiceProtocol: AnyObject {
    func callUpdates() -> AsyncStream<Bool>
    func stop()
}

@MainActor
final class CallMonitoringService: NSObject, CallMonitoringServiceProtocol, CXCallObserverDelegate {
    private let observer = CXCallObserver()
    private var continuation: AsyncStream<Bool>.Continuation?
    private var activeObserver: (any NSObjectProtocol)?

    func callUpdates() -> AsyncStream<Bool> {
        stop()
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.continuation = continuation
        observer.setDelegate(self, queue: .main)
        continuation.yield(hasActiveCall)
        // Kdyz byla appka behem hovoru uspana, zmena prijde az po navratu: stav se zkontroluje znovu.
        activeObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                self.continuation?.yield(self.hasActiveCall)
            }
        }
        return stream
    }

    func stop() {
        continuation?.finish()
        continuation = nil
        observer.setDelegate(nil, queue: nil)
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        activeObserver = nil
    }

    private var hasActiveCall: Bool { observer.calls.contains { !$0.hasEnded } }

    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        // Delegat bezi na hlavni fronte (setDelegate(queue: .main)).
        let active = callObserver.calls.contains { !$0.hasEnded }
        MainActor.assumeIsolated { continuation?.yield(active) }
    }
}
