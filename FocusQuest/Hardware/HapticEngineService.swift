import Foundation
import UIKit

@MainActor
protocol HapticEngineServiceProtocol: AnyObject {
    func prepare()
    func triggerPickupWarningInitial(enabled: Bool)
    func triggerCountdownPulse(enabled: Bool)
    func triggerRecovery(enabled: Bool)
    func triggerPenaltyFailure(enabled: Bool)
    func triggerBossDamageHit(enabled: Bool)
}

@MainActor
final class HapticEngineService: HapticEngineServiceProtocol {
    private let warning = UINotificationFeedbackGenerator()
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    func prepare() {
        warning.prepare()
        heavy.prepare()
        light.prepare()
        rigid.prepare()
    }

    func triggerPickupWarningInitial(enabled: Bool) { if enabled { warning.notificationOccurred(.warning); warning.prepare() } }
    func triggerCountdownPulse(enabled: Bool) { if enabled { heavy.impactOccurred(intensity: 1); heavy.prepare() } }
    func triggerRecovery(enabled: Bool) { if enabled { light.impactOccurred(intensity: 0.45); light.prepare() } }
    func triggerPenaltyFailure(enabled: Bool) { if enabled { warning.notificationOccurred(.error); warning.prepare() } }
    func triggerBossDamageHit(enabled: Bool) { if enabled { rigid.impactOccurred(intensity: 0.85); rigid.prepare() } }
}