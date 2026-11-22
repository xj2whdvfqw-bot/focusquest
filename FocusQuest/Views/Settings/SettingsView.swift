import SwiftUI
import UIKit

/// Nastaveni (list z ozubeneho kola): Sounds & notifications, Background, Feedback a paticka.
/// Zavira se jen tahem dolu (tlacitko Done je pryc), VoiceOver gestem escape.
/// Zvuky a notifikace jsou na samostatne strance se zpetnym "‹ Settings".
struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var profile: ProfileViewModel
    var onClose: (() -> Void)? = nil
    /// Otevre Shop › Backgrounds (list se predtim zavre).
    var onOpenBackgrounds: (() -> Void)? = nil
    /// Reset progress po potvrzeni; vraci false, kdyz se nepovedl.
    var onResetProgress: (() async -> Bool)? = nil

    @State private var showsSounds = false
    @State private var showsResetConfirmation = false
    @State private var isResetting = false
    /// Skutecny stav povoleni notifikaci v iOS.
    @State private var notifications = NotificationPermission.notDetermined
    /// Jak daleko hrac tahne podstranku od leveho okraje doprava (navrat zpet jako v iOS).
    @State private var backDrag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    /// Tah musi zacit tesne u leveho okraje (jako systemovy navrat zpet).
    private static let edgeWidth: CGFloat = 32

    var body: some View {
        ScreenScaffold {
            if showsSounds {
                soundsPage
                    .offset(x: backDrag)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainPage.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: showsSounds)
        // Podstranka nema NavigationStack (list ma vlastni krajinu a tah dolu), proto navrat
        // tahem od leveho okraje resi vlastni gesto: stranka jde s prstem, po ~100 pt nebo
        // rychlem svihu se vrati na Nastaveni, jinak pruzne zajede zpet. Svisle rolovani neblokuje.
        .simultaneousGesture(edgeBackGesture, including: showsSounds ? .all : .subviews)
        // Zavreni tahem dolu; ne behem potvrzeni "Reset progress" a ne behem mazani.
        // VoiceOver escape: ze stranky zvuku zpet na Nastaveni, z hlavni stranky zavrit.
        .fqSheetDismissal(blocked: showsResetConfirmation || isResetting) {
            if showsSounds { showsSounds = false } else { onClose?() }
        }
        .task { notifications = await NotificationPermission.current() }
        // Navrat z Nastaveni iPhonu: prepinace ukazi skutecny stav.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notifications = await NotificationPermission.current() } }
        }
    }

    private var edgeBackGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard showsSounds, value.startLocation.x < Self.edgeWidth else { return }
                // Jen vodorovny tah doprava; svisly tah dal roluje stranku.
                guard backDrag > 0 || value.translation.width > abs(value.translation.height) else { return }
                backDrag = max(0, value.translation.width)
            }
            .onEnded { value in
                guard backDrag > 0 else { return }
                // Asi ctvrtina sirky telefonu, nebo rychly svih.
                if value.translation.width > 100 || value.predictedEndTranslation.width > 220 {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showsSounds = false
                        backDrag = 0
                    }
                } else {
                    withAnimation(FQMotion.pop) { backDrag = 0 }
                }
            }
    }

    // MARK: - Hlavni stranka

    @ViewBuilder private var mainPage: some View {
        ScreenTitle(title: "Settings")
            .padding(.top, FQSpace.md)
        card {
            Button { showsSounds = true } label: {
                linkRow(icon: "bell", title: "Sounds & notifications", detail: soundsSummary)
            }
            .buttonStyle(.fqPress)
        }
        ScreenSection(title: "Background") {
            card {
                Button { onOpenBackgrounds?() } label: {
                    linkRow(icon: nil, title: profile.selectedBackground?.name ?? ShopBackground.worldName, detail: "Change it in Shop › Backgrounds")
                }
                .buttonStyle(.fqPress)
            }
        }
        ScreenSection(title: "Feedback") {
            card {
                Button { contactDeveloper() } label: {
                    linkRow(icon: "envelope", title: "Contact the developer", detail: "Report a bug or suggest an idea")
                }
                .buttonStyle(.fqPress)
                // "Rate this app" je skryte, dokud appka nema App Store ID. Pak se vrati s primym odkazem
                // https://apps.apple.com/app/id<ID>?action=write-review (requestReview() casto nic neukaze).
            }
        }
        ScreenSection(title: "Your data", detail: "Stored only on this iPhone") {
            card {
                Button { showsResetConfirmation = true } label: {
                    HStack(spacing: FQSpace.md) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .regular))
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset progress").font(.fqBody)
                            Text("Start over with a new hero").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                        }
                        Spacer(minLength: FQSpace.sm)
                        if isResetting { ProgressView() }
                    }
                    .foregroundStyle(FQColor.danger)
                    .padding(.vertical, FQSpace.sm)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.fqPress)
                .disabled(isResetting)
            }
            if let message = model.statusMessage {
                Text(message).font(.fqMeta).foregroundStyle(FQColor.danger)
            }
        }
        .confirmationDialog("Reset all progress?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { resetProgress() }
            Button("Keep my progress", role: .cancel) { }
        } message: {
            Text("Your hero, level, coins, stats, subjects and settings will be deleted from this iPhone. This can't be undone.")
        }
        #if DEBUG
        ScreenSection(title: "Debug", detail: "Not in the release build") { debugCard }
        #endif
        footer
    }

    #if DEBUG
    /// Jen v Debug buildu: mince a level pro testovani obchodu a odznaku levelu.
    private var debugCard: some View {
        card {
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text("Coins: \(profile.profile.coins)")
                    .font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("+1 000") { profile.debugAddCoins(1_000) }
                    debugButton("+10 000") { profile.debugAddCoins(10_000) }
                    debugButton("Reset coins") { profile.debugResetCoins() }
                }
            }
            .padding(.vertical, FQSpace.md)
            HairlineDivider()
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text("Level: \(profile.level)")
                    .font(.fqLabel).monospacedDigit().foregroundStyle(FQColor.textSecondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("Level −1") { profile.debugSetLevel(profile.level - 1) }
                    debugButton("Level +1") { profile.debugSetLevel(profile.level + 1) }
                    ForEach(Self.tierLevels, id: \.level) { tier in
                        debugButton("\(tier.name) \(tier.level)") { profile.debugSetLevel(tier.level) }
                    }
                }
            }
            .padding(.vertical, FQSpace.md)
        }
    }

    private static let tierLevels: [(name: String, level: Int)] = [
        ("Bronze", 1), ("Silver", 5), ("Gold", 10), ("Sapphire", 15), ("Rainbow", 20),
    ]

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(ShopButtonStyle())
            .monospacedDigit()
    }
    #endif

    /// "Lo-fi · 3 of 4 sounds on · reminder off"
    private var soundsSummary: String {
        let prefs = model.preferences
        let reminder = notifications == .denied ? "notifications off" : "reminder \(prefs.isDailyReminderEnabled ? "on" : "off")"
        return "\(prefs.battleSound.title) · \(prefs.soundEffectsOnCount) of 4 sounds on · \(reminder)"
    }

    private var footer: some View {
        VStack(spacing: FQSpace.xs) {
            Text("FocusQuest version \(Self.appVersion)")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
            HStack(spacing: FQSpace.sm) {
                Button("Privacy Policy") { openURL(LegalLinks.privacy) }
                Text("·").accessibilityHidden(true)
                Button("Terms of Use") { openURL(LegalLinks.terms) }
                Text("·").accessibilityHidden(true)
                Button("Support") { openURL(LegalLinks.support) }
            }
            .font(.fqMeta.weight(.semibold))
            .foregroundStyle(FQColor.textSecondary)
            .buttonStyle(.fqPress)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FQSpace.sm)
        // Paticka nesedi na spodnim okraji listu (Done pod ni uz neni).
        .padding(.bottom, FQSpace.xl)
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private func resetProgress() {
        guard let onResetProgress, !isResetting else { return }
        isResetting = true
        Task {
            _ = await onResetProgress()
            isResetting = false
        }
    }

    private func contactDeveloper() {
        // Adresa vyvojare zatim neni; Mail se otevre s predvyplnenym predmetem a hrac adresu doplni.
        var components = URLComponents()
        components.scheme = "mailto"
        components.queryItems = [URLQueryItem(name: "subject", value: "FocusQuest \(Self.appVersion) feedback")]
        if let url = components.url { openURL(url) }
    }

    // MARK: - Sounds & notifications

    @ViewBuilder private var soundsPage: some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            Button { showsSounds = false } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text("Settings").font(.system(size: 17, weight: .medium, design: .rounded))
                }
                .foregroundStyle(FQColor.textPrimary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.fqPress)
            .accessibilityLabel("Back to Settings")
            Text("Sounds & notifications")
                .fqFont(size: 22, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, FQSpace.sm)
        ScreenSection(title: "Battle sound") {
            card {
                ForEach(Array(BattleSound.allCases.enumerated()), id: \.element) { index, sound in
                    if index > 0 { HairlineDivider() }
                    radioRow(sound)
                }
            }
        }
        ScreenSection(title: "Sound effects") {
            card {
                // Kazdy prepinac ma pod sebou zkusebni kartu, ktera se pri zapnuti rozbali.
                feedbackToggle("Tap sounds", detail: "A soft click on buttons and controls", isOn: binding(\.isSFXEnabled)) {
                    demoButton("Try tapping") { FQFeedback.shared.play(.tap) }
                }
                HairlineDivider()
                feedbackToggle("Haptics", detail: "Vibrations on taps, wins and the phone-lifted alarm", isOn: binding(\.isHapticsEnabled)) {
                    demoButton("Light") { FQFeedback.shared.haptic(.light) }
                    demoButton("Strong") { FQFeedback.shared.haptic(.heavy) }
                    demoButton("Success") { FQFeedback.shared.haptic(.success) }
                }
                HairlineDivider()
                feedbackToggle("Battle sounds", detail: "Attack, hit, victory and the boss escaping", isOn: binding(\.isBattleSoundEnabled)) {
                    demoButton("Attack") { FQFeedback.shared.play(.attack) }
                    demoButton("Hit") { FQFeedback.shared.play(.hit) }
                    demoButton("Victory") { FQFeedback.shared.play(.victory) }
                    demoButton("Escape") { FQFeedback.shared.play(.escape) }
                }
                HairlineDivider()
                feedbackToggle("Reward sounds", detail: "Coins, XP and level up", isOn: binding(\.isAchievementSoundEnabled)) {
                    demoButton("Coins") { FQFeedback.shared.play(.coin) }
                    demoButton("XP") { FQFeedback.shared.play(.xp) }
                    demoButton("Level up") { FQFeedback.shared.play(.levelUp) }
                }
                HairlineDivider()
                feedbackToggle("Alarm sound", detail: "Beeps when the phone is lifted", isOn: binding(\.isAlarmSoundEnabled)) {
                    demoButton("Play beep") { FQFeedback.shared.play(.alarm) }
                }
                HairlineDivider()
                effectsVolumeRow
            }
        }
        ScreenSection(title: "Notifications") {
            card {
                if notifications == .denied {
                    notificationsOffRow
                    HairlineDivider()
                }
                Group {
                    toggleRow("Daily reminder", detail: "A nudge at 17:00 if you haven't focused", isOn: notificationBinding(\.isDailyReminderEnabled))
                    HairlineDivider()
                    toggleRow("Battle finished", detail: "When the countdown ends", isOn: notificationBinding(\.isBattleDoneNotificationEnabled))
                    HairlineDivider()
                    toggleRow("Break is over", detail: "When your 5 minute break ends", isOn: notificationBinding(\.isBreakOverNotificationEnabled))
                }
                .disabled(notifications == .denied)
            }
        }
    }

    private func radioRow(_ sound: BattleSound) -> some View {
        let selected = model.preferences.battleSound == sound
        return Button {
            model.update { $0.battleSound = sound }
        } label: {
            HStack(spacing: FQSpace.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                    Text(sound.detail).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: FQSpace.sm)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? FQColor.accent : FQColor.textTertiary)
            }
            .padding(.vertical, FQSpace.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.fqPress)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Stavebni prvky

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .glassCard()
    }

    /// Radek s odkazem: obrysova ikona 24 pt bez podkladu, nazev, popisek a sipka.
    private func linkRow(icon: String?, title: String, detail: String) -> some View {
        HStack(spacing: FQSpace.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Text(detail).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
            Spacer(minLength: FQSpace.sm)
            Image(systemName: "chevron.right").font(.fqMeta.weight(.semibold)).foregroundStyle(FQColor.textTertiary)
        }
        .padding(.vertical, FQSpace.sm)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Text(detail).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
        }
        .tint(FQColor.toggleOn)
        .padding(.vertical, FQSpace.sm)
        // Prepinac je ovladaci prvek: klik a vibrace stejne jako tlacitka.
        .onChange(of: isOn.wrappedValue) { FQFeedback.shared.tap() }
    }

    /// Prepinac zvuku nebo haptiky; kdyz je zapnuty, pod nim se animovane rozbali zkusebni karta.
    private func feedbackToggle<Demo: View>(_ title: String, detail: String, isOn: Binding<Bool>, @ViewBuilder demo: () -> Demo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            toggleRow(title, detail: detail, isOn: Binding(
                get: { isOn.wrappedValue },
                set: { value in withAnimation(FQMotion.spring(reduceMotion: reduceMotion)) { isOn.wrappedValue = value } }
            ))
            if isOn.wrappedValue {
                VStack(alignment: .leading, spacing: FQSpace.sm) {
                    Text("Try it").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                    ChipFlow(spacing: FQSpace.sm) { demo() }
                }
                .padding(FQSpace.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FQColor.fill, in: FQRadius.shape(FQRadius.inSmallCard))
                .padding(.bottom, FQSpace.md)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private func demoButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(ShopButtonStyle(outlined: true))
    }

    /// Hlasitost efektu (klepnuti, bitva, odmeny, alarm). Po pusteni posuvniku zazni ukazka.
    private var effectsVolumeRow: some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            HStack {
                Text("Effects volume").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Spacer(minLength: FQSpace.sm)
                Text("\(Int((model.preferences.effectsVolume * 100).rounded())) %")
                    .font(.fqMeta)
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textSecondary)
            }
            HStack(spacing: FQSpace.sm) {
                Image(systemName: "speaker.fill").font(.fqMeta).foregroundStyle(FQColor.textSecondary).accessibilityHidden(true)
                Slider(
                    value: Binding(get: { model.preferences.effectsVolume }, set: { value in model.update { $0.effectsVolume = value } }),
                    in: 0...1,
                    onEditingChanged: { editing in if !editing { FQFeedback.shared.preview(.coin) } }
                )
                .tint(FQColor.accent)
                .accessibilityLabel("Effects volume")
                .accessibilityValue("\(Int((model.preferences.effectsVolume * 100).rounded())) percent")
                Image(systemName: "speaker.wave.3.fill").font(.fqMeta).foregroundStyle(FQColor.textSecondary).accessibilityHidden(true)
            }
        }
        .padding(.vertical, FQSpace.sm)
    }

    /// Notifikace vypnute v iOS: vysvetleni a odkaz do Nastaveni iPhonu.
    private var notificationsOffRow: some View {
        HStack(spacing: FQSpace.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(FQColor.textPrimary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Text("Turn them on in iPhone Settings").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
            }
            Spacer(minLength: FQSpace.sm)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            .buttonStyle(ShopButtonStyle())
        }
        .padding(.vertical, FQSpace.sm)
        .frame(minHeight: 44)
    }

    /// Prepinac notifikace ukazuje skutecny stav: kdyz iOS notifikace blokuje, je vypnuty.
    /// Prvni zapnuti spusti systemovy dotaz na povoleni.
    private func notificationBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { notifications != .denied && model.preferences[keyPath: keyPath] },
            set: { value in
                model.update { $0[keyPath: keyPath] = value }
                guard value, notifications == .notDetermined else { return }
                Task { notifications = await NotificationPermission.request() }
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.update { $0[keyPath: keyPath] = value } })
    }
}
