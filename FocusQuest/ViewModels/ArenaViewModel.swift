import Combine
import Foundation

enum ArenaState: Equatable {
    case idle
    case awaitingFlatPlacement
    case focusing(elapsedSeconds: Int, combo: Int)
    /// Hrac bitvu pozastavil tlacitkem Pause; cas se nepocita.
    case paused(elapsedSeconds: Int)
    case warningCountdown(secondsRemaining: Double, frozenElapsedSeconds: Int)
    case penalized(reason: String)
    case victory(BattleVictory)
    /// Hrac ustoupil z bitvy ("Retreat Anyway"): obrazovka porazky.
    case defeated(BattleDefeat)
}

/// Ustup z bitvy: co ukaze obrazovka porazky.
struct BattleDefeat: Equatable, Sendable {
    let boss: Boss
    let goalMinutes: Int
    let focusedMinutes: Int
    var missedMinutes: Int { max(0, goalMinutes - focusedMinutes) }
}

/// Ukol na karte "Working on" behem bitvy.
struct BattleTask: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var isDone = false
}

/// Vyhrana bitva: co ukaze obrazovka vitezstvi a co se pripise do profilu.
struct BattleVictory: Equatable, Sendable {
    let boss: Boss
    let subject: StudySubject
    let verifiedMinutes: Int
    let xpEarned: Int
    let coinsEarned: Int
    let droppedLoot: LootItem?
    /// Vlastni bitva z Areny: neposouva cestu sveta.
    var isCustom = false
}

@MainActor
final class ArenaViewModel: ObservableObject {
    @Published private(set) var state: ArenaState = .idle
    @Published private(set) var selectedBoss: Boss
    /// Predmet bitvy. Bez nej bitva nezacne.
    @Published private(set) var selectedSubject: StudySubject?
    @Published private(set) var posture: DevicePostureState = .unavailable
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var activeSession: StudySession?
    /// Vlastni bitva (Custom Battle): libovolna delka, nahodny boss, cestu sveta neposouva.
    @Published private(set) var isCustomBattle = false
    /// Karta "Working on": ukoly, ktere si hrac behem bitvy odskrtava. Jen v pameti.
    @Published private(set) var tasks: [BattleTask] = []
    /// Boss, ktery v posledni bitve opravdu padl (pred posunem cesty). Ukazuje ho obrazovka vitezstvi.
    @Published private(set) var lastBeaten: Boss?
    /// Volano, kdyz se predvolby zmeni z Areny (prehravac, postup na ceste), aby je znalo i Nastaveni.
    var onPreferencesChanged: ((AppPreferences) -> Void)?
    /// Volano jednou za kazdou vyhranou bitvu - pripise XP, mince a loot do profilu.
    var onVictory: ((BattleVictory) -> Void)?
    /// Volano, kdyz hrac z bitvy ustoupi (ztrata HP hrdiny a serie).
    var onQuestFailed: (() -> Void)?

    private let validation: any FocusValidationServiceProtocol
    private let motion: any MotionMonitoringServiceProtocol
    private let haptics: any HapticEngineServiceProtocol
    private let audio: any AudioAtmosphereServiceProtocol
    private let security: any RuntimeSecurityServiceProtocol
    private let preferenceStore: any PreferencesStoreProtocol
    private let profileProvider: @MainActor () -> UserProfile
    private let signer: any CryptoSignerProtocol
    private let simulationSigningKey: Data
    private let activity: (any FocusBattleActivityServiceProtocol)?
    private let notifications: (any BattleNotificationServiceProtocol)?
    private var postureTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var sessionStartUptime: TimeInterval = 0
    private var sessionStartWallClock = Date()
    private var nextHeartbeatAt: TimeInterval = 60
    private var hasUsedGraceRelic = false
    private var warningStartedAt: TimeInterval?
    private var warningFrozenElapsed = 0
    private var pausedAt: TimeInterval?
    private var isFinishing = false

    init(validation: any FocusValidationServiceProtocol, motion: any MotionMonitoringServiceProtocol, haptics: any HapticEngineServiceProtocol, audio: any AudioAtmosphereServiceProtocol, security: any RuntimeSecurityServiceProtocol, preferenceStore: any PreferencesStoreProtocol, profileProvider: @escaping @MainActor () -> UserProfile, signer: any CryptoSignerProtocol = CryptoSigner(), simulationSigningKey: Data = Data(), activity: (any FocusBattleActivityServiceProtocol)? = nil, notifications: (any BattleNotificationServiceProtocol)? = nil) {
        self.validation = validation
        self.motion = motion
        self.haptics = haptics
        self.audio = audio
        self.security = security
        self.preferenceStore = preferenceStore
        self.profileProvider = profileProvider
        self.signer = signer
        self.simulationSigningKey = simulationSigningKey
        self.activity = activity
        self.notifications = notifications
        let stored = preferenceStore.load()
        let remembered = Boss.find(stored.lastBossID)
        self.preferences = stored
        self.selectedBoss = remembered ?? BossWorld.allCases[0].bosses[0]
        self.selectedSubject = stored.preselectedSubject
        audio.onTrackAdvanced = { [weak self] track in self?.trackDidAdvance(track) }
        haptics.prepare()
    }

    /// Delka bitvy v sekundach.
    var targetSeconds: Int { selectedBoss.maxHP * 60 }

    var isBetweenBattles: Bool {
        switch state {
        case .idle, .penalized, .victory, .defeated: true
        default: false
        }
    }

    func startSession() {
        guard selectedSubject != nil, isBetweenBattles, !security.integrityReport().isCompromised else { return }
        lastBeaten = nil
        resetBossHealth()
        state = .awaitingFlatPlacement
        activeSession = nil
        isFinishing = false
        Task { await notifications?.requestAuthorizationIfNeeded() }
        postureTask?.cancel()
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

    /// Vzdat bitvu nebo zavrit obrazovku s vysledkem.
    func stopSession() {
        tearDownBattle()
        state = .idle
        activeSession = nil
        // Boss se pred dalsi bitvou vrati na plne zdravi podle svych minut.
        resetBossHealth()
        endCustomBattle()
    }

    // MARK: - Vlastni bitva

    /// "Not feeling it? Just 5 minutes": stejny boss jako na tlacitku Fight, jen na 5 minut.
    /// Je to vlastni bitva, takze cestu sveta neposouva. Spusti se z obrazovky bitvy jako Fight.
    func prepareQuickBattle(with boss: Boss) {
        guard isBetweenBattles else { return }
        selectBoss(boss)
        isCustomBattle = true
        selectedBoss = selectedBoss.withHP(minutes: Boss.quickBattleMinutes)
    }

    /// Konec vlastni bitvy: vybrany je zase posledni uzel cesty.
    func endCustomBattle() {
        guard isCustomBattle, isBetweenBattles else { return }
        isCustomBattle = false
        selectedBoss = Boss.find(preferences.lastBossID) ?? BossWorld.allCases[0].bosses[0]
    }

    // MARK: - Karta "Working on"

    static let maxTasks = 12
    static let maxTaskLength = 80

    func addTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, tasks.count < Self.maxTasks else { return }
        tasks.append(BattleTask(id: UUID(), title: String(trimmed.prefix(Self.maxTaskLength))))
    }

    func toggleTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone.toggle()
    }

    func removeTask(_ id: UUID) { tasks.removeAll { $0.id == id } }

    // MARK: - Pauza a ustup

    /// Pause: hodiny stoji, zvednuti telefonu se netresta a cas pauzy se do bitvy nepocita.
    func pauseBattle() {
        guard case let .focusing(elapsed, _) = state, !isFinishing else { return }
        timerTask?.cancel()
        timerTask = nil
        pausedAt = MonotonicClock.now
        state = .paused(elapsedSeconds: elapsed)
        audio.stop()
        let bossHP = selectedBoss.currentHP
        Task { await notifications?.cancelVictory() }
        Task { await activity?.update(bossHP: bossHP, elapsedSeconds: elapsed, warningSecondsRemaining: nil) }
    }

    func resumeBattle() {
        guard case let .paused(elapsed) = state else { return }
        if let pausedAt {
            let pausedDuration = MonotonicClock.now - pausedAt
            sessionStartUptime += pausedDuration
            sessionStartWallClock.addTimeInterval(pausedDuration)
        }
        pausedAt = nil
        beginFocusing(elapsed: elapsed)
        // Kdo pri pauze telefon zvedl, musi ho zase polozit - plati stejne pravidlo jako behem bitvy.
        if posture == .liftedOrTilted { beginWarning(elapsed: elapsed) }
    }

    /// "Retreat Anyway": bitva konci porazkou, hrdina ztrati HP a serie zacne znovu.
    func retreat() {
        guard !isFinishing else { return }
        let elapsed: Int
        switch state {
        case .focusing(let value, _), .paused(let value), .warningCountdown(_, let value): elapsed = value
        case .awaitingFlatPlacement:
            // Hodiny se jeste nerozbehly: odchod nic nestoji.
            stopSession()
            return
        default: return
        }
        let goal = targetSeconds / 60
        let defeat = BattleDefeat(boss: selectedBoss, goalMinutes: goal, focusedMinutes: min(goal, elapsed / 60))
        tearDownBattle()
        activeSession = nil
        state = .defeated(defeat)
        haptics.triggerPenaltyFailure(enabled: preferences.isHapticsEnabled)
        onQuestFailed?()
    }

    /// Bitva prave bezi (hodiny tikaji, je pozastavena nebo bezi odpocet zvednuteho telefonu).
    var isBattleRunning: Bool {
        switch state {
        case .focusing, .paused, .warningCountdown: true
        default: false
        }
    }

    func clearedNodes(in world: BossWorld) -> Int { preferences.clearedNodes(in: world) }

    /// Vybere uzel na ceste (kterykoli, nic neni zamcene); delka bitvy je dana uzlem.
    func selectBoss(_ boss: Boss) {
        guard isBetweenBattles else { return }
        isCustomBattle = false
        selectedBoss = Boss.find(boss.id) ?? boss
        changePreferences { $0.lastBossID = boss.id }
    }

    func selectSubject(_ subject: StudySubject) {
        guard isBetweenBattles else { return }
        selectedSubject = subject
        changePreferences { $0.lastSubject = subject }
    }

    /// Predmety pro Fight sheet v pevnem poradi seznamu (bez skrytych a smazanych).
    var visibleSubjects: [StudySubject] { preferences.subjects.visibleSubjects }

    /// Prida predmet z Fight sheetu a rovnou ho vybere. Duplicitu nevytvori, jen vybere existujici.
    @discardableResult
    func addSubject(named name: String) -> SubjectAddResult? {
        guard isBetweenBattles else { return nil }
        var subjects = preferences.subjects
        guard let result = subjects.add(named: name) else { return nil }
        selectedSubject = result.subject
        changePreferences {
            $0.subjects = subjects
            $0.lastSubject = result.subject
        }
        return result
    }

    /// Mekke smazani predmetu z rezimu Edit ve Fight sheetu; vyber preskoci na jiny viditelny predmet.
    func deleteSubject(_ subject: StudySubject) {
        guard isBetweenBattles else { return }
        changePreferences { $0.subjects.softDelete(subject) }
    }

    /// Predmety pro spravu "Your subjects": vsechny krome smazanych (i skryte).
    var managedSubjects: [SubjectEntry] { preferences.subjects.filter { $0.deletedAt == nil } }

    /// Prejmenovani v "Your subjects". Id zustava, takze historie bitev patri dal k predmetu.
    func renameSubject(_ subject: StudySubject, to name: String) {
        let title = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !title.isEmpty else { return }
        changePreferences { preferences in
            guard let index = preferences.subjects.firstIndex(where: { $0.id == subject.id }) else { return }
            preferences.subjects[index].subject.title = title
            if preferences.lastSubject == subject { preferences.lastSubject = preferences.subjects[index].subject }
        }
    }

    /// Skryti v "Your subjects": predmet zmizi z bitev, data zustanou.
    func setSubjectHidden(_ subject: StudySubject, hidden: Bool) {
        changePreferences { preferences in
            guard let index = preferences.subjects.firstIndex(where: { $0.id == subject.id }) else { return }
            preferences.subjects[index].isHidden = hidden
        }
    }

    private func resetBossHealth() {
        // Vlastni bitva si drzi zvolenou delku; uzel cesty se vrati na svou pevnou delku.
        if isCustomBattle { selectedBoss = selectedBoss.withHP(minutes: selectedBoss.maxHP); return }
        selectedBoss = Boss.find(selectedBoss.id) ?? selectedBoss.withHP(minutes: selectedBoss.maxHP)
    }

    // MARK: - Prehravac

    func setSoundscape(_ value: Soundscape) { changePreferences { $0.soundscape = value } }
    func setMusicEnabled(_ value: Bool) { changePreferences { $0.isMusicEnabled = value } }
    func setVolume(_ value: Double) { changePreferences { $0.ambientVolume = min(1, max(0, value)) } }
    func skipTrack() { changePreferences { $0.soundscape = .lofi; $0.selectedTrack = $0.selectedTrack.next } }

    /// Zmena predvoleb z Areny: ulozi se, projevi se ve zvuku a da se vedet Nastaveni.
    private func changePreferences(_ change: (inout AppPreferences) -> Void) {
        var updated = preferences
        change(&updated)
        guard updated != preferences else { return }
        updatePreferences(updated)
        onPreferencesChanged?(updated)
    }

    /// Playlist sam presel na dalsi skladbu - jen si ji zapamatujeme, prehravani uz bezi.
    private func trackDidAdvance(_ track: AmbientTrack) {
        guard preferences.selectedTrack != track else { return }
        preferences.selectedTrack = track
        preferenceStore.save(preferences)
        onPreferencesChanged?(preferences)
    }

    func updatePreferences(_ updated: AppPreferences) {
        preferences = updated
        preferenceStore.save(updated)
        audio.apply(preferences: updated)
        // Vybrany predmet mohl zmizet (smazani, skryti, smazani uctu) nebo se prejmenovat.
        guard isBetweenBattles else { return }
        let visible = updated.subjects.visibleSubjects
        if let current = selectedSubject, let fresh = visible.first(where: { $0 == current }) {
            selectedSubject = fresh
        } else {
            selectedSubject = updated.preselectedSubject
        }
    }

    func setSimulatedPosture(_ value: DevicePostureState) async {
        #if targetEnvironment(simulator)
        if let service = motion as? MotionMonitoringService { await service.setSimulatedPosture(value) }
        await handlePosture(value)
        #endif
    }

    // MARK: - Prubeh bitvy

    private func createServerSession() async {
        do {
            let response = try await validation.startSession(bossID: selectedBoss.id, mode: .solo, targetMinutes: selectedBoss.maxHP)
            // Hrac mohl bitvu vzdat driv, nez server odpovedel.
            guard case .awaitingFlatPlacement = state else { return }
            activeSession = StudySession(serverSessionID: response.sessionID, bossID: selectedBoss.id, mode: .solo)
            await activity?.start(boss: selectedBoss)
            hasUsedGraceRelic = false
            warningStartedAt = nil
            warningFrozenElapsed = 0
            if posture == .flatFaceUp, case .awaitingFlatPlacement = state { startFocusClock() }
        } catch {
            state = .penalized(reason: "Unable to verify a secure session.")
            postureTask?.cancel()
        }
    }

    func handlePosture(_ value: DevicePostureState) async {
        posture = value
        if value == .flatFaceUp {
            if case let .warningCountdown(_, frozenElapsed) = state { recoverFocus(elapsed: frozenElapsed) }
            else if case .awaitingFlatPlacement = state, activeSession != nil { startFocusClock() }
        } else if value == .liftedOrTilted, !isFinishing, case let .focusing(elapsed, _) = state {
            beginWarning(elapsed: elapsed)
        }
    }

    /// Hodiny bitvy se rozbehnou az ve chvili, kdy telefon poprve lezi na stole.
    private func startFocusClock() {
        sessionStartUptime = MonotonicClock.now
        sessionStartWallClock = Date()
        nextHeartbeatAt = 60
        beginFocusing(elapsed: 0)
    }

    private func beginFocusing(elapsed: Int) {
        state = .focusing(elapsedSeconds: elapsed, combo: activeSession?.comboMultiplier ?? 1)
        audio.beginFocus(preferences: preferences)
        // Notifikace prijde v cas konce bitvy i se zamcenou obrazovkou.
        let bossName = selectedBoss.name
        let remaining = targetSeconds - elapsed
        Task { await notifications?.scheduleVictory(bossName: bossName, after: remaining) }
        timerTask?.cancel()
        timerTask = Task { [weak self] in await self?.runFocusTicker() }
    }

    private func runFocusTicker() async {
        let clock = ContinuousClock()
        while !Task.isCancelled {
            do { try await clock.sleep(for: .seconds(1)) } catch { return }
            guard case .focusing = state, let session = activeSession, !isFinishing else { continue }
            let now = MonotonicClock.now
            let elapsed = max(0, Int(now - sessionStartUptime))
            let wallElapsed = Date().timeIntervalSince(sessionStartWallClock)
            if AntiCheatRules.clockIsTampered(wallDelta: wallElapsed, monotonicDelta: now - sessionStartUptime) {
                await penalize(reason: "Clock integrity check failed.")
                return
            }
            let shown = min(elapsed, targetSeconds)
            state = .focusing(elapsedSeconds: shown, combo: session.comboMultiplier)
            await activity?.update(bossHP: selectedBoss.currentHP, elapsedSeconds: shown, warningSecondsRemaining: nil)
            // Konec bitvy hlida klient podle casu; nespoleha na to, ze heartbeat zrovna srazi HP na nulu.
            if elapsed >= targetSeconds {
                await finishBattle(elapsed: targetSeconds)
                return
            }
            if TimeInterval(elapsed) >= nextHeartbeatAt {
                do { try await sendHeartbeat(elapsed: elapsed) } catch {
                    await penalize(reason: "Session verification failed.")
                    return
                }
                if selectedBoss.isDefeated {
                    await finishBattle(elapsed: elapsed)
                    return
                }
            }
        }
    }

    /// Server overi uplynuly cas a vrati skutecne HP bosse.
    private func sendHeartbeat(elapsed: Int) async throws {
        guard let session = activeSession else { return }
        let clientNonce = signer.makeNonce(byteCount: 24)
        let heartbeat = HeartbeatRequest(sessionID: session.serverSessionID, monotonicElapsedSeconds: TimeInterval(elapsed), motionIntegrityToken: "flat-face-up", clientNonce: clientNonce)
        let payload = try JSONEncoder.focusQuest.encode(heartbeat)
        let signature = signer.sign(payload, key: simulationSigningKey, nonce: clientNonce)
        let result = try await validation.sendHeartbeat(sessionID: session.serverSessionID, monotonicElapsedSeconds: TimeInterval(elapsed), motionIntegrityToken: "flat-face-up", attestationAssertion: nil, clientNonce: clientNonce, requestSignature: signature)
        selectedBoss.currentHP = result.authoritativeBossHP
        // Po uspani appky muze byt zpozdeni vic nez minuta; dalsi heartbeat az na pristi celou minutu.
        nextHeartbeatAt = TimeInterval((elapsed / 60 + 1) * 60)
        haptics.triggerBossDamageHit(enabled: preferences.isHapticsEnabled)
    }

    /// Cas vyprsel: posledni heartbeat dorovna HP, server bitvu uzavre a hrac dostane odmenu.
    private func finishBattle(elapsed: Int) async {
        guard let session = activeSession, !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        let subject = selectedSubject ?? .math
        do {
            if !selectedBoss.isDefeated { try await sendHeartbeat(elapsed: elapsed) }
            let result = try await validation.completeSession(sessionID: session.serverSessionID)
            let minutes = result.boss.isDefeated ? result.boss.maxHP : max(0, result.boss.maxHP - result.boss.currentHP)
            let victory = BattleVictory(
                boss: result.boss,
                subject: subject,
                verifiedMinutes: minutes,
                xpEarned: result.xpEarned,
                coinsEarned: RewardRules.coins(verifiedMinutes: minutes, bossDefeated: result.boss.isDefeated),
                droppedLoot: result.loot,
                isCustom: isCustomBattle
            )
            tearDownBattle(keepNotification: true)
            selectedBoss.currentHP = result.boss.currentHP
            // Obrazovka vitezstvi ukazuje bosse, ktery opravdu padl - ulozi se driv, nez se cesta posune.
            if result.boss.isDefeated { lastBeaten = Boss.find(selectedBoss.id) ?? result.boss }
            // Porazeny uzel na rade posune cestu sveta o krok.
            if result.boss.isDefeated, !isCustomBattle, let template = Boss.find(selectedBoss.id) { changePreferences { $0.markCleared(template) } }
            state = .victory(victory)
            activeSession = nil
            onVictory?(victory)
        } catch {
            await penalize(reason: "Could not finalize the verified battle.")
        }
    }

    private func beginWarning(elapsed: Int) {
        timerTask?.cancel()
        Task { await notifications?.cancelVictory() }
        let duration = AntiCheatRules.warningDuration(equippedLootIDs: profileProvider().equippedLootIDs, graceAlreadyUsed: hasUsedGraceRelic)
        hasUsedGraceRelic = hasUsedGraceRelic || duration > 5
        warningStartedAt = MonotonicClock.now
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
            let pausedDuration = MonotonicClock.now - warningStartedAt
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
        let elapsed = warningStartedAt == nil ? MonotonicClock.now - sessionStartUptime : TimeInterval(warningFrozenElapsed)
        tearDownBattle()
        state = .penalized(reason: reason)
        haptics.triggerPenaltyFailure(enabled: preferences.isHapticsEnabled)
        if let session = activeSession {
            try? await validation.reportViolation(sessionID: session.serverSessionID, reason: reason, monotonicElapsedSeconds: elapsed)
            activeSession?.comboMultiplier = 1
        }
    }

    /// Zastavi vse, co bitva rozbehla: casovace, senzory, hudbu, Live Activity a notifikaci.
    /// Po vitezstvi notifikace zustava - pokud je appka na pozadi, prave ona hrace zavola zpatky.
    private func tearDownBattle(keepNotification: Bool = false) {
        postureTask?.cancel(); timerTask?.cancel()
        postureTask = nil; timerTask = nil
        warningStartedAt = nil
        pausedAt = nil
        audio.stop()
        Task { await activity?.end() }
        if !keepNotification { Task { await notifications?.cancelVictory() } }
    }
}

private extension Duration {
    var secondsDouble: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
