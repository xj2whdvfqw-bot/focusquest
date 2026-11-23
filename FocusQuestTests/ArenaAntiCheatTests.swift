import XCTest
@testable import FocusQuest

@MainActor
final class ArenaAntiCheatTests: XCTestCase {
    func testReturningFlatRecoversFocusBeforeGraceExpires() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        await rig.model.handlePosture(.lifted)
        XCTAssertTrue(isWarning(rig.model.state))
        await rig.model.handlePosture(.lyingStill)
        XCTAssertTrue(isFocusing(rig.model.state))
        XCTAssertEqual(rig.haptics.warningCount, 0)
        XCTAssertGreaterThan(rig.audio.warningCount, 0)
    }

    /// Zadne "Slip forgiven": prvni propadly odpocet zvednuteho telefonu znamena utek bosse.
    func testFirstExpiredCountdownLetsBossEscape() async {
        let rig = makeRig(hapticsEnabled: true)
        rig.model.warningSeconds = 1
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        await rig.model.handlePosture(.lifted)
        for _ in 0..<40 {
            if case .defeated = rig.model.state { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard case let .defeated(defeat) = rig.model.state else { return XCTFail("Boss did not escape") }
        XCTAssertEqual(defeat.reason, .phoneStayedUp)
        // Hlaseni porusení bezi asynchronne; na pomalem CI runneru 50 ms nestaci, cekame az 1 s.
        var violationCount = 0
        for _ in 0..<20 {
            violationCount = await rig.validation.violationCount()
            if violationCount > 0 { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(violationCount, 1)
    }

    /// B2: bez extra pauz ma bitva jen jednu pauzu zdarma.
    func testOneFreePausePerBattleAndRunsOut() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.pauseLimitSeconds = 1
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        XCTAssertEqual(rig.model.pausesLeft, 1)
        rig.model.pauseBattle()
        XCTAssertTrue(isPaused(rig.model.state))
        rig.model.resumeBattle()
        XCTAssertTrue(isFocusing(rig.model.state))
        XCTAssertTrue(rig.model.hasUsedPause)
        rig.model.pauseBattle()
        XCTAssertTrue(isFocusing(rig.model.state), "Second pause without extras must be refused")

        let other = makeRig(hapticsEnabled: false)
        other.model.pauseLimitSeconds = 1
        other.model.startSession()
        await waitForSession(other.model)
        await other.model.handlePosture(.lyingStill)
        other.model.pauseBattle()
        for _ in 0..<40 {
            if case .defeated = other.model.state { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard case let .defeated(defeat) = other.model.state else { return XCTFail("Pause did not run out") }
        XCTAssertEqual(defeat.reason, .pauseRanOut)
        rig.model.stopSession()
    }

    /// B2: s extra pauzami jde po pauze zdarma pouzit nejvys jedna extra; jeji pouziti se ohlasi profilu.
    func testExtraPauseAfterFreePauseOncePerBattle() async {
        let rig = makeRig(hapticsEnabled: false, extraPauses: 3)
        var consumed = 0
        rig.model.onExtraPauseUsed = { consumed += 1 }
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        XCTAssertEqual(rig.model.pausesLeft, 2)
        rig.model.pauseBattle()
        rig.model.resumeBattle()
        XCTAssertEqual(consumed, 0, "The free pause goes first")
        XCTAssertEqual(rig.model.pausesLeft, 1)
        rig.model.pauseBattle()
        XCTAssertTrue(isPaused(rig.model.state), "One extra pause after the free one")
        XCTAssertEqual(consumed, 1)
        rig.model.resumeBattle()
        XCTAssertTrue(rig.model.hasUsedPause)
        rig.model.pauseBattle()
        XCTAssertTrue(isFocusing(rig.model.state), "Only 1 extra pause per battle")
        XCTAssertEqual(consumed, 1)
        rig.model.stopSession()
    }

    func testRetreatLetsBossEscape() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        rig.model.retreat()
        guard case let .defeated(defeat) = rig.model.state else { return XCTFail("Retreat did not end the battle") }
        XCTAssertEqual(defeat.reason, .retreated)
    }

    func testCallPausesWithoutUsingThePauseAndResumesWhenPhoneIsDown() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        rig.model.handleCall(active: true)
        guard case .callPaused(_, false) = rig.model.state else { return XCTFail("Call did not pause the battle") }
        XCTAssertFalse(rig.model.hasUsedPause, "A call must not use the single pause")
        XCTAssertTrue(rig.model.isBattleRunning)

        // Zvednuti telefonu behem hovoru se netresta.
        await rig.model.handlePosture(.lifted)
        guard case .callPaused(_, false) = rig.model.state else { return XCTFail("Lifting during a call must be ignored") }

        rig.model.handleCall(active: false)
        guard case .callPaused(_, true) = rig.model.state else { return XCTFail("Call end was not shown") }
        await rig.model.handlePosture(.lyingStill)
        XCTAssertTrue(isFocusing(rig.model.state))
        rig.model.pauseBattle()
        XCTAssertTrue(isPaused(rig.model.state), "The single pause is still available after a call")
        rig.model.stopSession()
    }

    func testCallDuringLiftedWarningCancelsTheWarning() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        await rig.model.handlePosture(.lifted)
        XCTAssertTrue(isWarning(rig.model.state))
        rig.model.handleCall(active: true)
        guard case .callPaused(_, false) = rig.model.state else { return XCTFail("Call did not replace the warning") }
        rig.model.stopSession()
    }

    func testCallBeforeTheClockStartsIsIgnored() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        rig.model.handleCall(active: true)
        guard case .awaitingFlatPlacement = rig.model.state else { return XCTFail("Nothing to pause before the clock runs") }
        rig.model.stopSession()
    }

    /// Vzorky po 0,1 s (10 Hz) od casu `start` do `start + seconds`; vrati ohlasene zmeny stavu.
    private func feed(_ detector: inout PostureDetector, z: Double, from start: Double, seconds: Double) -> [DevicePostureState] {
        var reported: [DevicePostureState] = []
        for step in 0...Int((seconds * 10).rounded()) {
            if let state = detector.update(gravityZ: z, at: start + Double(step) * 0.1) { reported.append(state) }
        }
        return reported
    }

    func testFlatFaceDownNeedsOneSecond() {
        var detector = PostureDetector()
        XCTAssertEqual(feed(&detector, z: 0.98, from: 0, seconds: 0.9), [])
        XCTAssertEqual(detector.update(gravityZ: 0.98, at: 1.0), .lyingStill)
        XCTAssertNil(detector.update(gravityZ: 0.98, at: 1.1), "Same state is reported only once")
    }

    func testFlatFaceUpCountsToo() {
        var detector = PostureDetector()
        XCTAssertEqual(feed(&detector, z: -0.99, from: 0, seconds: 1.0), [.lyingStill])
    }

    func testTiltBelowFlatThresholdResetsTheSecond() {
        var detector = PostureDetector()
        XCTAssertEqual(feed(&detector, z: 0.95, from: 0, seconds: 0.8), [])
        // 0,85 je mezi prahy: nic se neohlasi a odpocet 1 s zacne znovu.
        XCTAssertNil(detector.update(gravityZ: 0.85, at: 0.9))
        XCTAssertEqual(feed(&detector, z: 0.95, from: 1.0, seconds: 0.9), [])
        XCTAssertEqual(detector.update(gravityZ: 0.95, at: 2.0), .lyingStill)
    }

    func testLiftNeedsHalfASecondBelowThreshold() {
        var detector = PostureDetector()
        XCTAssertEqual(feed(&detector, z: 1, from: 0, seconds: 1.0), [.lyingStill])
        XCTAssertEqual(feed(&detector, z: 0.5, from: 1.1, seconds: 0.4), [], "A short wobble is not a lift")
        XCTAssertEqual(detector.update(gravityZ: 0.5, at: 1.6), .lifted)
    }

    func testBriefDipDoesNotCountAsLift() {
        var detector = PostureDetector()
        XCTAssertEqual(feed(&detector, z: 1, from: 0, seconds: 1.0), [.lyingStill])
        XCTAssertEqual(feed(&detector, z: 0.6, from: 1.1, seconds: 0.3), [])
        XCTAssertEqual(feed(&detector, z: 0.8, from: 1.5, seconds: 2.0), [], "Between thresholds nothing changes")
        XCTAssertEqual(feed(&detector, z: 0.6, from: 3.6, seconds: 0.4), [])
    }

    func testLowPassSmoothsAccelerometerShake() {
        var filter = GravityLowPass()
        XCTAssertEqual(filter.filter(1), 1)
        // Jeden otres na 0 posune vyhlazenou hodnotu jen o 20 %.
        XCTAssertEqual(filter.filter(0), 0.8, accuracy: 1e-9)
    }

    func testStartWithoutSensorStartsBattleAndIgnoresLifts() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        rig.model.startWithoutSensor()
        guard case .focusing = rig.model.state else { return XCTFail("Battle did not start without the sensor") }
        await rig.model.handlePosture(.lifted)
        guard case .focusing = rig.model.state else { return XCTFail("A lift must be ignored without the sensor") }
    }

    func testMutedHapticsDoNotDisableVisualWarning() async {
        let rig = makeRig(hapticsEnabled: false)
        rig.model.startSession()
        await waitForSession(rig.model)
        await rig.model.handlePosture(.lyingStill)
        await rig.model.handlePosture(.lifted)
        XCTAssertTrue(isWarning(rig.model.state))
        XCTAssertEqual(rig.haptics.warningCount, 0)
        XCTAssertEqual(rig.audio.warningCount, 1)
    }

    func testWallClockDivergenceOverTwoSecondsIsTampering() {
        XCTAssertFalse(AntiCheatRules.clockIsTampered(wallDelta: 30, monotonicDelta: 31.9))
        XCTAssertTrue(AntiCheatRules.clockIsTampered(wallDelta: 30, monotonicDelta: 32.1))
        XCTAssertTrue(AntiCheatRules.clockIsTampered(wallDelta: .infinity, monotonicDelta: 10))
    }

    private func makeRig(hapticsEnabled: Bool, extraPauses: Int = 0) -> Rig {
        let prefs = AppPreferences(isHapticsEnabled: hapticsEnabled, isMusicEnabled: true, isSFXEnabled: true, ambientVolume: 0.5, selectedTrack: .calmCurrents)
        let validation = ValidationSpy()
        let motion = MotionSpy()
        let haptics = HapticsSpy()
        let audio = AudioSpy()
        let model = ArenaViewModel(validation: validation, motion: motion, haptics: haptics, audio: audio, preferenceStore: PreferencesSpy(value: prefs), profileProvider: {
            var profile = UserProfile.fresh(deviceID: "test-device")
            profile.extraPauses = extraPauses
            return profile
        })
        model.selectSubject(.math)
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
    private func isPaused(_ state: ArenaState) -> Bool { if case .paused = state { true } else { false } }

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
    func sendHeartbeat(sessionID: String, monotonicElapsedSeconds: TimeInterval, motionIntegrityToken: String, attestationAssertion: Data?, clientNonce: String, requestSignature: String?) async throws -> HeartbeatResponse { HeartbeatResponse(authorizedDamage: 0, authoritativeBossHP: 45, serverTimestamp: Date()) }
    func reportViolation(sessionID: String, reason: String, monotonicElapsedSeconds: TimeInterval) async throws { violations += 1 }
    func completeSession(sessionID: String) async throws -> CompleteSessionResponse { CompleteSessionResponse(stats: .initial, boss: Boss.roster[0], xpEarned: 0) }
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

