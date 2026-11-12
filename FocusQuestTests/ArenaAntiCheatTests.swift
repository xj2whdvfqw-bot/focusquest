import XCTest
@testable import FocusQuest

@MainActor
final class ArenaAntiCheatTests: XCTestCase {
    func testReturningFlatRecoversFocusBeforeGraceExpires() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.flatFaceUp)
        await rig.model.handlePosture(.liftedOrTilted)
        XCTAssertTrue(isWarning(rig.model.state))
        await rig.model.handlePosture(.flatFaceUp)
        XCTAssertTrue(isFocusing(rig.model.state))
        XCTAssertEqual(rig.haptics.warningCount, 0)
        XCTAssertGreaterThan(rig.audio.warningCount, 0)
    }

    func testWarningExpiryReportsPenaltyAndResetsCombo() async {
        let rig = makeRig(hapticsEnabled: true)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.flatFaceUp)
        await rig.model.handlePosture(.liftedOrTilted)
        for _ in 0..<65 {
            if case .penalized = rig.model.state { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard case .penalized = rig.model.state else { return XCTFail("Warning did not expire") }
        let violationCount = await rig.validation.violationCount()
        XCTAssertEqual(violationCount, 1)
        XCTAssertEqual(rig.model.activeSession?.comboMultiplier, 1)
    }

    func testChronosShieldAddsOneGraceSecondOncePerSession() {
        XCTAssertEqual(AntiCheatRules.warningDuration(equippedLootIDs: ["chronos-shield"], graceAlreadyUsed: false), 6)
        XCTAssertEqual(AntiCheatRules.warningDuration(equippedLootIDs: ["chronos-shield"], graceAlreadyUsed: true), 5)
        XCTAssertEqual(AntiCheatRules.warningDuration(equippedLootIDs: [], graceAlreadyUsed: false), 5)
    }

    func testMutedHapticsDoNotDisableVisualWarning() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.flatFaceUp)
        await rig.model.handlePosture(.liftedOrTilted)
        XCTAssertTrue(isWarning(rig.model.state))
        XCTAssertEqual(rig.haptics.warningCount, 0)
        XCTAssertEqual(rig.audio.warningCount, 1)
    }

    func testWallClockDivergenceOverTwoSecondsIsTampering() {
        XCTAssertFalse(AntiCheatRules.clockIsTampered(wallDelta: 30, monotonicDelta: 31.9))
        XCTAssertTrue(AntiCheatRules.clockIsTampered(wallDelta: 30, monotonicDelta: 32.1))
        XCTAssertTrue(AntiCheatRules.clockIsTampered(wallDelta: .infinity, monotonicDelta: 10))
    }

    private func makeRig(hapticsEnabled: Bool) -> Rig {
        let prefs = AppPreferences(isHapticsEnabled: hapticsEnabled, isMusicEnabled: true, isSFXEnabled: true, ambientVolume: 0.5, selectedTrack: .calmCurrents)
        let validation = ValidationSpy()
        let motion = MotionSpy()
        let haptics = HapticsSpy()
        let audio = AudioSpy()
        let model = ArenaViewModel(validation: validation, motion: motion, haptics: haptics, audio: audio, security: SecuritySpy(), raid: RaidSessionService(), preferenceStore: PreferencesSpy(value: prefs), profileProvider: { .fresh(deviceID: "test-device") })
        return Rig(model: model, validation: validation, haptics: haptics, audio: audio)
    }

    private func waitForSession(_ model: ArenaViewModel) async {
        for _ in 0..<50 {
            if model.activeSession != nil { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Server session did not start")
    }

    private func isWarning(_ state: ArenaState) -> Bool { if case .warningCountdown = state { true } else { false } }
    private func isFocusing(_ state: ArenaState) -> Bool { if case .focusing = state { true } else { false } }

    private struct Rig {
        let model: ArenaViewModel
        let validation: ValidationSpy
        let haptics: HapticsSpy
        let audio: AudioSpy
    }
}

private actor ValidationSpy: FocusValidationServiceProtocol {
    private var violations = 0
    func startSession(bossID: String, mode: SessionMode, targetMinutes: Int) async throws -> StartSessionResponse { StartSessionResponse(sessionID: "test-session", sessionNonce: "test-nonce", serverTimestamp: Date()) }
    func sendHeartbeat(sessionID: String, monotonicElapsedSeconds: TimeInterval, motionIntegrityToken: String, attestationAssertion: Data?, clientNonce: String, requestSignature: String?) async throws -> HeartbeatResponse { HeartbeatResponse(authorizedDamage: 0, authoritativeBossHP: 45, comboMultiplier: 1, serverTimestamp: Date()) }
    func reportViolation(sessionID: String, reason: String, monotonicElapsedSeconds: TimeInterval) async throws { violations += 1 }
    func completeSession(sessionID: String) async throws -> CompleteSessionResponse { CompleteSessionResponse(stats: .initial, boss: Boss.roster[0], loot: nil, xpEarned: 0) }
    func violationCount() -> Int { violations }
}

private actor MotionSpy: MotionMonitoringServiceProtocol {
    private let stream: AsyncStream<DevicePostureState>
    init() { stream = AsyncStream { $0.yield(.unavailable) } }
    func postureUpdates() async -> AsyncStream<DevicePostureState> { stream }
}

@MainActor
private final class HapticsSpy: HapticEngineServiceProtocol {
    private(set) var warningCount = 0
    func prepare() { }
    func triggerPickupWarningInitial(enabled: Bool) { if enabled { warningCount += 1 } }
    func triggerCountdownPulse(enabled: Bool) { }
    func triggerRecovery(enabled: Bool) { }
    func triggerPenaltyFailure(enabled: Bool) { }
    func triggerBossDamageHit(enabled: Bool) { }
}

@MainActor
private final class AudioSpy: AudioAtmosphereServiceProtocol {
    private(set) var warningCount = 0
    var onTrackAdvanced: ((AmbientTrack) -> Void)?
    func apply(preferences: AppPreferences) { }
    func beginFocus(preferences: AppPreferences) { }
    func enterWarning(preferences: AppPreferences, secondsRemaining: Int) { warningCount += 1 }
    func countdownTick(preferences: AppPreferences, secondsRemaining: Int) { }
    func recover(preferences: AppPreferences) { }
    func stop() { }
}

@MainActor
private final class PreferencesSpy: PreferencesStoreProtocol {
    private var value: AppPreferences
    init(value: AppPreferences) { self.value = value }
    func load() -> AppPreferences { value }
    func save(_ preferences: AppPreferences) { value = preferences }
    func reset() { value = AppPreferences() }
}

private struct SecuritySpy: RuntimeSecurityServiceProtocol {
    func integrityReport() -> RuntimeIntegrityReport { RuntimeIntegrityReport(isCompromised: false, findings: []) }
}