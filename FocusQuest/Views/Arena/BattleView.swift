import SwiftUI

/// Bitva s vybranym uzlem cesty. Delka je pevna podle uzlu - hrac ji nemeni.
struct BattleView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    /// Zavola se po zavreni vysledku bitvy (navrat na cestu sveta).
    let onExit: () -> Void
    @State private var receipt: UIImage?
    @State private var showsRetreatConfirm = false
    @State private var newTask = ""
    @FocusState private var taskFieldFocused: Bool

    private var pill: RoundedRectangle { RoundedRectangle(cornerRadius: FQRadius.control, style: .continuous) }
    private var world: BossWorld { model.selectedBoss.world }
    private var isWarning: Bool { if case .warningCountdown = model.state { true } else { false } }
    private var isPaused: Bool { if case .paused = model.state { true } else { false } }
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

    var body: some View {
        ZStack {
            ScreenScaffold(alert: isWarning, scene: world.scene) {
                subjectPicker
                battleStage
                workingOnCard
                rulesCard
                soundPlayer
                #if targetEnvironment(simulator)
                simulatorControls
                #endif
                if let receipt { BattleReceiptShareView(image: receipt) }
            }
            // Hlavni akce je pripnuta nad spodni listou, aby byla videt bez rolovani.
            .pinnedBottomAction { sessionControls }
            if case let .warningCountdown(seconds, _) = model.state { warningOverlay(seconds: seconds) }
            if case let .penalized(reason) = model.state {
                resultOverlay(icon: "xmark.shield.fill", title: "Quest failed", detail: reason, color: FQColor.danger)
            }
            if case let .defeated(defeat) = model.state {
                resultOverlay(icon: "flag.fill", title: "You retreated", detail: defeatDetail(defeat), color: FQColor.danger)
            }
            if case let .victory(victory) = model.state { victoryOverlay(victory) }
        }
        .navigationTitle(model.isCustomBattle ? "Custom Battle" : "Node \(model.selectedBoss.nodeIndex + 1) · \(world.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        // Behem bitvy se z ni neda odejit tlacitkem zpet - jen vzdat.
        .navigationBarBackButtonHidden(!model.isBetweenBattles)
        // Cervena obrazovka s odpoctem ma zabrat opravdu cely displej.
        .toolbar(isWarning ? .hidden : .visible, for: .tabBar)
        .toolbar(isWarning ? .hidden : .visible, for: .navigationBar)
        .animation(.easeOut(duration: 0.25), value: isVictory)
        // Ustup stoji HP hrdiny a serii, proto se potvrzuje pojmenovanym tlacitkem.
        .confirmationDialog("Retreat from \(model.selectedBoss.name)?", isPresented: $showsRetreatConfirm, titleVisibility: .visible) {
            Button("Retreat Anyway", role: .destructive) { model.retreat() }
            Button("Keep Fighting", role: .cancel) {}
        } message: {
            Text("You lose \(PlayerStats.heroHPLossPerFailedQuest) hero HP and your streak resets. Time focused in this battle won't count.")
        }
        .onChange(of: model.state) { _, value in
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

    private func defeatDetail(_ defeat: BattleDefeat) -> String {
        let focused = ArenaView.durationText(minutes: defeat.focusedMinutes)
        let goal = ArenaView.durationText(minutes: defeat.goalMinutes)
        return "\(defeat.boss.name) escaped after \(focused) of \(goal). You lost \(defeat.heroHPLost) hero HP and your streak resets."
    }

    // MARK: - Sekce

    /// Predmet je povinny - bez nej tlacitko bitvy nejde zmacknout.
    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            Text(model.selectedSubject == nil ? "Choose what you study" : "Studying")
                .font(.fqLabel)
                .foregroundStyle(model.selectedSubject == nil ? FQColor.caution : FQColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FQSpace.sm) {
                    ForEach(StudySubject.allCases) { subject in
                        let isSelected = subject == model.selectedSubject
                        Button { model.selectSubject(subject) } label: {
                            Label(subject.title, systemImage: subject.symbol)
                                .font(.fqLabel)
                                .foregroundStyle(FQColor.textPrimary)
                                .padding(.horizontal, FQSpace.lg)
                                .padding(.vertical, FQSpace.sm)
                                .glassControl(in: pill, tint: isSelected ? FQColor.accent.opacity(0.35) : nil, interactive: true)
                                .overlay { pill.strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, FQSpace.xs)
            }
            .scrollClipDisabled()
        }
        .disabled(!isIdle)
        .opacity(isIdle ? 1 : 0.6)
    }

    private var battleStage: some View {
        VStack(spacing: FQSpace.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(isWarning ? FQColor.danger : world.accent).opacity(0.28), Color.clear], center: .center, startRadius: 0, endRadius: 88))
                    .frame(width: 176, height: 176)
                PixelArtAvatarView(sprite: .boss(model.selectedBoss.pixelSpriteConfig), hitFlash: false, size: 112)
            }
            .frame(height: 120)

            VStack(spacing: FQSpace.xs) {
                Text(model.selectedBoss.name).font(.fqTitle).foregroundStyle(FQColor.textPrimary).multilineTextAlignment(.center)
                Text("\(model.selectedBoss.tier.rawValue.capitalized) · \(durationText) battle")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
            }

            // Odpocet primo pod bossem: hlavni informace obrazovky, proto obri cislice.
            Text(clockText)
                .font(.fqTimer)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(isPaused ? FQColor.textSecondary : FQColor.textPrimary)
                .contentTransition(.numericText())
                .animation(.default, value: elapsed)
                .accessibilityLabel(isPaused ? "Paused, \(clockText) left" : "Time left \(clockText)")

            if isPaused {
                Label("Paused · the clock is stopped", systemImage: "pause.fill")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.caution)
            }

            HStack(spacing: FQSpace.sm) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: isWarning, size: 32)
                Text("Combo \(comboValue)x").font(.fqLabel).foregroundStyle(FQColor.accent)
            }
            .padding(.leading, FQSpace.sm)
            .padding(.trailing, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .background(FQColor.fill, in: pill)

            HairlineDivider()

            BossHealthBarView(currentHP: model.selectedBoss.currentHP, maxHP: model.selectedBoss.maxHP)
        }
        .padding(.horizontal, FQSpace.xl)
        .padding(.vertical, FQSpace.lg)
        .frame(maxWidth: .infinity)
        .glassCard(tint: isWarning ? FQColor.danger : nil)
    }

    /// Karta "Working on": co chce hrac v teto bitve stihnout. Jde plnit pred bitvou i behem ni.
    private var workingOnCard: some View {
        let doneCount = model.tasks.filter(\.isDone).count
        return VStack(alignment: .leading, spacing: FQSpace.md) {
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
                            .foregroundStyle(FQColor.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(task.title)")
                }
            }
            if model.tasks.count < ArenaViewModel.maxTasks {
                HStack(spacing: FQSpace.sm) {
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
                .frame(minHeight: 44)
                .background(FQColor.fill, in: pill)
            }
        }
        .padding(FQSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func addTask() {
        model.addTask(newTask)
        newTask = ""
        // Klavesnice zustane otevrena, aby slo pridat vic ukolu za sebou.
        taskFieldFocused = model.tasks.count < ArenaViewModel.maxTasks
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
        let isFocusing = if case .focusing = model.state { true } else { false }
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

    // MARK: - Ovladani

    @ViewBuilder private var sessionControls: some View {
        switch model.state {
        case .idle, .penalized, .victory, .defeated:
            if model.selectedSubject == nil {
                // Vypnute tlacitko by na skle bylo necitelne; misto nej jasna vyzva.
                Label("Choose a subject above to start", systemImage: "books.vertical.fill")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(FQSpace.lg)
                    .glassCard(radius: FQRadius.control, tint: FQColor.caution)
            } else {
                Button { model.startSession() } label: {
                    Label("Begin \(durationText) Battle", systemImage: "play.fill")
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
        case .awaitingFlatPlacement:
            HStack(spacing: FQSpace.md) {
                Label("Place iPhone face-up on desk", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    .font(.fqLabel)
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(FQSpace.lg)
                    .glassCard(radius: FQRadius.control)
                // Hodiny jeste nebezi, takze zruseni nic nestoji (zpet tlacitko je behem bitvy skryte).
                actionCircle("xmark", caption: "Cancel", tint: nil) { model.retreat() }
            }
        case .focusing, .paused, .warningCountdown:
            HStack(spacing: FQSpace.xxl) {
                if isPaused {
                    actionCircle("play.fill", caption: "Resume", tint: FQColor.accent) { model.resumeBattle() }
                } else {
                    actionCircle("pause.fill", caption: "Pause", tint: nil) { model.pauseBattle() }
                }
                actionCircle("flag.fill", caption: "Retreat", tint: FQColor.danger) { showsRetreatConfirm = true }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Kulate tlacitko s popiskem pod nim (Pause / Resume / Retreat / Cancel).
    private func actionCircle(_ symbol: String, caption: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: FQSpace.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint ?? FQColor.textPrimary)
                    .frame(width: 64, height: 64)
                    .glassControl(in: Circle(), tint: tint?.opacity(0.18), interactive: true)
                Text(caption).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityAddTraits(.isButton)
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
