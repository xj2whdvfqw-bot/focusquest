import SwiftUI

struct ArenaView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    @State private var receipt: UIImage?

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
    private var clockText: String { String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed / 60) % 60, elapsed % 60) }

    var body: some View {
        ZStack {
            ScreenScaffold(alert: isWarning) {
                header
                VStack(alignment: .leading, spacing: FQSpace.md) {
                    modePicker
                    bossSelector
                    if model.mode == .raid { raidPartyBar }
                }
                battleStage
                sessionControls
                #if targetEnvironment(simulator)
                simulatorControls
                #endif
                if let partyAlert = model.partyAlert { partyAlertBanner(partyAlert) }
                if let receipt { BattleReceiptShareView(image: receipt) }
            }
            if case let .warningCountdown(seconds, _) = model.state { warningOverlay(seconds: seconds) }
            if case let .penalized(reason) = model.state {
                resultOverlay(icon: "xmark.shield.fill", title: "Combo broken", detail: reason, color: FQColor.danger)
            }
            if case let .victory(boss, _, loot) = model.state {
                resultOverlay(icon: "trophy.fill", title: "Victory", detail: loot.map { "\(boss.name) defeated. \($0.name) found." } ?? "\(boss.name) defeated.", color: FQColor.accent)
            }
        }
        // Cervena obrazovka s odpoctem ma zabrat opravdu cely displej.
        .toolbar(isWarning ? .hidden : .visible, for: .tabBar)
        .onChange(of: model.state) { _, value in
            if case let .victory(boss, _, loot) = value {
                profileModel.unlockLoot(loot)
                receipt = BattleReceiptRenderer.render(profile: profileModel.profile, boss: boss, focusMinutes: elapsed / 60, flawless: true)
            }
        }
    }

    // MARK: - Sekce

    private var header: some View {
        HStack(alignment: .bottom) {
            ScreenTitle(eyebrow: "Arena", title: "Study battle")
            Spacer(minLength: FQSpace.sm)
            StatusPill(
                text: model.posture == .flatFaceUp ? "Phone flat" : "Place phone flat",
                color: model.posture == .flatFaceUp ? FQColor.accent : FQColor.caution
            )
            .padding(.bottom, FQSpace.xs)
        }
    }

    private var modePicker: some View {
        Picker("Battle mode", selection: $model.mode) {
            Text("Solo battle").tag(SessionMode.solo)
            Text("Co-op raid").tag(SessionMode.raid)
        }
        .pickerStyle(.segmented)
        .disabled(!isIdle)
    }

    private var bossSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FQSpace.sm) {
                ForEach(Boss.roster) { boss in
                    let isSelected = boss.id == model.selectedBoss.id
                    Button { model.selectBoss(boss) } label: {
                        HStack(spacing: FQSpace.sm) {
                            PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 32)
                            Text(boss.name).font(.fqLabel).foregroundStyle(FQColor.textPrimary)
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
        .disabled(!isIdle)
        .opacity(isIdle ? 1 : 0.6)
    }

    private var raidPartyBar: some View {
        HStack(spacing: FQSpace.sm) {
            if model.partyMembers.isEmpty {
                Label("Raid party - up to 4 players", systemImage: "person.3.fill")
                    .font(.fqSecondary)
                    .foregroundStyle(FQColor.textSecondary)
            }
            ForEach(model.partyMembers) { member in
                HStack(spacing: FQSpace.sm) {
                    Circle().fill(member.isFocusing ? FQColor.accent : FQColor.caution).frame(width: 8, height: 8)
                    Text(member.displayName).font(.fqMeta.weight(.medium))
                }
                .padding(.horizontal, FQSpace.md)
                .padding(.vertical, FQSpace.sm)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FQSpace.md)
        .glassCard(radius: FQRadius.control)
    }

    private var battleStage: some View {
        VStack(spacing: FQSpace.lg) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(isWarning ? FQColor.danger : FQColor.accent).opacity(0.22), Color.clear], center: .center, startRadius: 0, endRadius: 104))
                    .frame(width: 208, height: 208)
                PixelArtAvatarView(sprite: .boss(model.selectedBoss.pixelSpriteConfig), hitFlash: false, size: 144)
            }
            .frame(height: 176)

            VStack(spacing: FQSpace.xs) {
                Text(model.selectedBoss.name).font(.fqTitle).foregroundStyle(FQColor.textPrimary)
                Text("\(model.selectedBoss.tier.rawValue.capitalized) boss").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }

            Text(clockText)
                .font(.system(size: 48, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(FQColor.textPrimary)
                .contentTransition(.numericText())
                .animation(.default, value: elapsed)
                .accessibilityLabel("Focus time \(clockText)")

            HStack(spacing: FQSpace.sm) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: isWarning, size: 32)
                Text("Combo \(comboValue)x").font(.fqLabel).foregroundStyle(FQColor.accent)
            }
            .padding(.leading, FQSpace.sm)
            .padding(.trailing, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .background(Color.white.opacity(0.08), in: Capsule())

            HairlineDivider()

            BossHealthBarView(currentHP: model.selectedBoss.currentHP, maxHP: model.selectedBoss.maxHP)
        }
        .padding(FQSpace.xl)
        .frame(maxWidth: .infinity)
        .glassCard(tint: isWarning ? FQColor.danger : nil)
    }

    @ViewBuilder private var sessionControls: some View {
        switch model.state {
        case .idle, .penalized, .victory:
            Button { model.startSession() } label: {
                Label("Begin Focus Battle", systemImage: "play.fill")
                    .font(.fqHeadline)
                    .foregroundStyle(FQColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FQSpace.xs)
            }
            .prominentGlassButtonStyle()
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(FQColor.accent)
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

    private func partyAlertBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.fqLabel)
            .foregroundStyle(FQColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FQSpace.lg)
            .glassCard(radius: FQRadius.control, tint: FQColor.danger)
    }

    // MARK: - Prekryvy

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
