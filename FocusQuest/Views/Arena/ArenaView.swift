import SwiftUI

struct ArenaView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    @State private var receipt: UIImage?
    /// Kategorie bossu, kterou si hrac prohlizi; nil = kategorie vybraneho bosse.
    @State private var shownCategory: BossCategory?

    private var isWarning: Bool { if case .warningCountdown = model.state { true } else { false } }
    private var isIdle: Bool { if case .idle = model.state { true } else { false } }
    private var elapsed: Int {
        switch model.state {
        case .focusing(let value, _): value
        case .warningCountdown(_, let value): value
        default: 0
        }
    }
    private var comboValue: Int { if case let .focusing(_, combo) = model.state { combo } else { model.activeSession?.comboMultiplier ?? 1 } }
    /// Odpocet do konce bitvy; pred bitvou ukazuje celou delku.
    private var remaining: Int { max(0, model.targetSeconds - elapsed) }
    private var clockText: String { String(format: "%02d:%02d:%02d", remaining / 3600, (remaining / 60) % 60, remaining % 60) }

    var body: some View {
        ZStack {
            ScreenScaffold(alert: isWarning) {
                header
                subjectPicker
                bossSelector
                battleStage
                bossHPCard
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
                resultOverlay(icon: "xmark.shield.fill", title: "Combo broken", detail: reason, color: FQColor.danger)
            }
            if case let .victory(victory) = model.state { victoryOverlay(victory) }
        }
        // Cervena obrazovka s odpoctem ma zabrat opravdu cely displej.
        .toolbar(isWarning ? .hidden : .visible, for: .tabBar)
        .animation(.easeOut(duration: 0.25), value: isVictory)
        .onChange(of: model.state) { _, value in
            // Odmenu uz pripsal model; obrazovka si jen pripravi sdilitelnou uctenku.
            if case let .victory(victory) = value {
                receipt = BattleReceiptRenderer.render(profile: profileModel.profile, boss: victory.boss, focusMinutes: victory.verifiedMinutes, flawless: true)
            }
        }
    }

    private var isVictory: Bool { if case .victory = model.state { true } else { false } }

    /// "25 min" nebo "1 h 30 min".
    static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }

    // MARK: - HP bosse

    private var bossHPCard: some View {
        VStack(alignment: .leading, spacing: FQSpace.md) {
            HStack(spacing: FQSpace.sm) {
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    Text("Boss HP").font(.fqLabel).foregroundStyle(FQColor.textSecondary)
                    Text("\(model.bossMinutes) HP")
                        .font(.fqTitle)
                        .monospacedDigit()
                        .foregroundStyle(FQColor.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: FQSpace.sm)
                roundButton("minus", label: "Five minutes less") { model.setBossMinutes(model.bossMinutes - Boss.minutesStep) }
                    .disabled(model.bossMinutes <= Boss.minutesRange.lowerBound)
                roundButton("plus", label: "Five minutes more") { model.setBossMinutes(model.bossMinutes + Boss.minutesStep) }
                    .disabled(model.bossMinutes >= Boss.minutesRange.upperBound)
            }
            Slider(
                value: Binding(get: { Double(model.bossMinutes) }, set: { model.setBossMinutes(Int($0.rounded())) }),
                in: Double(Boss.minutesRange.lowerBound)...Double(Boss.minutesRange.upperBound),
                step: Double(Boss.minutesStep)
            )
            .tint(FQColor.accent)
            .accessibilityLabel("Boss HP")
            .accessibilityValue("\(model.bossMinutes) minutes")
            Text("\(model.selectedBoss.name) only. 1 HP = 1 minute of verified focus. This battle takes \(Self.durationText(minutes: model.bossMinutes)).")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
        }
        .padding(FQSpace.lg)
        .glassCard()
        .disabled(!isIdle)
        .opacity(isIdle ? 1 : 0.6)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FQColor.textPrimary)
                .frame(width: 44, height: 44)
                .glassControl(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Prehravac

    private var soundPlayer: some View {
        let preferences = model.preferences
        let isFocusing = if case .focusing = model.state { true } else { false }
        let status = !preferences.isMusicEnabled ? "Sound is off" : (isFocusing ? "Now playing" : "Plays when the battle starts")
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

    // MARK: - Sekce

    private var header: some View {
        ScreenTitle(eyebrow: "Arena", title: "Study battle")
            .frame(maxWidth: .infinity, alignment: .leading)
    }

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
                                .glassControl(in: Capsule(), tint: isSelected ? FQColor.accent.opacity(0.35) : nil, interactive: true)
                                .overlay { Capsule().strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 1) }
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

    private var bossSelector: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            Picker("Boss category", selection: Binding(get: { shownCategory ?? model.selectedBoss.category }, set: { shownCategory = $0 })) {
                ForEach(BossCategory.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            bossRow(shownCategory ?? model.selectedBoss.category)
        }
        .disabled(!isIdle)
        .opacity(isIdle ? 1 : 0.6)
    }

    private func bossRow(_ category: BossCategory) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FQSpace.sm) {
                ForEach(category.bosses) { boss in
                    let isSelected = boss.id == model.selectedBoss.id
                    Button { model.selectBoss(boss) } label: {
                        HStack(spacing: FQSpace.sm) {
                            PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 32)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(boss.name).font(.fqLabel).foregroundStyle(FQColor.textPrimary)
                                Text("\(model.preferences.bossMinutes(for: boss.id)) HP").font(.fqMeta).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                            }
                        }
                        .padding(.leading, FQSpace.sm)
                        .padding(.trailing, FQSpace.lg)
                        .padding(.vertical, FQSpace.sm)
                        .glassControl(in: Capsule(), tint: isSelected ? FQColor.accent.opacity(0.35) : nil, interactive: true)
                        .overlay { Capsule().strokeBorder(isSelected ? FQColor.accent : Color.clear, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, FQSpace.xs)
        }
        .scrollClipDisabled()
    }

    private var battleStage: some View {
        VStack(spacing: FQSpace.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(isWarning ? FQColor.danger : FQColor.accent).opacity(0.22), Color.clear], center: .center, startRadius: 0, endRadius: 88))
                    .frame(width: 176, height: 176)
                PixelArtAvatarView(sprite: .boss(model.selectedBoss.pixelSpriteConfig), hitFlash: false, size: 112)
            }
            .frame(height: 120)

            VStack(spacing: FQSpace.xs) {
                Text(model.selectedBoss.name).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text("\(Self.durationText(minutes: model.selectedBoss.maxHP)) battle").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }

            Text(clockText)
                .font(.system(size: 48, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(FQColor.textPrimary)
                .contentTransition(.numericText())
                .animation(.default, value: elapsed)
                .accessibilityLabel("Time left \(clockText)")

            HStack(spacing: FQSpace.sm) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: isWarning, size: 32)
                Text("Combo \(comboValue)x").font(.fqLabel).foregroundStyle(FQColor.accent)
            }
            .padding(.leading, FQSpace.sm)
            .padding(.trailing, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .background(FQColor.fill, in: Capsule())

            HairlineDivider()

            BossHealthBarView(currentHP: model.selectedBoss.currentHP, maxHP: model.selectedBoss.maxHP)
        }
        .padding(.horizontal, FQSpace.xl)
        .padding(.vertical, FQSpace.lg)
        .frame(maxWidth: .infinity)
        .glassCard(tint: isWarning ? FQColor.danger : nil)
    }

    @ViewBuilder private var sessionControls: some View {
        switch model.state {
        case .idle, .penalized, .victory:
            Button { model.startSession() } label: {
                Label(model.selectedSubject == nil ? "Choose a subject first" : "Begin Focus Battle", systemImage: "play.fill")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FQSpace.xs)
            }
            .prominentGlassButtonStyle()
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(FQColor.accent)
            .disabled(model.selectedSubject == nil)
        case .awaitingFlatPlacement:
            Label("Place iPhone face-up on desk", systemImage: "iphone.gen3.radiowaves.left.and.right")
                .font(.fqLabel)
                .foregroundStyle(FQColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(FQSpace.lg)
                .glassCard(radius: FQRadius.control)
        case .focusing, .warningCountdown:
            Button(role: .destructive) { model.stopSession() } label: {
                Label("Surrender Battle", systemImage: "flag.fill")
                    .font(.fqHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FQSpace.xs)
            }
            .glassButtonStyle()
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(FQColor.danger)
        }
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
                        .fill(RadialGradient(colors: [FQColor.accent.opacity(0.45), Color.clear], center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 160, height: 160)
                    PixelArtAvatarView(sprite: .boss(victory.boss.pixelSpriteConfig), size: 96)
                        .opacity(0.55)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(FQColor.accent)
                        .offset(x: 44, y: 40)
                        .accessibilityHidden(true)
                }
                .frame(height: 140)
                VStack(spacing: FQSpace.xs) {
                    Text("Victory!").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(FQColor.textPrimary)
                    Text("\(victory.boss.name) defeated · \(victory.subject.title), \(Self.durationText(minutes: victory.verifiedMinutes))")
                        .font(.fqSecondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FQColor.textSecondary)
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
                Button { model.stopSession() } label: {
                    Text("Collect Loot")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(FQColor.accent)
            }
            .padding(FQSpace.xl)
            .frame(maxWidth: 360)
            .glassCard()
            .padding(.horizontal, FQSpace.xl)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .accessibilityAddTraits(.isModal)
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
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                VStack(spacing: FQSpace.sm) {
                    Text(title).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                    Text(detail).font(.fqSecondary).multilineTextAlignment(.center).foregroundStyle(FQColor.textSecondary)
                }
                Button { model.stopSession() } label: {
                    Text("Return to Arena")
                        .font(.fqHeadline)
                        .foregroundStyle(FQColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FQSpace.xs)
                }
                .prominentGlassButtonStyle()
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(FQColor.accent)
            }
            .padding(FQSpace.xl)
            .frame(maxWidth: 360)
            .glassCard()
            .padding(.horizontal, FQSpace.xl)
        }
        .accessibilityAddTraits(.isModal)
    }
}
