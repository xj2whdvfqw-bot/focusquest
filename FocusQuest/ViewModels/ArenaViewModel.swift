import Combine
import Foundation

enum ArenaState: Equatable {
    case idle
    case awaitingFlatPlacement
    case focusing(elapsedSeconds: Int)
    /// Jedina pauza bitvy ("Pause once"): cas se nepocita, po vyprseni `secondsLeft` boss uteče.
    case paused(elapsedSeconds: Int, secondsLeft: Int)
    /// Zvednuty telefon. `forgiven` = prvni propadly odpocet v bitve byl prave odpusten ("Slip forgiven").
    case warningCountdown(secondsRemaining: Double, frozenElapsedSeconds: Int, forgiven: Bool)
    /// Telefonni hovor: hodiny stoji bez casoveho limitu a nepocita se to do "Pause once".
    /// `callEnded` = hovor skoncil a bitva pokracuje, az telefon zase lezi displejem dolu.
    case callPaused(elapsedSeconds: Int, callEnded: Bool)
    /// Technicka chyba (server, hodiny). Nic se nebere.
    case penalized(reason: String)
    case victory(BattleVictory)
    /// Boss utekl: zadne XP ani mince. Serie a mince zustavaji.
    case defeated(BattleDefeat)
}

/// Proc boss utekl.
enum EscapeReason: Equatable, Sendable {
    case retreated, phoneStayedUp, pauseRanOut

    var text: String {
        switch self {
        case .retreated: "You retreated."
        case .phoneStayedUp: "The phone stayed up."
        case .pauseRanOut: "The pause ran out."
        }
    }
}

/// Boss utekl: co ukaze obrazovka porazky.
struct BattleDefeat: Equatable, Sendable {
    let boss: Boss
    let reason: EscapeReason
    let goalMinutes: Int
    let focusedMinutes: Int
}

/// Vyhrana bitva: co ukaze obrazovka vitezstvi a co se pripise do profilu.
struct BattleVictory: Equatable, Sendable {
    let boss: Boss
    let subject: StudySubject
    let verifiedMinutes: Int
    let xpEarned: Int
    let coinsEarned: Int
    /// Vlastni bitva z Areny: neposouva cestu sveta.
    var isCustom = false
    /// Dalsi boss sveta, kdyz tahle vyhra posunula cestu (byl to boss na rade). Jinak nil.
    var nextUp: Boss? = nil
    /// Rychla 5minutova bitva ("Just 5 minutes") proti rozcvicce: vyhra nabidne "Keep going" na nejkratsiho neporazeneho bosse.
    var isQuickBattle: Bool { boss.isWarmUp }
}

@MainActor
final class ArenaViewModel: ObservableObject {
    @Published private(set) var state: ArenaState = .idle
    @Published private(set) var selectedBoss: Boss
    /// Predmet bitvy. Bez nej bitva nezacne.
    @Published private(set) var selectedSubject: StudySubject?
    @Published private(set) var posture: DevicePostureState = .unavailable
    /// Bitva bezi bez senzoru ("Start without sensor"): zvednuti telefonu se nehlida.
    @Published private(set) var isSensorBypassed = false
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var activeSession: StudySession?
    /// Vlastni bitva (Custom Battle): libovolna delka, nahodny boss, cestu sveta neposouva.
    @Published private(set) var isCustomBattle = false
    /// Jedina pauza bitvy uz byla pouzita.
    @Published private(set) var hasUsedPause = false
    /// Prvni propadly odpocet zvednuteho telefonu uz byl odpusten; dalsi znamena utek bosse.
    @Published private(set) var hasUsedSlipGrace = false
    /// Boss, ktery v posledni bitve opravdu padl (pred posunem cesty). Ukazuje ho obrazovka vitezstvi.
    @Published private(set) var lastBeaten: Boss?
    /// Volano, kdyz se predvolby zmeni z Areny (prehravac, postup na ceste), aby je znalo i Nastaveni.
    var onPreferencesChanged: ((AppPreferences) -> Void)?
    /// Volano jednou za kazdou vyhranou bitvu - pripise XP, mince a loot do profilu.
    var onVictory: ((BattleVictory) -> Void)?

    private let validation: any FocusValidationServiceProtocol
    private let motion: any MotionMonitoringServiceProtocol
    private let haptics: any HapticEngineServiceProtocol
    private let audio: any AudioAtmosphereServiceProtocol
    private let preferenceStore: any PreferencesStoreProtocol
    private let profileProvider: @MainActor () -> UserProfile
    private let signer: any CryptoSignerProtocol
    private let simulationSigningKey: Data
    private let activity: (any FocusBattleActivityServiceProtocol)?
    private let notifications: (any BattleNotificationServiceProtocol)?
    private let calls: (any CallMonitoringServiceProtocol)?
    private var postureTask: Task<Void, Never>?
    private var callTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var sessionStartUptime: TimeInterval = 0
    private var sessionStartWallClock = Date()
    private var nextHeartbeatAt: TimeInterval = 60
    private var warningStartedAt: TimeInterval?
    private var warningFrozenElapsed = 0
    private var pausedAt: TimeInterval?
    private var isFinishing = false

    init(validation: any FocusValidationServiceProtocol, motion: any MotionMonitoringServiceProtocol, haptics: any HapticEngineServiceProtocol, audio: any AudioAtmosphereServiceProtocol, preferenceStore: any PreferencesStoreProtocol, profileProvider: @escaping @MainActor () -> UserProfile, signer: any CryptoSignerProtocol = CryptoSigner(), simulationSigningKey: Data = Data(), activity: (any FocusBattleActivityServiceProtocol)? = nil, notifications: (any BattleNotificationServiceProtocol)? = nil, calls: (any CallMonitoringServiceProtocol)? = nil) {
        self.calls = calls
        self.validation = validation
        self.motion = motion
        self.haptics = haptics
        self.audio = audio
        self.preferenceStore = preferenceStore
        self.profileProvider = profileProvider
        self.signer = signer
        self.simulationSigningKey = simulationSigningKey
        self.activity = activity
        self.notifications = notifications
        var stored = preferenceStore.load()
        // Prvni spusteni verze s mapou: svety, ktere uz jsou odemcene, mlhu nemaji (bez animace).
        if stored.revealedWorlds == nil {
            stored.revealedWorlds = BossWorld.allCases.filter { stored.isUnlocked($0) }.map(\.rawValue)
            preferenceStore.save(stored)
        }
        // Boss ze starsi verze, ktery uz v appce neni, se nahradi aktualnim bossem mapy.
        let remembered = Boss.find(stored.lastBossID) ?? stored.currentBoss(anchor: nil)
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
        guard selectedSubject != nil, isBetweenBattles else { return }
        lastBeaten = nil
        hasUsedPause = false
        hasUsedSlipGrace = false
        resetBossHealth()
        // Poloha z minule bitvy neplati: bitva zacne az po novem polozeni telefonu.
        posture = .unavailable
        isSensorBypassed = false
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
        callTask?.cancel()
        if let calls {
            let stream = calls.callUpdates()
            callTask = Task { [weak self] in
                for await active in stream {
                    guard !Task.isCancelled else { break }
                    self?.handleCall(active: active)
                }
            }
        }
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

    /// "Not feeling it? Just 5 minutes": 5minutova bitva proti vlastnimu bossovi (Warm-up Wisp).
    /// Je to vlastni bitva: cestu neposouva, posledni boss cesty (lastBossID) zustava. Spousti se pres Fight sheet.
    func prepareQuickBattle() {
        guard isBetweenBattles else { return }
        isCustomBattle = true
        selectedBoss = Boss.warmUpWisp
    }

    /// "Keep going" po rozcvicce: aktualni boss mapy (dalsi svety jsou zamcene, takze jiny na rade neni).
    func keepGoingBoss(pathWins: [String: Int]) -> Boss? { currentMapBoss }

    // MARK: - Mapa

    /// Aktualni boss mapy: na rade ve svete posledni bitvy, jinak v prvnim odemcenem nedobytem svete.
    /// Nil = vsechny svety dobyte. Hrdina na mape stoji u nej a kamera na nej najede.
    var currentMapBoss: Boss? { preferences.currentBoss(anchor: pathAnchor.world) }

    func isUnlocked(_ world: BossWorld) -> Bool { preferences.isUnlocked(world) }

    func canFight(_ boss: Boss, wins: Int) -> Bool { preferences.canFight(boss, wins: wins) }

    /// Odemceny svet, nad kterym se jeste nerozplynula mlha (animace na mape).
    func needsReveal(_ world: BossWorld) -> Bool {
        // Prvni svet mlhu nikdy nema.
        world.previous != nil && isUnlocked(world) && !(preferences.revealedWorlds ?? []).contains(world.rawValue)
    }

    /// Mlha nad svetem se rozplynula: priste uz se animace neprehraje.
    func markRevealed(_ world: BossWorld) {
        var revealed = preferences.revealedWorlds ?? []
        guard !revealed.contains(world.rawValue) else { return }
        revealed.append(world.rawValue)
        preferences.revealedWorlds = revealed
        preferenceStore.save(preferences)
        onPreferencesChanged?(preferences)
    }

    // MARK: - Prestavka

    /// Svet, na jehoz ceste hrac je: posledni porazeny boss cesty, jinak posledni vybrany boss cesty.
    /// Rozcvicka do zadneho sveta nepatri, takze se preskoci.
    private var pathAnchor: Boss {
        if let lastBeaten, !lastBeaten.isWarmUp { return lastBeaten }
        if !selectedBoss.isWarmUp { return selectedBoss }
        return Boss.find(preferences.lastBossID).flatMap { $0.isWarmUp ? nil : $0 } ?? BossWorld.allCases[0].bosses[0]
    }

    /// Boss cesty pro Arenu: vybrany boss, a kdyz je vybrana rozcvicka, posledni boss cesty.
    var arenaPathBoss: Boss {
        guard selectedBoss.isWarmUp else { return selectedBoss }
        return Boss.find(preferences.lastBossID).flatMap { $0.isWarmUp ? nil : $0 } ?? BossWorld.allCases[0].bosses[0]
    }

    /// Boss na rade na ceste (NEXT BOSS v prestavce): aktualni boss mapy. Po finalnim bossovi sveta
    /// je to prvni boss nove odemceneho sveta. Nil = vse dobyto.
    var upcomingPathBoss: Boss? { currentMapBoss }

    /// "NEXT BOSS" z prestavky: bitva zacne hned, predmet zustava stejny.
    func startNextBoss(_ boss: Boss) {
        guard isBetweenBattles else { return }
        stopSession()
        selectBoss(boss)
        startSession()
    }

    // MARK: - Notifikace mimo bitvu

    /// Posledni znamy stav "dnes uz hrac bojoval" (pro denni pripominku).
    private var focusedToday = false

    /// Naplanuje denni pripominku v 17:00 (nebo ji zrusi, kdyz je vypnuta).
    func refreshDailyReminder(focusedToday: Bool) {
        self.focusedToday = focusedToday
        let enabled = preferences.isDailyReminderEnabled
        Task { await notifications?.updateDailyReminder(enabled: enabled, focusedToday: focusedToday) }
    }

    /// Zacatek 5minutove prestavky: notifikace "Break is over", pokud je zapnuta.
    func breakStarted(seconds: Int) {
        guard preferences.isBreakOverNotificationEnabled else { return }
        Task { await notifications?.scheduleBreakOver(after: seconds) }
    }

    /// Prestavka skoncila nebo ji hrac opustil: notifikace uz neni potreba.
    func breakEnded() {
        Task { await notifications?.cancelBreakOver() }
    }

    /// Prestavka dobehla do 0:00: kratka melodie a jemna vibrace.
    func announceBreakOver() {
        audio.breakOver(preferences: preferences)
        haptics.triggerRecovery(enabled: preferences.isHapticsEnabled)
    }

    /// Konec vlastni bitvy: vybrany je zase posledni uzel cesty.
    func endCustomBattle() {
        guard isCustomBattle, isBetweenBattles else { return }
        isCustomBattle = false
        selectedBoss = Boss.find(preferences.lastBossID) ?? BossWorld.allCases[0].bosses[0]
    }

    // MARK: - Pauza a ustup

    /// Jedina pauza za bitvu trva nejdele 2 minuty.
    var pauseLimitSeconds = 120

    /// "Pause once": hodiny stoji, zvednuti telefonu se netresta a cas pauzy se do bitvy nepocita.
    /// Kdo se do 2:00 nevrati, tomu boss uteče.
    func pauseBattle() {
        guard case let .focusing(elapsed) = state, !isFinishing, !hasUsedPause else { return }
        hasUsedPause = true
        timerTask?.cancel()
        pausedAt = MonotonicClock.now
        state = .paused(elapsedSeconds: elapsed, secondsLeft: pauseLimitSeconds)
        audio.stop()
        let bossHP = selectedBoss.currentHP
        Task { await notifications?.cancelVictory() }
        Task { await activity?.update(bossHP: bossHP, elapsedSeconds: elapsed, warningSecondsRemaining: nil) }
        timerTask = Task { [weak self] in await self?.runPauseTicker() }
    }

    private func runPauseTicker() async {
        let clock = ContinuousClock()
        let start = clock.now
        while !Task.isCancelled {
            do { try await clock.sleep(for: .milliseconds(250)) } catch { return }
            guard case let .paused(elapsed, shown) = state else { return }
            let left = max(0, pauseLimitSeconds - Int(start.duration(to: clock.now).secondsDouble))
            if left <= 0 { bossEscapes(.pauseRanOut, elapsed: elapsed); return }
            if left != shown { state = .paused(elapsedSeconds: elapsed, secondsLeft: left) }
        }
    }

    func resumeBattle() {
        guard case let .paused(elapsed, _) = state else { return }
        timerTask?.cancel()
        if let pausedAt {
            let pausedDuration = MonotonicClock.now - pausedAt
            sessionStartUptime += pausedDuration
            sessionStartWallClock.addTimeInterval(pausedDuration)
        }
        pausedAt = nil
        beginFocusing(elapsed: elapsed)
        // Kdo pri pauze telefon zvedl, musi ho zase polozit - plati stejne pravidlo jako behem bitvy.
        if posture == .lifted { beginWarning(elapsed: elapsed) }
    }

    // MARK: - Telefonni hovor

    /// Hovor zacal: bitva se pozastavi bez limitu a nepocita se to do jedine pauzy.
    /// Hovor skoncil: obrazovka "Call ended" a bitva pokracuje po polozeni telefonu displejem dolu.
    func handleCall(active: Bool) {
        guard !isFinishing else { return }
        if active {
            let elapsed: Int
            switch state {
            case .focusing(let value), .paused(let value, _), .warningCountdown(_, let value, _): elapsed = value
            // Dalsi hovor hned po skonceni predchoziho.
            case .callPaused(let value, true): elapsed = value
            default: return
            }
            timerTask?.cancel()
            timerTask = nil
            warningStartedAt = nil
            pausedAt = nil
            state = .callPaused(elapsedSeconds: elapsed, callEnded: false)
            audio.stop()
            let bossHP = selectedBoss.currentHP
            Task { await notifications?.cancelVictory() }
            Task { await activity?.update(bossHP: bossHP, elapsedSeconds: elapsed, warningSecondsRemaining: nil) }
        } else if case let .callPaused(elapsed, false) = state {
            state = .callPaused(elapsedSeconds: elapsed, callEnded: true)
        }
    }

    /// Bez senzoru ("Start without sensor") se polozeni nehlida: po hovoru pokracuje tlacitko.
    func continueAfterCall() {
        guard isSensorBypassed, case let .callPaused(elapsed, true) = state else { return }
        resumeAfterCall(elapsed: elapsed)
    }

    private func resumeAfterCall(elapsed: Int) {
        // Hodiny navazou presne tam, kde hovor bitvu zastavil; cas hovoru se nepocita.
        sessionStartUptime = MonotonicClock.now - TimeInterval(elapsed)
        sessionStartWallClock = Date().addingTimeInterval(-TimeInterval(elapsed))
        haptics.triggerRecovery(enabled: preferences.isHapticsEnabled)
        beginFocusing(elapsed: elapsed)
    }

    /// "Retreat Anyway": boss uteče, bitva nic neprinese. Serie a mince zustavaji.
    func retreat() {
        guard !isFinishing else { return }
        let elapsed: Int
        switch state {
        case .focusing(let value), .paused(let value, _), .warningCountdown(_, let value, _), .callPaused(let value, _): elapsed = value
        case .awaitingFlatPlacement:
            // Hodiny se jeste nerozbehly: odchod nic nestoji.
            stopSession()
            return
        default: return
        }
        bossEscapes(.retreated, elapsed: elapsed)
    }

    /// Jediny trest bitvy: boss uteče bez XP a minci.
    private func bossEscapes(_ reason: EscapeReason, elapsed: Int) {
        guard isBattleRunning, !isFinishing else { return }
        let goal = targetSeconds / 60
        let defeat = BattleDefeat(boss: selectedBoss, reason: reason, goalMinutes: goal, focusedMinutes: min(goal, elapsed / 60))
        let session = activeSession
        tearDownBattle()
        activeSession = nil
        state = .defeated(defeat)
        haptics.triggerPenaltyFailure(enabled: preferences.isHapticsEnabled)
        // Server se dozvi, ze bitva skoncila bez vitezstvi; nic se tim nebere.
        if let session {
            let validation = validation
            Task { try? await validation.reportViolation(sessionID: session.serverSessionID, reason: reason.text, monotonicElapsedSeconds: TimeInterval(elapsed)) }
        }
    }

    /// Bitva prave bezi (hodiny tikaji, je pozastavena nebo bezi odpocet zvednuteho telefonu).
    var isBattleRunning: Bool {
        switch state {
        case .focusing, .paused, .warningCountdown, .callPaused: true
        default: false
        }
    }

    func clearedNodes(in world: BossWorld) -> Int { preferences.clearedNodes(in: world) }

    /// Vybere uzel na ceste (kterykoli, nic neni zamcene); delka bitvy je dana uzlem.
    func selectBoss(_ boss: Boss) {
        guard isBetweenBattles else { return }
        // Rozcvicka ("Same again" po rychle bitve) je vzdy rychla bitva a neprepise boss cesty.
        if boss.isWarmUp { prepareQuickBattle(); return }
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

    /// Onboarding ("What are you studying?"): vybrana dlazdice klepnutim zmizi uplne
    /// (novy hrac k ni nema statistiky), nevybrana se prida.
    func toggleOnboardingSubject(named name: String) {
        guard isBetweenBattles else { return }
        let key = name.lowercased()
        guard let entry = preferences.subjects.first(where: { $0.isVisible && $0.subject.title.lowercased() == key }) else {
            addSubject(named: name)
            return
        }
        changePreferences { preferences in
            preferences.subjects.removeAll { $0.id == entry.id }
            if preferences.lastSubject == entry.subject { preferences.lastSubject = nil }
        }
        if selectedSubject == entry.subject { selectedSubject = preferences.preselectedSubject }
    }

    /// Mekke smazani predmetu z rezimu Edit ve Fight sheetu; vyber preskoci na jiny viditelny predmet.
    func deleteSubject(_ subject: StudySubject) {
        guard isBetweenBattles else { return }
        changePreferences { $0.subjects.softDelete(subject) }
    }

    /// Predmety pro spravu "Your subjects": vsechny krome smazanych (i skryte).
    var managedSubjects: [SubjectEntry] { preferences.subjects.filter { $0.deletedAt == nil } }

    /// "Recently deleted" ve sprave predmetu: jdou 24 h obnovit.
    var deletedSubjects: [SubjectEntry] { preferences.subjects.recentlyDeleted }

    /// Restore v "Recently deleted" nebo Undo v toastu po smazani.
    func restoreSubject(_ subject: StudySubject) {
        changePreferences { $0.subjects.restore(subject) }
    }

    /// Udrzba pri spusteni: predmety smazane pred vic nez 24 h zmizi nadobro (vraci jejich id,
    /// aby se smazaly i jejich statistiky) a predmety se statistikami, ktere v seznamu chybi, se vrati.
    @discardableResult
    func maintainSubjects(history: [SessionSummary], now: Date = Date()) -> Set<String> {
        var purged: Set<String> = []
        changePreferences { preferences in
            purged = preferences.subjects.purgeExpired(now: now)
            let kept = history.filter { session in !(session.subject.map { purged.contains($0.id) } ?? false) }
            preferences.subjects.addMissing(from: kept)
            if let last = preferences.lastSubject, purged.contains(last.id) { preferences.lastSubject = nil }
        }
        return purged
    }

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
        let reminderChanged = updated.isDailyReminderEnabled != preferences.isDailyReminderEnabled
        preferences = updated
        if reminderChanged { refreshDailyReminder(focusedToday: focusedToday) }
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
            warningStartedAt = nil
            warningFrozenElapsed = 0
            if posture == .lyingStill, case .awaitingFlatPlacement = state { startFocusClock() }
        } catch {
            state = .penalized(reason: "Unable to verify a secure session.")
            postureTask?.cancel()
        }
    }

    /// Pojistka, kdyz senzor polozeni nezaznamena: bitva zacne hned a zvednuti se uz nehlida.
    func startWithoutSensor() {
        guard case .awaitingFlatPlacement = state else { return }
        isSensorBypassed = true
        postureTask?.cancel()
        postureTask = nil
        posture = .lyingStill
        // Bez serverove relace zacne bitva, jakmile relace dorazi (createServerSession).
        if activeSession != nil { startFocusClock() }
    }

    func handlePosture(_ value: DevicePostureState) async {
        guard !isSensorBypassed else { return }
        posture = value
        if value == .lyingStill {
            if case let .warningCountdown(_, frozenElapsed, _) = state { recoverFocus(elapsed: frozenElapsed) }
            else if case let .callPaused(elapsed, true) = state { resumeAfterCall(elapsed: elapsed) }
            else if case .awaitingFlatPlacement = state, activeSession != nil { startFocusClock() }
        } else if value == .lifted, !isFinishing, case let .focusing(elapsed) = state {
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
        state = .focusing(elapsedSeconds: elapsed)
        audio.beginFocus(preferences: preferences)
        // Notifikace prijde v cas konce bitvy i se zamcenou obrazovkou.
        let bossName = selectedBoss.name
        let remaining = targetSeconds - elapsed
        if preferences.isBattleDoneNotificationEnabled {
            Task { await notifications?.scheduleVictory(bossName: bossName, after: remaining) }
        }
        timerTask?.cancel()
        timerTask = Task { [weak self] in await self?.runFocusTicker() }
    }

    private func runFocusTicker() async {
        let clock = ContinuousClock()
        while !Task.isCancelled {
            do { try await clock.sleep(for: .seconds(1)) } catch { return }
            guard case .focusing = state, activeSession != nil, !isFinishing else { continue }
            let now = MonotonicClock.now
            let elapsed = max(0, Int(now - sessionStartUptime))
            let wallElapsed = Date().timeIntervalSince(sessionStartWallClock)
            if AntiCheatRules.clockIsTampered(wallDelta: wallElapsed, monotonicDelta: now - sessionStartUptime) {
                await penalize(reason: "Clock integrity check failed.")
                return
            }
            let shown = min(elapsed, targetSeconds)
            state = .focusing(elapsedSeconds: shown)
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
        // Bitva bez predmetu se pocita do "General".
        let subject = selectedSubject ?? .general
        do {
            if !selectedBoss.isDefeated { try await sendHeartbeat(elapsed: elapsed) }
            let result = try await validation.completeSession(sessionID: session.serverSessionID)
            let minutes = result.boss.isDefeated ? result.boss.maxHP : max(0, result.boss.maxHP - result.boss.currentHP)
            // Vyplata: 12 XP a 3 mince za overenou minutu.
            var victory = BattleVictory(
                boss: result.boss,
                subject: subject,
                verifiedMinutes: minutes,
                xpEarned: RewardRules.xp(verifiedMinutes: minutes),
                coinsEarned: RewardRules.coins(verifiedMinutes: minutes),
                isCustom: isCustomBattle || selectedBoss.isWarmUp
            )
            tearDownBattle(keepNotification: true)
            selectedBoss.currentHP = result.boss.currentHP
            // Obrazovka vitezstvi ukazuje bosse, ktery opravdu padl - ulozi se driv, nez se cesta posune.
            if result.boss.isDefeated { lastBeaten = Boss.find(selectedBoss.id) ?? result.boss }
            // Porazeny uzel na rade posune cestu sveta o krok a obrazovka ukaze "Next up".
            if result.boss.isDefeated, !isCustomBattle, let template = Boss.find(selectedBoss.id) {
                let world = template.world
                let wasFrontier = template.nodeIndex == clearedNodes(in: world)
                changePreferences { $0.markCleared(template) }
                if wasFrontier { victory.nextUp = world.frontierBoss(cleared: clearedNodes(in: world)) }
            }
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
        let duration = warningSeconds
        warningStartedAt = MonotonicClock.now
        warningFrozenElapsed = elapsed
        state = .warningCountdown(secondsRemaining: Double(duration), frozenElapsedSeconds: elapsed, forgiven: false)
        haptics.triggerPickupWarningInitial(enabled: preferences.isHapticsEnabled)
        audio.enterWarning(preferences: preferences, secondsRemaining: duration)
        timerTask = Task { [weak self] in await self?.runWarningTicker(frozenElapsed: elapsed) }
    }

    /// Odpocet zvednuteho telefonu. Prvni propadly odpocet v bitve se odpusti ("Slip forgiven")
    /// a po chvilce bezi znovu; druhy znamena, ze boss uteče. Polozeni telefonu ticker zrusi.
    private func runWarningTicker(frozenElapsed: Int) async {
        let clock = ContinuousClock()
        let duration = warningSeconds
        while !Task.isCancelled {
            let start = clock.now
            var previousSecond = duration + 1
            while true {
                let remaining = max(0, Double(duration) - start.duration(to: clock.now).secondsDouble)
                if remaining <= 0 { break }
                let wholeSecond = Int(ceil(remaining))
                if wholeSecond < previousSecond {
                    if previousSecond <= duration {
                        haptics.triggerCountdownPulse(enabled: preferences.isHapticsEnabled)
                        audio.countdownTick(preferences: preferences, secondsRemaining: wholeSecond)
                    }
                    await activity?.update(bossHP: selectedBoss.currentHP, elapsedSeconds: frozenElapsed, warningSecondsRemaining: wholeSecond)
                    previousSecond = wholeSecond
                }
                state = .warningCountdown(secondsRemaining: remaining, frozenElapsedSeconds: frozenElapsed, forgiven: false)
                do { try await clock.sleep(for: .milliseconds(100)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            if hasUsedSlipGrace {
                bossEscapes(.phoneStayedUp, elapsed: frozenElapsed)
                return
            }
            hasUsedSlipGrace = true
            state = .warningCountdown(secondsRemaining: 0, frozenElapsedSeconds: frozenElapsed, forgiven: true)
            do { try await clock.sleep(for: .seconds(slipForgivenSeconds)) } catch { return }
            // Telefon porad neni dole: alarm bezi dal, tentokrat uz naostro.
            audio.enterWarning(preferences: preferences, secondsRemaining: duration)
        }
    }

    /// Jak dlouho zustane na obrazovce "Slip forgiven", nez se odpocet rozbehne znovu.
    var slipForgivenSeconds = 2.2
    /// Odpocet zvednuteho telefonu (testy ho zkracuji).
    var warningSeconds = AntiCheatRules.warningSeconds


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
        }
    }

    /// Zastavi vse, co bitva rozbehla: casovace, senzory, hudbu, Live Activity a notifikaci.
    /// Po vitezstvi notifikace zustava - pokud je appka na pozadi, prave ona hrace zavola zpatky.
    private func tearDownBattle(keepNotification: Bool = false) {
        postureTask?.cancel(); timerTask?.cancel(); callTask?.cancel()
        postureTask = nil; timerTask = nil; callTask = nil
        calls?.stop()
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
