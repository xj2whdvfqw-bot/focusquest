import SwiftUI

/// Bitva pres celou obrazovku (bez spodni listy): jedna velka plovouci karta uprostred
/// s bossem, obrim odpoctem, kulatymi tlacitky a seznamem "Working on".
struct BattleView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    /// Zavola se po zavreni vysledku bitvy nebo krizkem pred bitvou (zavre celou obrazovku).
    let onExit: () -> Void
    @State private var receipt: UIImage?
    @State private var showsRetreatConfirm = false
    @State private var showsBattleSettings = false
    @State private var newTask = ""
    @FocusState private var taskFieldFocused: Bool

    private var pill: RoundedRectangle { RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous) }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 40, style: .continuous) }
    private var world: BossWorld { model.selectedBoss.world }
    private var isWarning: Bool { if case .warningCountdown = model.state { true } else { false } }
    private var isPaused: Bool { if case .paused = model.state { true } else { false } }
    private var isFocusing: Bool { if case .focusing = model.state { true } else { false } }
    private var isIdle: Bool { if case .idle = model.state { true } else { false } }
    private var isVictory: Bool { if case .victory = model.state { true } else { false } }
    private var elapsed: Int {
        switch model.state {
        case .focusing(let value, _): value
        case .paused(let value): value
        case .warningCountdown(_, let value): value
        default: 0
        }
    }
    private var comboValue: Int { if case let .focusing(_, combo) = model.state { combo } else { model.activeSession?.comboMultiplier ?? 1 } }
    /// Odpocet do konce bitvy; pred bitvou ukazuje celou delku.
    private var remaining: Int { max(0, model.targetSeconds - elapsed) }
    /// "24:59", nad hodinu "1:29:59" - obri cislice se tak vejdou na sirku telefonu.
    private var clockText: String {
        let hours = remaining / 3600, minutes = (remaining / 60) % 60, seconds = remaining % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
    private var durationText: String { ArenaView.durationText(minutes: model.selectedBoss.maxHP) }
    private var battleTitle: String { model.isCustomBattle ? "Custom Focus" : "Node \(model.selectedBoss.nodeIndex + 1) · \(world.title)" }

    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: isWarning, scene: world.scene)
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: FQSpace.xl) {
                        topBar
                        battleCard
                        if let receipt { BattleReceiptShareView(image: receipt) }
                        #if targetEnvironment(simulator)
                        simulatorControls
                        #endif
                    }
                    .padding(.horizontal, FQSpace.gutter)
                    .padding(.vertical, FQSpace.lg)
                    .frame(maxWidth: 520)
                    // Karta stoji uprostred obrazovky; delsi seznam ukolu ji jen natahne a da se rolovat.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            if showsRetreatConfirm { retreatDialog.transition(.opacity) }
            if case let .warningCountdown(seconds, _) = model.state { warningOverlay(seconds: seconds) }
            if case let .penalized(reason) = model.state {
                resultOverlay(icon: "xmark.shield.fill", title: "Quest failed", detail: reason, color: FQColor.danger)
            }
            if case let .defeated(defeat) = model.state {
                resultOverlay(icon: "flag.fill", title: "You retreated", detail: defeatDetail(defeat), color: FQColor.danger)
            }
            if case let .victory(victory) = model.state { victoryOverlay(victory) }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.25), value: isVictory)
        .animation(.easeOut(duration: 0.2), value: showsRetreatConfirm)
        .sheet(isPresented: $showsBattleSettings) { battleSettingsSheet }
        .onChange(of: model.state) { _, value in
            // Ustupovy dialog nema smysl, kdyz bitva mezitim skoncila.
            if !model.isBattleRunning { showsRetreatConfirm = false }
            // Odmenu uz pripsal model; obrazovka si jen pripravi sdilitelnou uctenku.
            if case let .victory(victory) = value {
                receipt = BattleReceiptRenderer.render(profile: profileModel.profile, boss: victory.boss, focusMinutes: victory.verifiedMinutes, flawless: true)
            }
        }
    }

    private func closeResult() {
        model.stopSession()
        receipt = nil
        onExit()
    }

    /// Krizek pred bitvou: vlastni bitva se zrusi a obrazovka se zavre.
    private func closeBeforeBattle() {
        model.endCustomBattle()
        onExit()
    }

    private func defeatDetail(_ defeat: BattleDefeat) -> String {
        let focused = ArenaView.durationText(minutes: defeat.focusedMinutes)
        let goal = ArenaView.durationText(minutes: defeat.goalMinutes)
        return "\(defeat.boss.name) escaped after \(focused) of \(goal). You lost \(defeat.heroHPLost) hero HP and your streak resets."
    }

    // MARK: - Horni lista

    private var topBar: some View {
        HStack(spacing: FQSpace.md) {
            if isIdle {
                circleIcon("xmark", label: "Close", action: closeBeforeBattle)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer(minLength: 0)
            Text(battleTitle)
                .font(.fqLabel)
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
            Spacer(minLength: 0)
            circleIcon(model.preferences.isMusicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", label: "Sound and battle rules") {
                showsBattleSettings = true
            }
        }
    }

    private func circleIcon(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(FQColor.textPrimary)
                .frame(width: 44, height: 44)
                .glassControl(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Hlavni karta

    private var battleCard: some View {
        VStack(spacing: FQSpace.xxl) {
            bossHeader
            VStack(spacing: FQSpace.md) {
                timer
                statusLine
            }
            controls
            HairlineDivider()
            workingOnSection
        }
        .padding(.horizontal, FQSpace.xl)
        .padding(.top, FQSpace.xxl)
        .padding(.bottom, FQSpace.xl)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: cardShape)
        .background((isWarning ? FQColor.danger : world.accent).opacity(0.06), in: cardShape)
        .overlay { cardShape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1) }
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
    }

    private var bossHeader: some View {
        VStack(spacing: FQSpace.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(isWarning ? FQColor.danger : world.accent).opacity(0.32), Color.clear], center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                PixelArtAvatarView(sprite: .boss(model.selectedBoss.pixelSpriteConfig), hitFlash: false, size: 104)
            }
            .frame(height: 112)
            VStack(spacing: FQSpace.xs) {
                Text(model.selectedBoss.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(FQColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(model.selectedBoss.tier.rawValue.capitalized) · \(durationText)")
                    .font(.fqSecondary)
                    .foregroundStyle(FQColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Obri odpocet: hlavni informace obrazovky.
    private var timer: some View {
        Text(clockText)
            .font(.system(size: remaining >= 3600 ? 72 : 92, weight: .light, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(isPaused ? FQColor.textSecondary : FQColor.textPrimary)
            .contentTransition(.numericText())
            .animation(.default, value: elapsed)
            .accessibilityLabel(isPaused ? "Paused, \(clockText) left" : "Time left \(clockText)")
    }

    /// Jeden tichy radek pod odpoctem: co se prave deje.
    @ViewBuilder private var statusLine: some View {
        switch model.state {
        case .paused:
            Label("Paused · the clock is stopped", systemImage: "pause.fill")
                .font(.fqLabel)
                .foregroundStyle(FQColor.caution)
        case .focusing, .warningCountdown:
            HStack(spacing: FQSpace.sm) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: isWarning, size: 24)
                Text("Combo \(comboValue)x").font(.fqLabel).foregroundStyle(FQColor.accent)
                Text("·").foregroundStyle(FQColor.textTertiary)
                Text("\(max(0, model.selectedBoss.currentHP)) HP left").font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.textSecondary)
            }
        case .awaitingFlatPlacement:
            Label("Place your iPhone face-up on the desk", systemImage: "iphone.gen3.radiowaves.left.and.right")
                .font(.fqLabel)
                .foregroundStyle(FQColor.textPrimary)
                .multilineTextAlignment(.center)
        default:
            Text(model.selectedSubject == nil ? "What are you studying?" : "Ready when you are")
                .font(.fqLabel)
                .foregroundStyle(model.selectedSubject == nil ? FQColor.caution : FQColor.textSecondary)
        }
    }

    // MARK: - Ovladani

    @ViewBuilder private var controls: some View {
        switch model.state {
        case .idle, .penalized, .victory, .defeated:
            VStack(spacing: FQSpace.xl) {
                subjectPicker
                Button { model.startSession() } label: {
                    Label("Begin Battle", systemImage: "play.fill")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(FQColor.accent, in: pill)
                }
                .buttonStyle(.plain)
                .disabled(model.selectedSubject == nil)
                .opacity(model.selectedSubject == nil ? 0.35 : 1)
                .accessibilityHint(model.selectedSubject == nil ? "Choose a subject first" : "")
            }
        case .awaitingFlatPlacement:
            // Hodiny jeste nebezi, takze zruseni nic nestoji.
            actionCircle("xmark", caption: "Cancel", tint: nil) { model.retreat() }
        case .focusing, .paused, .warningCountdown:
            HStack(spacing: FQSpace.xxxl) {
                if isPaused {
                    actionCircle("play.fill", caption: "Resume", tint: FQColor.accent) { model.resumeBattle() }
                } else {
                    actionCircle("pause.fill", caption: "Pause", tint: nil) { model.pauseBattle() }
                }
                actionCircle("flag.fill", caption: "Retreat", tint: FQColor.danger) { showsRetreatConfirm = true }
            }
        }
    }

    /// Predmet je povinny - bez nej bitva nezacne.
    private var subjectPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FQSpace.sm) {
                ForEach(StudySubject.allCases) { subject in
                    let isSelected = subject == model.selectedSubject
                    Button { model.selectSubject(subject) } label: {
                        Label(subject.title, systemImage: subject.symbol)
                            .font(.fqLabel)
                            .foregroundStyle(isSelected ? FQColor.onAccent : FQColor.textPrimary)
                            .padding(.horizontal, FQSpace.lg)
                            .frame(height: 40)
                            .background(isSelected ? AnyShapeStyle(FQColor.accent) : AnyShapeStyle(FQColor.fill), in: pill)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    /// Velke kulate tlacitko s popiskem pod nim (Pause / Resume / Retreat / Cancel).
    private func actionCircle(_ symbol: String, caption: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: FQSpace.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint ?? FQColor.textPrimary)
                    .frame(width: 76, height: 76)
                    .background((tint ?? Color.white).opacity(tint == nil ? 0.10 : 0.16), in: Circle())
                    .overlay { Circle().strokeBorder((tint ?? Color.white).opacity(0.25), lineWidth: 1) }
                Text(caption).font(.fqLabel).foregroundStyle(FQColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Working on

    /// Co chce hrac v teto bitve stihnout. Je soucasti hlavni karty, bez vlastniho ramecku.
    private var workingOnSection: some View {
        let doneCount = model.tasks.filter(\.isDone).count
        return VStack(alignment: .leading, spacing: FQSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Working on").font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                if !model.tasks.isEmpty {
                    Text("\(doneCount) of \(model.tasks.count) done").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                }
            }
            ForEach(model.tasks) { task in
                HStack(spacing: FQSpace.xs) {
                    Button { model.toggleTask(task.id) } label: {
                        HStack(spacing: FQSpace.md) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(task.isDone ? FQColor.accent : FQColor.textSecondary)
                            Text(task.title)
                                .font(.fqBody)
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? FQColor.textSecondary : FQColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(task.isDone ? .isSelected : [])
                    Button { model.removeTask(task.id) } label: {
                        Image(systemName: "xmark")
                            .font(.fqMeta.weight(.semibold))
                            .foregroundStyle(FQColor.textTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(task.title)")
                }
            }
            if model.tasks.count < ArenaViewModel.maxTasks {
                HStack(spacing: FQSpace.md) {
                    Image(systemName: "plus").font(.fqLabel).foregroundStyle(FQColor.textSecondary).accessibilityHidden(true)
                    TextField("Add a task", text: $newTask)
                        .font(.fqBody)
                        .foregroundStyle(FQColor.textPrimary)
                        .focused($taskFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addTask)
                    if !newTask.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Add", action: addTask)
                            .font(.fqLabel)
                            .foregroundStyle(FQColor.accent)
                    }
                }
                .padding(.horizontal, FQSpace.lg)
                .frame(minHeight: 48)
                .background(FQColor.fill, in: pill)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addTask() {
        model.addTask(newTask)
        newTask = ""
        // Klavesnice zustane otevrena, aby slo pridat vic ukolu za sebou.
        taskFieldFocused = model.tasks.count < ArenaViewModel.maxTasks
    }

    // MARK: - Ustup

    /// Varovani pred ustupem pres celou obrazovku: rozmazane pozadi, vyrazne "Stay and Fight"
    /// a nenapadne "Retreat Anyway" pod nim.
    private var retreatDialog: some View {
        let streak = profileModel.stats.currentStreak()
        let focused = ArenaView.durationText(minutes: elapsed / 60)
        return ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: FQSpace.xxl) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [FQColor.danger.opacity(0.35), Color.clear], center: .center, startRadius: 0, endRadius: 90))
                        .frame(width: 180, height: 180)
                    PixelArtAvatarView(sprite: .boss(model.selectedBoss.pixelSpriteConfig), hitFlash: false, size: 112)
                }
                .frame(height: 140)
                .accessibilityHidden(true)
                VStack(spacing: FQSpace.md) {
                    Text("Don't let \(model.selectedBoss.name) win")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textPrimary)
                    Text(elapsed >= 60
                         ? "You've already focused for \(focused). Only \(clockText) to go. Your hero is counting on you."
                         : "The battle has only just begun. Your hero is counting on you.")
                        .font(.fqBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                }
                VStack(spacing: FQSpace.sm) {
                    Label("You lose \(PlayerStats.heroHPLossPerFailedQuest) hero HP", systemImage: "heart.slash.fill")
                    Label(streak > 0 ? "Your \(streak)-day streak resets" : "This battle's time won't count", systemImage: streak > 0 ? "flame.fill" : "clock.badge.xmark")
                }
                .font(.fqLabel)
                .foregroundStyle(FQColor.danger)
                VStack(spacing: FQSpace.md) {
                    Button { showsRetreatConfirm = false } label: {
                        Text("Stay and Fight")
                            .font(.fqHeadline)
                            .foregroundStyle(FQColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(FQColor.accent, in: pill)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showsRetreatConfirm = false
                        model.retreat()
                    } label: {
                        Text("Retreat Anyway")
                            .font(.fqLabel)
                            .foregroundStyle(FQColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FQSpace.xxl)
            .frame(maxWidth: 440)
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Zvuk a pravidla (list)

    private var battleSettingsSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FQSpace.xl) {
                Text("Sound & rules").font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                soundPlayer
                rulesCard
            }
            .padding(FQSpace.gutter)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }

    /// Pravidla bitvy: pevna delka, telefon na stole, pauza kdykoli, ustup stoji HP.
    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            if model.isCustomBattle {
                rule(symbol: "timer", title: "Custom \(durationText)", detail: "A random boss you've unlocked. Custom battles don't move you along the path.")
            } else {
                rule(symbol: "timer", title: "Fixed \(durationText)", detail: "Node \(model.selectedBoss.nodeIndex + 1) of the path. Every node adds 5 minutes.")
            }
            rule(symbol: "iphone.gen3", title: "Phone face-up on the desk", detail: "Lifting it starts a short countdown. Pause first if you need the phone.")
            rule(symbol: "pause.circle", title: "Pause any time", detail: "The clock stops while you're paused.")
            rule(symbol: "flag", title: "Retreating costs \(PlayerStats.heroHPLossPerFailedQuest) hero HP", detail: "Your streak resets too.")
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func rule(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: FQSpace.md) {
            IconTile(symbol: symbol, color: world.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.fqLabel).foregroundStyle(FQColor.textPrimary)
                Text(detail).font(.fqMeta).foregroundStyle(FQColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(FQColor.textPrimary)
                .frame(width: 44, height: 44)
                .glassControl(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var soundPlayer: some View {
        let preferences = model.preferences
        let status = !preferences.isMusicEnabled ? "Sound is off" : (isFocusing ? "Now playing" : (isPaused ? "Paused" : "Plays when the battle starts"))
        return VStack(spacing: FQSpace.md) {
            HStack(spacing: FQSpace.md) {
                IconTile(symbol: preferences.soundscape == .lofi ? "music.note" : "waveform")
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text(preferences.soundscape == .lofi ? preferences.selectedTrack.title : preferences.soundscape.title)
                        .font(.fqBody.weight(.medium))
                        .foregroundStyle(FQColor.textPrimary)
                        .lineLimit(1)
                    Text(status).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: FQSpace.sm)
                if preferences.soundscape == .lofi {
                    roundButton("forward.fill", label: "Next track") { model.skipTrack() }
                }
                roundButton(preferences.isMusicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", label: preferences.isMusicEnabled ? "Turn sound off" : "Turn sound on") {
                    model.setMusicEnabled(!preferences.isMusicEnabled)
                }
            }
            Picker("Sound", selection: Binding(get: { preferences.soundscape }, set: { model.setSoundscape($0) })) {
                ForEach(Soundscape.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: FQSpace.md) {
                Image(systemName: "speaker.fill").font(.fqMeta).foregroundStyle(FQColor.textSecondary).accessibilityHidden(true)
                Slider(value: Binding(get: { preferences.ambientVolume }, set: { model.setVolume($0) }), in: 0...1)
                    .tint(FQColor.accent)
                    .accessibilityLabel("Sound volume")
                Image(systemName: "speaker.wave.3.fill").font(.fqMeta).foregroundStyle(FQColor.textSecondary).accessibilityHidden(true)
            }
        }
        .padding(FQSpace.lg)
        .glassCard()
    }

    #if targetEnvironment(simulator)
    private var simulatorControls: some View {
        HStack(spacing: FQSpace.sm) {
            Button("Simulate Flat") { Task { await model.setSimulatedPosture(.flatFaceUp) } }
            Button("Simulate Lift") { Task { await model.setSimulatedPosture(.liftedOrTilted) } }
        }
        .font(.fqMeta)
        .buttonStyle(.bordered)
        .tint(FQColor.textSecondary)
        .frame(maxWidth: .infinity)
    }
    #endif

    // MARK: - Prekryvy

    /// Obrazovka vitezstvi: porazeny boss, ziskane XP, mince a pripadny loot.
    private func victoryOverlay(_ victory: BattleVictory) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: FQSpace.lg) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [world.accent.opacity(0.45), Color.clear], center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 160, height: 160)
                    PixelArtAvatarView(sprite: .boss(victory.boss.pixelSpriteConfig), size: 96)
                        .opacity(0.55)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(FQColor.accent)
                        .offset(x: 44, y: 40)
                        .accessibilityHidden(true)
                }
                .frame(height: 140)
                VStack(spacing: FQSpace.xs) {
                    Text("Victory!").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(FQColor.textPrimary)
                    Text("\(victory.boss.name) defeated · \(victory.subject.title), \(ArenaView.durationText(minutes: victory.verifiedMinutes))")
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                    if victory.boss.isDefeated, !victory.isCustom, let next = nextNode(after: victory.boss) {
                        Label("Unlocked: \(next.name) · \(ArenaView.durationText(minutes: next.maxHP))", systemImage: "lock.open.fill")
                            .font(.fqLabel)
                            .foregroundStyle(world.accent)
                            .padding(.top, FQSpace.xs)
                    }
                }
                HStack(spacing: FQSpace.sm) {
                    rewardTile(value: "+\(victory.xpEarned)", label: "XP", symbol: "sparkles")
                    rewardTile(value: "+\(victory.coinsEarned)", label: "Coins", symbol: "dollarsign.circle.fill")
                }
                if let loot = victory.droppedLoot {
                    Label("\(loot.name) found", systemImage: "gift.fill")
                        .font(.fqLabel)
                        .foregroundStyle(FQColor.textPrimary)
                }
                Button(action: closeResult) {
                    Text("Collect Loot")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
                .controlSize(.large)
                .tint(FQColor.accent)
            }
            .padding(FQSpace.xl)
            .frame(maxWidth: 360)
            .glassCard(prominent: true)
            .padding(.horizontal, FQSpace.xl)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .accessibilityAddTraits(.isModal)
    }

    private func nextNode(after boss: Boss) -> Boss? {
        let list = boss.world.bosses
        let next = boss.nodeIndex + 1
        return next < list.count ? list[next] : nil
    }

    private func rewardTile(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: FQSpace.xs) {
            Image(systemName: symbol).font(.fqLabel).foregroundStyle(FQColor.accent).accessibilityHidden(true)
            Text(value).font(.fqTitle).monospacedDigit().foregroundStyle(FQColor.textPrimary)
            Text(label).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FQSpace.md)
        .background(FQColor.fill, in: RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func warningOverlay(seconds: Double) -> some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.62, green: 0.04, blue: 0.14), Color(red: 0.34, green: 0.01, blue: 0.08)], startPoint: .top, endPoint: .bottom)
                .opacity(0.94)
                .ignoresSafeArea()
            VStack(spacing: FQSpace.lg) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: true, size: 112)
                Text("\(Int(ceil(seconds)))")
                    .font(.system(size: 112, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
                    .contentTransition(.numericText())
                VStack(spacing: FQSpace.sm) {
                    Text("Return phone to desk")
                        .font(.fqTitle)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textPrimary)
                    Text("Combo and verified rewards are at risk")
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
                }
            }
            .padding(FQSpace.xl)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: Int(ceil(seconds)))
        .accessibilityAddTraits(.isModal)
        // Varovna obrazovka je cervena v obou rezimech, text na ni musi zustat svetly.
        .environment(\.colorScheme, .dark)
    }

    private func resultOverlay(icon: String, title: String, detail: String, color: Color) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: FQSpace.lg) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text(title).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Text(detail).font(.fqSecondary).multilineTextAlignment(.center).foregroundStyle(FQColor.textSecondary)
                }
                Button(action: closeResult) {
                    Text("Back to the Path")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.roundedRectangle(radius: FQRadius.control))
                .controlSize(.large)
                .tint(FQColor.accent)
            }
            .padding(FQSpace.xl)
            .frame(maxWidth: 360)
            .glassCard(prominent: true)
            .padding(.horizontal, FQSpace.xl)
        }
        .accessibilityAddTraits(.isModal)
    }
}
