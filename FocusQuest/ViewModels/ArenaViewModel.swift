import Combine
import Foundation

enum ArenaState: Equatable {
    case idle
    case awaitingFlatPlacement
    case focusing(elapsedSeconds: Int, combo: Int)
    case warningCountdown(secondsRemaining: Double, frozenElapsedSeconds: Int)
    case penalized(reason: String)
    case victory(boss: Boss, xpEarned: Int, droppedLoot: LootItem?)
}

@MainActor
final class ArenaViewModel: ObservableObject {
    @Published private(set) var state: ArenaState = .idle
    @Published var selectedBoss: Boss = Boss.roster[0]
    @Published var mode: SessionMode = .solo
    @Published private(set) var posture: DevicePostureState = .unavailable
    @Published private(set) var partyMembers: [RaidMember] = []
    @Published private(set) var partyAlert: String?
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var activeSession: StudySession?

    private let validation: any FocusValidationServiceProtocol
    private let motion: any MotionMonitoringServiceProtocol
    private let haptics: any HapticEngineServiceProtocol
    private let audio: any AudioAtmosphereServiceProtocol
    private let security: any RuntimeSecurityServiceProtocol
    private let raid: any RaidSessionServiceProtocol
    private let preferenceStore: any PreferencesStoreProtocol
    private let profileProvider: @MainActor () -> UserProfile
    private let signer: any CryptoSignerProtocol
    private let simulationSigningKey: Data
    private let activity: (any FocusBattleActivityServiceProtocol)?
    private var postureTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var raidTask: Task<Void, Never>?
    private var sessionStartUptime: TimeInterval = 0
    private var sessionStartWallClock = Date()
    private var nextHeartbeatAt: TimeInterval = 60
    private var hasUsedGraceRelic = false
    private var warningStartedAt: TimeInterval?
    private var warningFrozenElapsed = 0

    init(validation: any FocusValidationServiceProtocol, motion: any MotionMonitoringServiceProtocol, haptics: any HapticEngineServiceProtocol, audio: any AudioAtmosphereServiceProtocol, security: any RuntimeSecurityServiceProtocol, raid: any RaidSessionServiceProtocol, preferenceStore: any PreferencesStoreProtocol, profileProvider: @escaping @MainActor () -> UserProfile, signer: any CryptoSignerProtocol = CryptoSigner(), simulationSigningKey: Data = Data(), activity: (any FocusBattleActivityServiceProtocol)? = nil) {
        self.validation = validation
        self.motion = motion
        self.haptics = haptics
        self.audio = audio
        self.security = security
        self.raid = raid
        self.preferenceStore = preferenceStore
        self.profileProvider = profileProvider
        self.signer = signer
        self.simulationSigningKey = simulationSigningKey
        self.activity = activity
        self.preferences = preferenceStore.load()
        haptics.prepare()
        observeRaidEvents()
    }

    func startSession() {
        guard !security.integrityReport().isCompromised else { return }
        switch state {
        case .idle, .penalized, .victory: break
        default: return
        }
        state = .awaitingFlatPlacement
        Task { partyMembers = await raid.partyMembers() }
        postureTask = Task { [weak self] in
            guard let self else { return }
            let stream = await motion.postureUpdates()
            for await newPosture in stream {
                guard !Task.isCancelled else { break }
                await handlePosture(newPosture)
            }
        }
        Task { [weak self] in await self?.createServerSession() }
    }

    func stopSession() {
        postureTask?.cancel(); timerTask?.cancel()
        postureTask = nil; timerTask = nil
        audio.stop()
        Task { await activity?.end() }
        if activeSession != nil { state = .idle; activeSession = nil }
    }

    func selectBoss(_ boss: Boss) { guard case .idle = state else { return }; selectedBoss = boss }

    func updatePreferences(_ updated: AppPreferences) {
        preferences = updated
        preferenceStore.save(updated)
        audio.apply(preferences: updated)
    }

    func setSimulatedPosture(_ value: DevicePostureState) async {
        #if targetEnvironment(simulator)
        if let service = motion as? MotionMonitoringService { await service.setSimulatedPosture(value) }
        await handlePosture(value)
        #endif
    }

    private func createServerSession() async {
        do {
            let response = try await validation.startSession(bossID: selectedBoss.id, mode: mode)
            activeSession = StudySession(serverSessionID: response.sessionID, bossID: selectedBoss.id, mode: mode)
            await activity?.start(boss: selectedBoss)
            sessionStartUptime = ProcessInfo.processInfo.systemUptime
            sessionStartWallClock = Date()
            nextHeartbeatAt = 60
            hasUsedGraceRelic = false
            warningStartedAt = nil
            warningFrozenElapsed = 0
            if posture == .flatFaceUp { beginFocusing(elapsed: 0) }
        } catch {
            state = .penalized(reason: "Unable to verify a secure session.")
            postureTask?.cancel()
        }
    }

    func handlePosture(_ value: DevicePostureState) async {
        posture = value
        if value == .flatFaceUp {
            if case let .warningCountdown(_, frozenElapsed) = state { recoverFocus(elapsed: frozenElapsed) }
            else if case .awaitingFlatPlacement = state, activeSession != nil { beginFocusing(elapsed: 0) }
        } else if value == .liftedOrTilted, case let .focusing(elapsed, _) = state {
            beginWarning(elapsed: elapsed)
        }
    }

    private func beginFocusing(elapsed: Int) {
        state = .focusing(elapsedSeconds: elapsed, combo: activeSession?.comboMultiplier ?? 1)
        audio.beginFocus(preferences: preferences)
        timerTask?.cancel()
        timerTask = Task { [weak self] in await self?.runFocusTicker() }
    }

    private func runFocusTicker() async {
        let clock = ContinuousClock()
        while !Task.isCancelled {
            do { try await clock.sleep(for: .seconds(1)) } catch { break }
            guard case .focusing = state, let session = activeSession else { continue }
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = max(0, Int(now - sessionStartUptime))
            let wallElapsed = Date().timeIntervalSince(sessionStartWallClock)
            if AntiCheatRules.clockIsTampered(wallDelta: wallElapsed, monotonicDelta: now - sessionStartUptime) {
                await penalize(reason: "Clock integrity check failed.")
                continue
            }
            state = .focusing(elapsedSeconds: elapsed, combo: session.comboMultiplier)
            await activity?.update(bossHP: selectedBoss.currentHP, elapsedSeconds: elapsed, warningSecondsRemaining: nil)
            if TimeInterval(elapsed) >= nextHeartbeatAt { await sendHeartbeat(elapsed: elapsed) }
        }
    }

    private func sendHeartbeat(elapsed: Int) async {
        guard let session = activeSession else { return }
        do {
            let clientNonce = signer.makeNonce(byteCount: 24)
            let heartbeat = HeartbeatRequest(sessionID: session.serverSessionID, monotonicElapsedSeconds: TimeInterval(elapsed), motionIntegrityToken: "flat-face-up", clientNonce: clientNonce)
            let payload = try JSONEncoder.focusQuest.encode(heartbeat)
            let signature = signer.sign(payload, key: simulationSigningKey, nonce: clientNonce)
            let result = try await validation.sendHeartbeat(sessionID: session.serverSessionID, monotonicElapsedSeconds: TimeInterval(elapsed), motionIntegrityToken: "flat-face-up", attestationAssertion: nil, clientNonce: clientNonce, requestSignature: signature)
            selectedBoss.currentHP = result.authoritativeBossHP
            nextHeartbeatAt += 60
            haptics.triggerBossDamageHit(enabled: preferences.isHapticsEnabled)
            if selectedBoss.isDefeated { await completeSession() }
        } catch {
            await penalize(reason: "Session verification failed.")
        }
    }

    private func beginWarning(elapsed: Int) {
        timerTask?.cancel()
        let duration = AntiCheatRules.warningDuration(equippedLootIDs: profileProvider().equippedLootIDs, graceAlreadyUsed: hasUsedGraceRelic)
        hasUsedGraceRelic = hasUsedGraceRelic || duration > 5
        warningStartedAt = ProcessInfo.processInfo.systemUptime
        warningFrozenElapsed = elapsed
        state = .warningCountdown(secondsRemaining: Double(duration), frozenElapsedSeconds: elapsed)
        haptics.triggerPickupWarningInitial(enabled: preferences.isHapticsEnabled)
        audio.enterWarning(preferences: preferences, secondsRemaining: duration)
        Task { await activity?.update(bossHP: selectedBoss.currentHP, elapsedSeconds: elapsed, warningSecondsRemaining: duration) }
        timerTask = Task { [weak self] in await self?.runWarningTicker(duration: duration, frozenElapsed: elapsed) }
    }

    private func runWarningTicker(duration: Int, frozenElapsed: Int) async {
        let clock = ContinuousClock()
        let start = clock.now
        var previousSecond = duration
        while !Task.isCancelled {
            do { try await clock.sleep(for: .milliseconds(100)) } catch { return }
            let elapsed = start.duration(to: clock.now).secondsDouble
            let remaining = max(0, Double(duration) - elapsed)
            if remaining <= 0 { await penalize(reason: "Phone was lifted during a verified focus session."); return }
            let wholeSecond = Int(ceil(remaining))
            if wholeSecond < previousSecond {
                haptics.triggerCountdownPulse(enabled: preferences.isHapticsEnabled)
                audio.countdownTick(preferences: preferences, secondsRemaining: wholeSecond)
                await activity?.update(bossHP: selectedBoss.currentHP, elapsedSeconds: frozenElapsed, warningSecondsRemaining: wholeSecond)
                previousSecond = wholeSecond
            }
            state = .warningCountdown(secondsRemaining: remaining, frozenElapsedSeconds: frozenElapsed)
        }
    }

    private func recoverFocus(elapsed: Int) {
        timerTask?.cancel()
        if let warningStartedAt {
            let pausedDuration = ProcessInfo.processInfo.systemUptime - warningStartedAt
            sessionStartUptime += pausedDuration
            sessionStartWallClock.addTimeInterval(pausedDuration)
        }
        warningStartedAt = nil
        haptics.triggerRecovery(enabled: preferences.isHapticsEnabled)
        audio.recover(preferences: preferences)
        Task { await activity?.update(bossHP: selectedBoss.currentHP, elapsedSeconds: elapsed, warningSecondsRemaining: nil) }
        beginFocusing(elapsed: elapsed)
    }

    private func penalize(reason: String) async {
        timerTask?.cancel()
        state = .penalized(reason: reason)
        haptics.triggerPenaltyFailure(enabled: preferences.isHapticsEnabled)
        audio.recover(preferences: preferences)
        Task { await activity?.end() }
        if let session = activeSession {
            let elapsed = warningStartedAt == nil ? ProcessInfo.processInfo.systemUptime - sessionStartUptime : TimeInterval(warningFrozenElapsed)
            try? await validation.reportViolation(sessionID: session.serverSessionID, reason: reason, monotonicElapsedSeconds: elapsed)
            if session.mode == .raid { await raid.broadcastComboBroken(memberName: profileProvider().username) }
            activeSession?.comboMultiplier = 1
        }
    }

    private func completeSession() async {
        guard let session = activeSession else { return }
        timerTask?.cancel()
        do {
            let result = try await validation.completeSession(sessionID: session.serverSessionID)
            state = .victory(boss: result.boss, xpEarned: result.xpEarned, droppedLoot: result.loot)
            await activity?.end()
        } catch { state = .penalized(reason: "Could not finalize the verified battle.") }
    }

    private func observeRaidEvents() {
        raidTask = Task { [weak self] in
            guard let self else { return }
            let stream = await raid.events()
            for await event in stream { partyAlert = "\(event.memberName) lifted their phone! Party combo lost." }
        }
    }
}

private extension Duration {
    var secondsDouble: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}