import SwiftUI

struct ArenaView: View {
    @ObservedObject var model: ArenaViewModel
    @ObservedObject var profileModel: ProfileViewModel
    @State private var receipt: UIImage?

    private var isWarning: Bool { if case .warningCountdown = model.state { true } else { false } }
    private var elapsed: Int {
        switch model.state {
        case .focusing(let value, _): value
        case .warningCountdown(_, let value): value
        default: 0
        }
    }

    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: isWarning)
            ScrollView {
                VStack(spacing: 18) {
                    header
                    modePicker
                    bossSelector
                    if model.mode == .raid { raidPartyBar }
                    battleStage
                    BossHealthBarView(currentHP: model.selectedBoss.currentHP, maxHP: model.selectedBoss.maxHP).padding(18).glassmorphic()
                    sessionControls
                    #if targetEnvironment(simulator)
                    simulatorControls
                    #endif
                    if let partyAlert = model.partyAlert { Text(partyAlert).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white).padding(12).frame(maxWidth: .infinity).background(.red.opacity(0.75), in: Capsule()) }
                    if let receipt { BattleReceiptShareView(image: receipt) }
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 30)
            }
            if case let .warningCountdown(seconds, _) = model.state { warningOverlay(seconds: seconds) }
            if case let .penalized(reason) = model.state { resultOverlay(title: "COMBO BROKEN", detail: reason, color: .red) }
            if case let .victory(boss, _, loot) = model.state { resultOverlay(title: "VICTORY", detail: loot.map { "\(boss.name) defeated. \($0.name) found." } ?? "\(boss.name) defeated.", color: .green) }
        }
        .preferredColorScheme(.dark)
        .onChange(of: model.state) { _, value in
            if case let .victory(boss, _, loot) = value {
                profileModel.unlockLoot(loot)
                receipt = BattleReceiptRenderer.render(profile: profileModel.profile, boss: boss, focusMinutes: elapsed / 60, flawless: true)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                SectionEyebrow(title: "FocusQuest / Arena")
                Text("Study battle").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(model.posture == .flatFaceUp ? .green : .orange).frame(width: 8, height: 8)
                Text(model.posture == .flatFaceUp ? "PHONE FLAT" : "PLACE PHONE FLAT").font(.system(size: 10, weight: .bold, design: .monospaced))
            }.padding(.horizontal, 11).padding(.vertical, 8).background(.white.opacity(0.08), in: Capsule())
        }
    }

    private var modePicker: some View {
        HStack(spacing: 5) {
            ForEach([SessionMode.solo, .raid], id: \.self) { mode in
                Button { self.model.mode = mode } label: {
                    Text(mode == .solo ? "SOLO BATTLE" : "CO-OP RAID")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(self.model.mode == mode ? Color.white.opacity(0.16) : .clear, in: Capsule())
                }.buttonStyle(.plain)
            }
        }.padding(4).glassmorphic(radius: 18)
    }

    private var bossSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Boss.roster) { boss in
                    Button { model.selectBoss(boss) } label: {
                        HStack(spacing: 7) {
                            PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), size: 31)
                            Text(boss.name).font(.system(size: 12, weight: .semibold, design: .rounded))
                        }.padding(.horizontal, 10).padding(.vertical, 4).glassmorphic(radius: 16)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var raidPartyBar: some View {
        HStack(spacing: 10) {
            ForEach(model.partyMembers) { member in
                HStack(spacing: 6) {
                    Circle().fill(member.isFocusing ? .mint : .orange).frame(width: 7, height: 7)
                    Text(member.displayName).font(.system(size: 11, weight: .semibold, design: .rounded))
                }.padding(.horizontal, 9).padding(.vertical, 7).background(.white.opacity(0.08), in: Capsule())
            }
            if model.partyMembers.isEmpty { Text("Raid party - up to 4 players").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.65)) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).glassmorphic(radius: 16)
    }

    private var battleStage: some View {
        VStack(spacing: 8) {
            PixelArtAvatarView(sprite: .boss(model.selectedBoss.pixelSpriteConfig), hitFlash: false, size: 150)
            Text(model.selectedBoss.name.uppercased()).font(.system(size: 16, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(.white)
            HStack(spacing: 13) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: isWarning, size: 52)
                Text("\(elapsed / 3600, format: .number.precision(.integerLength(2))) : \((elapsed / 60) % 60, format: .number.precision(.integerLength(2))) : \(elapsed % 60, format: .number.precision(.integerLength(2)))")
                    .font(.system(size: 27, weight: .medium, design: .monospaced)).monospacedDigit().foregroundStyle(.white)
                Text("COMBO  \(comboValue)x").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.yellow)
            }.padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 13).glassmorphic(alert: isWarning)
    }

    private var comboValue: Int { if case let .focusing(_, combo) = model.state { combo } else { model.activeSession?.comboMultiplier ?? 1 } }

    @ViewBuilder private var sessionControls: some View {
        switch model.state {
        case .idle, .penalized, .victory:
            Button { model.startSession() } label: { Label("Begin Focus Battle", systemImage: "play.fill").font(.system(size: 15, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).padding(16).background(Color(red: 0.3, green: 0.78, blue: 0.67), in: Capsule()).foregroundStyle(.black) }
                .buttonStyle(.plain)
        case .awaitingFlatPlacement:
            Label("Place iPhone face-up on desk", systemImage: "iphone.gen3.radiowaves.left.and.right").font(.system(size: 13, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity).padding(15).glassmorphic()
        case .focusing, .warningCountdown:
            Button(role: .destructive) { model.stopSession() } label: { Label("Surrender Battle", systemImage: "xmark.circle").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(14).glassmorphic() }.buttonStyle(.plain)
        }
    }

    #if targetEnvironment(simulator)
    private var simulatorControls: some View {
        HStack {
            Button("Simulate Flat") { Task { await model.setSimulatedPosture(.flatFaceUp) } }
            Button("Simulate Lift") { Task { await model.setSimulatedPosture(.liftedOrTilted) } }
        }.font(.system(size: 11, weight: .medium, design: .monospaced)).buttonStyle(.bordered).tint(.white.opacity(0.75))
    }
    #endif

    private func warningOverlay(seconds: Double) -> some View {
        ZStack {
            Color(red: 0.5, green: 0.02, blue: 0.1).opacity(0.88).ignoresSafeArea()
            VStack(spacing: 17) {
                PixelArtAvatarView(sprite: .companion("lo-fi-cat"), startled: true, size: 110)
                Text("\(Int(ceil(seconds)))").font(.system(size: 106, weight: .black, design: .rounded).monospacedDigit()).foregroundStyle(.white).contentTransition(.numericText())
                Text("RETURN PHONE TO DESK IMMEDIATELY!").font(.system(size: 15, weight: .black, design: .monospaced)).multilineTextAlignment(.center).foregroundStyle(.white)
                Text("Combo and verified rewards are at risk").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.75))
            }.padding(25)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: Int(ceil(seconds)))
        .accessibilityAddTraits(.isModal)
    }

    private func resultOverlay(title: String, detail: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.system(size: 21, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(detail).font(.system(size: 14, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.white)
            Button("Return to Arena") { model.stopSession() }.font(.system(size: 13, weight: .bold)).padding(.horizontal, 18).padding(.vertical, 10).background(.white.opacity(0.16), in: Capsule())
        }.padding(24).frame(maxWidth: .infinity).glassmorphic().padding(.horizontal, 28).background(Color.black.opacity(0.45).ignoresSafeArea())
    }
}