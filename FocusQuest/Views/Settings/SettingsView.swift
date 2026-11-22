import SwiftUI
import UIKit

/// Nastaveni (list z ozubeneho kola) ve stylu systemoveho Nastaveni iOS 26:
/// inset grouped seznam, velky nadpis vlevo, radky s ikonou v barevnem ctverecku, seda hodnota
/// a sipka u podstranek, nativni prepinace se systemovou zelenou. NavigationStack dava Liquid Glass
/// listu, mekky scroll edge efekt a navrat chevronem i tahem od leveho okraje.
/// List se zavira tahem dolu (VoiceOver gestem escape).
struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var profile: ProfileViewModel
    var onClose: (() -> Void)? = nil
    /// Otevre Shop › Backgrounds (list se predtim zavre).
    var onOpenBackgrounds: (() -> Void)? = nil
    /// Reset progress po potvrzeni; vraci false, kdyz se nepovedl.
    var onResetProgress: (() async -> Bool)? = nil

    @State private var showsResetConfirmation = false
    @State private var isResetting = false
    /// Skutecny stav povoleni notifikaci v iOS.
    @State private var notifications = NotificationPermission.notDetermined
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SoundsSettingsPage(model: model)
                    } label: {
                        SettingsRow(title: "Sounds & haptics", symbol: "speaker.wave.2.fill", color: .pink, value: "\(model.preferences.soundEffectsOnCount) of 4 on")
                    }
                    NavigationLink {
                        MusicSettingsPage(model: model)
                    } label: {
                        SettingsRow(title: "Music", symbol: "music.note", color: .orange, value: model.preferences.battleSound.title)
                    }
                    NavigationLink {
                        NotificationSettingsPage(model: model, notifications: $notifications)
                    } label: {
                        SettingsRow(title: "Notifications", symbol: "bell.badge.fill", color: .red, value: notificationSummary)
                    }
                } footer: {
                    Text("Music plays during battles. Sounds and haptics apply to the whole app.")
                }

                Section {
                    Button { onOpenBackgrounds?() } label: {
                        SettingsRow(title: "Background", symbol: "photo.fill", color: .indigo, value: profile.selectedBackground?.name ?? ShopBackground.worldName, showsChevron: true)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Backgrounds are in Shop › Backgrounds.")
                }

                Section {
                    Button { contactDeveloper() } label: {
                        SettingsRow(title: "Contact the developer", symbol: "envelope.fill", color: .blue, showsChevron: true)
                    }
                    // "Rate this app" je skryte, dokud appka nema App Store ID. Pak se vrati s primym odkazem
                    // https://apps.apple.com/app/id<ID>?action=write-review (requestReview() casto nic neukaze).
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Report a bug or suggest an idea.")
                }

                Section {
                    Button(role: .destructive) { showsResetConfirmation = true } label: {
                        HStack {
                            Text("Reset progress")
                            Spacer()
                            if isResetting { ProgressView() }
                        }
                    }
                    .disabled(isResetting)
                    .confirmationDialog("Reset all progress?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
                        Button("Reset progress", role: .destructive) { resetProgress() }
                        Button("Keep my progress", role: .cancel) { }
                    } message: {
                        Text("Your hero, level, coins, stats, subjects and settings will be deleted from this iPhone. This can't be undone.")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    if let message = model.statusMessage {
                        Text(message).foregroundStyle(FQColor.danger)
                    } else {
                        Text("Everything is stored only on this iPhone. Reset starts over with a new hero.")
                    }
                }

                #if DEBUG
                DebugSettingsSections(model: model, profile: profile, notifications: $notifications)
                #endif

                Section {
                } footer: {
                    footer
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .settingsScrollEdges()
        }
        // Bez systemove modre: tint je bily (chevron zpet, fajfky, posuvniky); jen prepinace zustavaji zelene (settingsToggleTint).
        .tint(.white)
        // Zavreni tahem dolu; ne behem potvrzeni "Reset progress" a ne behem mazani.
        .fqSheetDismissal(blocked: showsResetConfirmation || isResetting) { onClose?() }
        .task { notifications = await NotificationPermission.current() }
        // Navrat z Nastaveni iPhonu: prepinace ukazi skutecny stav.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notifications = await NotificationPermission.current() } }
        }
    }

    private var notificationSummary: String {
        switch notifications {
        case .denied: "Off"
        case .notDetermined: "Not set"
        case .allowed, .silent: model.preferences.isDailyReminderEnabled ? "Reminder on" : "On"
        }
    }

    private var footer: some View {
        VStack(spacing: FQSpace.xs) {
            Text("FocusQuest version \(Self.appVersion)")
            HStack(spacing: FQSpace.sm) {
                Button("Privacy Policy") { openURL(LegalLinks.privacy) }
                Text("·").accessibilityHidden(true)
                Button("Terms of Use") { openURL(LegalLinks.terms) }
                Text("·").accessibilityHidden(true)
                Button("Support") { openURL(LegalLinks.support) }
            }
            .fontWeight(.semibold)
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FQSpace.sm)
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
}

// MARK: - Sounds & haptics

/// Zvukove efekty a haptika. Kazdy prepinac ma pod sebou radek "Try it", ktery se pri zapnuti
/// rozbali a pri vypnuti schova. Haptika ma navic silu Light / Medium / Strong pro celou appku.
private struct SoundsSettingsPage: View {
    @ObservedObject var model: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var prefs: AppPreferences { model.preferences }

    var body: some View {
        List {
            Section {
                toggle("Tap sounds", symbol: "hand.tap.fill", color: .blue, isOn: binding(\.isSFXEnabled))
                if prefs.isSFXEnabled {
                    TryItRow {
                        demo("Tap") { FQFeedback.shared.play(.tap) }
                    }
                }
                toggle("Battle sounds", symbol: "bolt.fill", color: .orange, isOn: battleSoundBinding)
                if prefs.isBattleSoundEnabled {
                    TryItRow {
                        demo("Hit") { FQFeedback.shared.play(.hit) }
                        demo("Victory") { FQFeedback.shared.play(.victory) }
                        demo("Escape") { FQFeedback.shared.play(.escape) }
                    }
                }
                toggle("Reward sounds", symbol: "star.fill", color: .yellow, isOn: binding(\.isAchievementSoundEnabled))
                if prefs.isAchievementSoundEnabled {
                    TryItRow {
                        demo("Coins") { FQFeedback.shared.play(.coin) }
                        demo("XP") { FQFeedback.shared.play(.xp) }
                        demo("Level up") { FQFeedback.shared.play(.levelUp) }
                    }
                }
                toggle("Alarm sound", symbol: "alarm.fill", color: .red, isOn: binding(\.isAlarmSoundEnabled))
                if prefs.isAlarmSoundEnabled {
                    TryItRow {
                        demo("Beep") { FQFeedback.shared.play(.alarm) }
                    }
                }
            } header: {
                Text("Sound effects")
            } footer: {
                Text("Tap sounds click on buttons. Battle sounds play on the final blow, victory and when the boss escapes. Alarm sound beeps when the phone is lifted.")
            }

            Section {
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    HStack {
                        Text("Effects volume")
                        Spacer()
                        Text("\(Int((prefs.effectsVolume * 100).rounded())) %")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: FQSpace.sm) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                        Slider(
                            value: Binding(get: { prefs.effectsVolume }, set: { value in model.update { $0.effectsVolume = value } }),
                            in: 0...1,
                            onEditingChanged: { editing in if !editing { FQFeedback.shared.preview(.coin) } }
                        )
                        .accessibilityLabel("Effects volume")
                        .accessibilityValue("\(Int((prefs.effectsVolume * 100).rounded())) percent")
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("A sample plays when you let go of the slider.")
            }

            Section {
                toggle("Haptics", symbol: "iphone.radiowaves.left.and.right", color: .purple, isOn: binding(\.isHapticsEnabled))
                if prefs.isHapticsEnabled {
                    Picker("Strength", selection: Binding(get: { prefs.hapticStrength }, set: { value in
                        model.update { $0.hapticStrength = value }
                        // Nova sila se hned ukaze (FQFeedback ma predvolby po update).
                        FQFeedback.shared.haptic(.medium)
                    })) {
                        ForEach(HapticStrength.allCases) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden, edges: .bottom)
                    TryItRow {
                        demo("Light") { FQFeedback.shared.haptic(.light) }
                        demo("Strong") { FQFeedback.shared.haptic(.heavy) }
                        demo("Success") { FQFeedback.shared.haptic(.success) }
                    }
                }
            } header: {
                Text("Haptics")
            } footer: {
                Text("Vibrations on taps, wins and the phone-lifted alarm. The strength applies to the whole app.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sounds & haptics")
        .navigationBarTitleDisplayMode(.large)
        .settingsScrollEdges()
        .animation(reduceMotion ? nil : .default, value: prefs)
    }

    private func toggle(_ title: String, symbol: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            SettingsRow(title: title, symbol: symbol, color: color)
        }
        .settingsToggleTint()
        // Prepinac je ovladaci prvek: klik a vibrace stejne jako tlacitka.
        .onChange(of: isOn.wrappedValue) { FQFeedback.shared.tap() }
    }

    private func demo(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
    }

    /// Battle sounds: zapamatuje se, ze je hrac prepnul sam (jinak zustavaji vychozi vypnute).
    private var battleSoundBinding: Binding<Bool> {
        Binding(get: { prefs.isBattleSoundEnabled }, set: { value in
            model.update {
                $0.isBattleSoundEnabled = value
                $0.isBattleSoundUserSet = true
            }
        })
    }

    private func binding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.update { $0[keyPath: keyPath] = value } })
    }
}

/// Radek "Try it" pod zapnutym prepinacem: male tlacitka s ukazkou.
private struct TryItRow<Buttons: View>: View {
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            Text("Try it").font(.footnote).foregroundStyle(.secondary)
            ChipFlow(spacing: FQSpace.sm) { buttons() }
        }
        .padding(.vertical, 4)
        // Odsazeni pod text prepinace (ikona 29 + mezera), jako podrizeny radek.
        .padding(.leading, 41)
        .transition(.opacity)
    }
}

// MARK: - Music

/// Hudba bitvy: jedna volba (zatrzitko vpravo jako v systemovem Nastaveni).
/// Vyber hudby do bitvy. U kazde stopy play/stop s 8s ukazkou (zesileni a zeslabeni), pod seznamem
/// hlasitost hudby (plati pro bitvu i ukazku). Odchod ze stranky vsechny ukazky zastavi.
private struct MusicSettingsPage: View {
    @ObservedObject var model: SettingsViewModel
    private let preview = MusicPreview.shared

    private var volumePercent: Int { Int((model.preferences.ambientVolume * 100).rounded()) }

    var body: some View {
        List {
            Section {
                ForEach(BattleSound.allCases) { sound in
                    row(sound)
                }
            } header: {
                Text("During battles")
            } footer: {
                Text("Tap play for an 8 second sample. Fireplace piano and Study flow loop with a soft crossfade. Music keeps playing when the phone is locked.")
            }

            Section {
                VStack(alignment: .leading, spacing: FQSpace.xs) {
                    HStack {
                        Text("Music volume")
                        Spacer()
                        Text("\(volumePercent) %")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: FQSpace.sm) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                        Slider(value: Binding(get: { model.preferences.ambientVolume }, set: { value in
                            model.update { $0.ambientVolume = value }
                            preview.setVolume(value)
                        }), in: 0...1)
                        .accessibilityLabel("Music volume")
                        .accessibilityValue("\(volumePercent) percent")
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Applies to music in battles and to the samples.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Music")
        .navigationBarTitleDisplayMode(.large)
        .settingsScrollEdges()
        .onDisappear { preview.stop() }
    }

    private func row(_ sound: BattleSound) -> some View {
        let isSelected = model.preferences.battleSound == sound
        let isPlaying = preview.playing == sound
        return HStack(spacing: FQSpace.md) {
            Button {
                model.update { $0.battleSound = sound }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sound.title).foregroundStyle(.primary)
                        Text(sound.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Bila fajfka (ne systemova modra).
                    if isSelected {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            if sound != .off {
                Button {
                    preview.toggle(sound, preferences: model.preferences)
                } label: {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPlaying ? "Stop sample of \(sound.title)" : "Play sample of \(sound.title)")
            }
        }
    }
}

// MARK: - Notifications

private struct NotificationSettingsPage: View {
    @ObservedObject var model: SettingsViewModel
    @Binding var notifications: NotificationPermission
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                statusRow
            } footer: {
                Text(statusFooter)
            }
            Section {
                toggle("Daily reminder", symbol: "calendar", color: .green, isOn: notificationBinding(\.isDailyReminderEnabled))
                toggle("Battle finished", symbol: "flag.checkered", color: .orange, isOn: notificationBinding(\.isBattleDoneNotificationEnabled))
                toggle("Break is over", symbol: "cup.and.saucer.fill", color: .brown, isOn: notificationBinding(\.isBreakOverNotificationEnabled))
            } footer: {
                Text("The daily reminder comes at 17:00 if you haven't focused yet. Battle finished arrives when the countdown ends, Break is over when your 5 minute break ends.")
            }
            .disabled(notifications == .denied)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .settingsScrollEdges()
    }

    private var statusFooter: String {
        switch notifications {
        case .allowed: "Battle results, breaks and the reminder can reach you."
        case .notDetermined: "iOS will ask once."
        case .silent: "Banners are off: notifications land quietly in Notification Center."
        case .denied: "Notifications are off for FocusQuest. Turn them on in iPhone Settings."
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch notifications {
        case .allowed:
            SettingsRow(title: "Notifications", symbol: "bell.fill", color: .red, value: "Allowed")
        case .notDetermined:
            Button { Task { notifications = await NotificationPermission.request() } } label: {
                SettingsRow(title: "Allow notifications", symbol: "bell.fill", color: .red, showsChevron: true)
            }
        case .silent, .denied:
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            } label: {
                SettingsRow(title: "Open iPhone Settings", symbol: "bell.slash.fill", color: .gray, value: notifications == .denied ? "Off" : "Quiet", showsChevron: true)
            }
        }
    }

    private func toggle(_ title: String, symbol: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            SettingsRow(title: title, symbol: symbol, color: color)
        }
        .settingsToggleTint()
        .onChange(of: isOn.wrappedValue) { FQFeedback.shared.tap() }
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
}

// MARK: - Debug

#if DEBUG
/// Jen v Debug buildu: mince, level, odemceni svetu a test notifikaci.
private struct DebugSettingsSections: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var profile: ProfileViewModel
    @Binding var notifications: NotificationPermission
    @State private var debugNotificationStatus: String?
    @State private var debugPending: [String]?
    @State private var debugTipsStatus: String?

    private static let tierLevels: [(name: String, level: Int)] = [
        ("Bronze", 1), ("Silver", 5), ("Gold", 10), ("Sapphire", 15), ("Rainbow", 20),
    ]

    var body: some View {
        Section {
            HStack {
                SettingsRow(title: "Worlds", symbol: "map.fill", color: .teal, value: model.preferences.debugUnlockAllWorlds ? "All unlocked" : "Normal")
            }
            ChipFlow(spacing: FQSpace.sm) {
                debugButton("Unlock all worlds") { model.update { $0.debugUnlockAllWorlds = true } }
                debugButton("Lock them back") { model.update { $0.debugUnlockAllWorlds = false } }
            }
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text("Coins: \(profile.profile.coins)").monospacedDigit().foregroundStyle(.secondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("+1 000") { profile.debugAddCoins(1_000) }
                    debugButton("+10 000") { profile.debugAddCoins(10_000) }
                    debugButton("Reset coins") { profile.debugResetCoins() }
                }
            }
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text("Level: \(profile.level)").monospacedDigit().foregroundStyle(.secondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("Level −1") { profile.debugSetLevel(profile.level - 1) }
                    debugButton("Level +1") { profile.debugSetLevel(profile.level + 1) }
                    ForEach(Self.tierLevels, id: \.level) { tier in
                        debugButton("\(tier.name) \(tier.level)") { profile.debugSetLevel(tier.level) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text("Easter eggs found: \(profile.profile.foundEasterEggs.count) of \(MapEasterEgg.allCases.count)").monospacedDigit().foregroundStyle(.secondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("Reset easter eggs") { profile.debugResetEasterEggs() }
                    debugButton("Reset tips") {
                        // Datastore TipKitu jde smazat jen pred Tips.configure: provede se pri dalsim spusteni.
                        FQTips.resetOnNextLaunch()
                        debugTipsStatus = "Tips reset. Quit and reopen the app to see them again."
                    }
                }
                if let debugTipsStatus { Text(debugTipsStatus).font(.footnote) }
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Not in the release build. \"Win now\" in a running battle wins it at once, with rewards.")
        }

        Section {
            ChipFlow(spacing: FQSpace.sm) {
                debugButton("Test notifications") {
                    Task {
                        let scheduled = await BattleNotificationService().scheduleTestNotifications()
                        notifications = await NotificationPermission.current()
                        debugNotificationStatus = scheduled ? "Scheduled 3 test notifications." : "Not allowed in iOS: nothing scheduled."
                        debugPending = await BattleNotificationService().pendingSummary()
                    }
                }
                debugButton("Show pending") {
                    Task { debugPending = await BattleNotificationService().pendingSummary() }
                }
            }
            if let debugNotificationStatus {
                Text(debugNotificationStatus).font(.footnote)
            }
            if let debugPending {
                Text(debugPending.isEmpty ? "No pending notifications" : debugPending.joined(separator: "\n"))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Debug notifications")
        } footer: {
            Text("Victory, Break is over and Daily reminder in 5, 7 and 9 s. Lock the phone to see the banners.")
        }
    }

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .monospacedDigit()
    }
}
#endif

// MARK: - Stavebni prvky

/// Radek jako v systemovem Nastaveni: ikona v malem zaoblenem barevnem ctverci, nazev,
/// seda hodnota vpravo a u tlacitek, ktera nekam vedou, sipka.
struct SettingsRow: View {
    let title: String
    var symbol: String? = nil
    var color: Color = .gray
    var value: String? = nil
    /// Sipka u tlacitek (NavigationLink ma vlastni).
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                SettingsIcon(symbol: symbol, color: color)
            }
            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: FQSpace.sm)
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Bila SF Symbol ikona v barevnem ctverci se zaoblenymi rohy (29 bodu jako v Nastaveni iOS).
struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

private extension View {
    /// Nativni prepinac se systemovou zelenou, jako v Nastaveni iPhonu.
    func settingsToggleTint() -> some View { tint(Color(uiColor: .systemGreen)) }

    /// Mekky scroll edge efekt nahore i dole (iOS 26); starsi iOS maji standardni listu.
    @ViewBuilder func settingsScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
