import SwiftUI
import UIKit
import WidgetKit

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
    /// "Replay tutorial": list se zavre a tutorial zacne znovu na Home.
    var onReplayTutorial: (() -> Void)? = nil
    /// Debug "Reset onboarding": znovu uvodni onboarding i tutorial.
    var onResetOnboarding: (() -> Void)? = nil

    @State private var showsResetConfirmation = false
    /// Otevrene podstranky (Sounds & haptics, Music, Notifications).
    @State private var path: [SettingsPage] = []
    /// C7: prepinac iCloud sync (plati jen se zapnutym FeatureFlags.iCloudSync).
    @AppStorage(CloudSync.enabledKey) private var iCloudSyncEnabled = false
    @State private var isResetting = false
    /// Skutecny stav povoleni notifikaci v iOS.
    @State private var notifications = NotificationPermission.notDetermined
    /// Q1/J2: 0 = velky nadpis "Settings" vlevo nahore, 1 = odrolovano, nahore maly nadpis na stredu s materialem.
    @State private var titleProgress: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: SettingsPage.sounds) {
                        SettingsRow(title: "Sounds & haptics", symbol: "speaker.wave.2.fill", color: .pink, value: "\(model.preferences.soundEffectsOnCount) of 4 on")
                    }
                    NavigationLink(value: SettingsPage.music) {
                        SettingsRow(title: "Music", symbol: "music.note", color: .orange, value: model.preferences.battleSound.title)
                    }
                    NavigationLink(value: SettingsPage.notifications) {
                        SettingsRow(title: "Notifications", symbol: "bell.badge.fill", color: .red, value: notificationSummary)
                    }
                } header: {
                    // Q1/J2: velky nadpis hned pod grabberem (jako systemove Nastaveni), roluje s obsahem.
                    SettingsLargeTitle(title: "Settings", progress: titleProgress)
                } footer: {
                    Text("Music plays during battles. Sounds and haptics apply to the whole app.")
                }

                Section {
                    Button { FQFeedback.shared.tap(); onOpenBackgrounds?() } label: {
                        SettingsRow(title: "Background", symbol: "photo.fill", color: .indigo, value: profile.selectedBackground?.name ?? ShopBackground.worldName, showsChevron: true)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Backgrounds are in Shop › Backgrounds.")
                }

                Section {
                    Button { FQFeedback.shared.tap(); onReplayTutorial?() } label: {
                        SettingsRow(title: "Replay tutorial", symbol: "hand.tap.fill", color: .green, showsChevron: true)
                    }
                    NavigationLink(value: SettingsPage.focusFilter) {
                        SettingsRow(title: "Use with iPhone Focus", symbol: "moon.fill", color: .indigo)
                    }
                    NavigationLink(value: SettingsPage.shortcuts) {
                        SettingsRow(title: "Siri & Shortcuts", symbol: "square.2.layers.3d.fill", color: .pink)
                    }
                } header: {
                    Text("Help")
                } footer: {
                    Text("A quick tour of Fight, Path, Shop, Stats and Hero, plus how to use FocusQuest with Focus modes, Siri and the Action button.")
                }

                Section {
                    Button { FQFeedback.shared.tap(); contactDeveloper() } label: {
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
                    Button(role: .destructive) { FQFeedback.shared.tap(); showsResetConfirmation = true } label: {
                        HStack {
                            Text("Reset progress")
                            Spacer()
                            if isResetting { ProgressView() }
                        }
                    }
                    .disabled(isResetting)
                    .confirmationDialog("Reset all progress?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
                        Button("Reset progress", role: .destructive) { FQFeedback.shared.tap(); resetProgress() }
                        Button("Keep my progress", role: .cancel) { FQFeedback.shared.tap() }
                    } message: {
                        Text("Your hero, level, coins, stats, focus list and settings will be deleted from this iPhone. This can't be undone.")
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

                // C7: pripravene, skryte, dokud neni FeatureFlags.iCloudSync (placeny ucet, viz DEVELOPER_ACCOUNT_TODO.md).
                if FeatureFlags.iCloudSync { iCloudSection }

                #if DEBUG
                DebugSettingsSections(model: model, profile: profile, notifications: $notifications, onResetOnboarding: onResetOnboarding)
                #endif

                Section {
                } footer: {
                    footer
                }
            }
            .listStyle(.insetGrouped)
            // Q1/J2: systemovy velky nadpis se v listu na iOS 26 nekreslil (prazdny tmavy blok, "Settings" az
            // po odrolovani). Koren proto nema navigacni listu: velky nadpis je hlavicka prvni sekce a po odrolovani
            // se nahore plynule objevi maly nadpis na stredu s materialem (SettingsCompactTitleBar).
            .navigationTitle("Settings")
            .toolbar(.hidden, for: .navigationBar)
            .modifier(SettingsTitleScrollTracker(progress: $titleProgress))
            .overlay(alignment: .top) {
                SettingsCompactTitleBar(title: "Settings", progress: titleProgress)
            }
            .navigationDestination(for: SettingsPage.self) { page in
                switch page {
                case .sounds: SoundsSettingsPage(model: model)
                case .music: MusicSettingsPage(model: model)
                case .notifications: NotificationSettingsPage(model: model, notifications: $notifications)
                case .focusFilter: FocusFilterGuidePage()
                case .shortcuts: ShortcutsGuidePage()
                }
            }
        }
        // A1: klik pri otevreni podstranky. Zadne gesto na radku (simultaneousGesture v Listu
        // pohltilo klepnuti a NavigationLink se neotevrel), zvuk spusti az zmena cesty.
        .onChange(of: path) { old, new in
            if new.count > old.count { FQFeedback.shared.tap() }
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

    /// C7: iCloud sync (jen se zapnutym FeatureFlags.iCloudSync).
    private var iCloudSection: some View {
        Section {
            Toggle(isOn: Binding(get: { iCloudSyncEnabled }, set: { value in
                iCloudSyncEnabled = value
                // Po zapnuti se hned nahraje mistni stav; stav z iCloudu se slouci pri dalsim spusteni.
                if value { CloudSync.scheduleUpload() }
            }).fqTapFeedback()) {
                SettingsRow(title: "Sync with iCloud", symbol: "icloud.fill", color: .blue)
            }
            .settingsToggleTint()
            SettingsRow(title: "Last synced", symbol: "clock.arrow.circlepath", color: .gray, value: CloudSync.lastSync.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
        } header: {
            Text("iCloud sync")
        } footer: {
            Text("Keeps your hero, progress and stats the same on all your devices with this Apple ID. Changes from another device show up the next time you open FocusQuest.")
        }
    }

    private var notificationSummary: String {
        switch notifications {
        case .denied: "Off"
        case .notDetermined: "Not set"
        case .allowed, .silent: model.preferences.isDailyReminderEnabled ? "Reminder on" : "On"
        }
    }

    /// O1/H1: vse na stred se stejnymi odstupy. Odkazy na jednom radku (.footnote, "Terms of Use" se nezalomi);
    /// kdyz se na uzky iPhone nebo s velkym pismem nevejdou, jsou pod sebou, kazdy na stredu.
    private var footer: some View {
        VStack(spacing: FQSpace.sm) {
            Text("FocusQuest version \(Self.appVersion)")
                .font(.footnote)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: FQSpace.sm) {
                    legalLinks(separated: true)
                }
                VStack(spacing: FQSpace.xs) {
                    legalLinks(separated: false)
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderless)
            // A6: nenapadny credit uplne dole.
            Text("Vibecoded with artificial intelligence")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, FQSpace.sm)
    }

    @ViewBuilder
    private func legalLinks(separated: Bool) -> some View {
        Button("Privacy Policy") { FQFeedback.shared.tap(); openURL(LegalLinks.privacy) }
            .lineLimit(1).fixedSize()
        if separated { Text("·").accessibilityHidden(true) }
        Button("Terms of Use") { FQFeedback.shared.tap(); openURL(LegalLinks.terms) }
            .lineLimit(1).fixedSize()
        if separated { Text("·").accessibilityHidden(true) }
        Button("Support") { FQFeedback.shared.tap(); openURL(LegalLinks.support) }
            .lineLimit(1).fixedSize()
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

/// Podstranky Nastaveni (navigace pres hodnotu, aby klik hral bez gesta na radku).
private enum SettingsPage: Hashable {
    case sounds, music, notifications, focusFilter, shortcuts
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
                        // Nova sila se hned ukaze (FQFeedback ma predvolby po update); klik jako u ostatnich voleb.
                        FQFeedback.shared.play(.tap)
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
        .navigationBarTitleDisplayMode(.inline)
        .settingsScrollEdges()
        .animation(reduceMotion ? nil : .default, value: prefs)
    }

    private func toggle(_ title: String, symbol: String, color: Color, isOn: Binding<Bool>) -> some View {
        // Prepinac je ovladaci prvek: klik a vibrace stejne jako tlacitka (pred zmenou hodnoty).
        Toggle(isOn: isOn.fqTapFeedback()) {
            SettingsRow(title: title, symbol: symbol, color: color)
        }
        .settingsToggleTint()
    }

    private func demo(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
    }

    /// Battle sounds: zapamatuje se, ze je hrac prepnul sam (jinak plati vychozi zapnuto, K1/D6).
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
        .navigationBarTitleDisplayMode(.inline)
        .settingsScrollEdges()
        .onDisappear { preview.stop() }
    }

    private func row(_ sound: BattleSound) -> some View {
        let isSelected = model.preferences.battleSound == sound
        let isPlaying = preview.playing == sound
        return HStack(spacing: FQSpace.md) {
            Button {
                FQFeedback.shared.tap()
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
                    FQFeedback.shared.tap()
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
                toggle("Streak in danger", symbol: "flame.fill", color: .red, isOn: notificationBinding(\.isStreakReminderEnabled))
                toggle("Battle finished", symbol: "flag.checkered", color: .orange, isOn: notificationBinding(\.isBattleDoneNotificationEnabled))
                toggle("Break is over", symbol: "cup.and.saucer.fill", color: .brown, isOn: notificationBinding(\.isBreakOverNotificationEnabled))
            } footer: {
                Text("The daily reminder comes at 17:00 if you haven't focused yet, Streak in danger at 20:00 if your streak would end tonight. Battle finished arrives when the countdown ends, Break is over when your 5 minute break ends.")
            }
            .disabled(notifications == .denied)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
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
            Button { FQFeedback.shared.tap(); Task { notifications = await NotificationPermission.request() } } label: {
                SettingsRow(title: "Allow notifications", symbol: "bell.fill", color: .red, showsChevron: true)
            }
        case .silent, .denied:
            Button {
                FQFeedback.shared.tap()
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            } label: {
                SettingsRow(title: "Open iPhone Settings", symbol: "bell.slash.fill", color: .gray, value: notifications == .denied ? "Off" : "Quiet", showsChevron: true)
            }
        }
    }

    private func toggle(_ title: String, symbol: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn.fqTapFeedback()) {
            SettingsRow(title: title, symbol: symbol, color: color)
        }
        .settingsToggleTint()
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
    /// S1/M4: "Change class (free)" otevre list zmeny tridy bez lektvaru.
    @State private var showsClassChange = false
    /// Znovu onboarding (1A) i tutorial (1B) od zacatku.
    var onResetOnboarding: (() -> Void)?

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
                Text("Extra pauses: \(profile.profile.extraPauses) of \(UserProfile.maxExtraPauses) · Streak freezes: \(profile.profile.streakFreezes) of \(StreakFreeze.maxOwned)").monospacedDigit().foregroundStyle(.secondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("+3 extra pauses") { profile.debugAddExtraPauses(3) }
                    debugButton("+1 streak freeze") { profile.debugAddStreakFreeze() }
                }
            }
            VStack(alignment: .leading, spacing: FQSpace.sm) {
                Text("Class: \(profile.profile.heroClass.displayName) · Class Potions: \(profile.profile.classPotions) of \(UserProfile.maxClassPotions)").monospacedDigit().foregroundStyle(.secondary)
                ChipFlow(spacing: FQSpace.sm) {
                    debugButton("Change class (free)") { showsClassChange = true }
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
                    debugButton("Reset onboarding") { onResetOnboarding?() }
                }
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Not in the release build. \"Win now\" in a running battle wins it at once, with rewards.")
        }
        .sheet(isPresented: $showsClassChange) {
            ClassChangeSheet(model: profile, mode: .debugFree) { showsClassChange = false }
                .presentationDragIndicator(.visible)
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

        // C1: nahled widgetu se skutecnymi daty. Nahrada za App Group: bez ni widget na plose data nema.
        Section {
            let snapshot = WidgetSnapshot.current()
            VStack(alignment: .leading, spacing: FQSpace.md) {
                widgetPreview(snapshot, family: .systemSmall, width: 158)
                widgetPreview(snapshot, family: .systemMedium, width: 338)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, FQSpace.sm)
            SettingsRow(title: "App Group", symbol: "square.stack.3d.up.fill", color: .purple, value: WidgetSnapshot.isSharingAvailable ? "Shared with widget" : "Not available")
            // C7: kolik mista zabira ulozeny stav (iCloud KVS ma limit 1 MB).
            SettingsRow(title: "Saved data", symbol: "internaldrive.fill", color: .gray, value: Self.savedDataText())
        } header: {
            Text("Debug widget")
        } footer: {
            Text("The same views as the Home Screen widget, with live data. Without an App Group (free Apple ID) the real widget shows Open FocusQuest.")
        }
    }

    /// C7: velikost ulozeneho stavu ("12 KB").
    private static func savedDataText() -> String {
        var total = 0
        for entry in AppStateStore.byteSizes(in: .standard) { total += entry.bytes }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    private func widgetPreview(_ snapshot: WidgetSnapshot, family: WidgetFamily, width: CGFloat) -> some View {
        FocusWidgetContent(snapshot: snapshot, family: family, date: Date())
            .padding(16)
            .frame(width: width, height: 158)
            .background { FocusWidgetBackground() }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title) { FQFeedback.shared.tap(); action() }
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

    /// Q1/J2: podstranky maji systemovou listu s malym nadpisem a zpet. V klidu je lista pruhledna, po odrolovani
    /// je pod ni material (iOS 26: tvrdy scroll edge efekt nahore, dole mekky), obsah pod ni mizi.
    /// Driv (O1) bylo pozadi listy vzdy viditelne a na iOS 26 zakrylo velky nadpis.
    @ViewBuilder func settingsScrollEdges() -> some View {
        let bar = self
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.bar, for: .navigationBar)
        if #available(iOS 26.0, *) {
            bar
                .scrollEdgeEffectStyle(.hard, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            bar
        }
    }
}

// MARK: - Nadpis korene (Q1/J2)

/// Velky nadpis vlevo (hlavicka prvni sekce). Pri odrolovani se zmensi a zpruhledni,
/// nahore ho vystrida maly nadpis na stredu.
private struct SettingsLargeTitle: View {
    let title: String
    let progress: CGFloat

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(.primary)
            .textCase(nil)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .scaleEffect(1 - 0.12 * progress, anchor: .bottomLeading)
            .opacity(1 - progress)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: FQSpace.sm, trailing: 0))
            .accessibilityAddTraits(.isHeader)
    }
}

/// Maly nadpis na stredu nahore s materialem pod sebou (jako navigacni lista po odrolovani).
/// V klidu je neviditelny; bez zachytavani dotyku.
private struct SettingsCompactTitleBar: View {
    /// Vyska listy pod grabberem (jako systemova lista v listu).
    static let height: CGFloat = 54
    let title: String
    let progress: CGFloat

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background {
                Rectangle().fill(.bar)
                    .overlay(alignment: .bottom) { Divider() }
                    .ignoresSafeArea(edges: .top)
            }
            .opacity(progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Sleduje, o kolik je seznam odrolovany, a prevadi to na prechod velkeho nadpisu v maly
/// (0 v klidu, 1 po odrolovani o vysku velkeho nadpisu). Na iOS 18+ z rolovaci plochy;
/// na iOS 17 velky nadpis jen odroluje s obsahem (maly se neukaze).
private struct SettingsTitleScrollTracker: ViewModifier {
    @Binding var progress: CGFloat
    /// O kolik bodu se nadpis prolne (zhruba vyska velkeho nadpisu).
    static let distance: CGFloat = 40

    static func progress(forOffset offset: CGFloat) -> CGFloat {
        min(1, max(0, offset / distance))
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                let value = Self.progress(forOffset: offset)
                if abs(value - progress) > 0.001 { progress = value }
            }
        } else {
            content
        }
    }
}

// MARK: - Navody (C3, C4)

/// C3: jak pridat FocusQuest do iOS Focus rezimu.
private struct FocusFilterGuidePage: View {
    @Environment(\.openURL) private var openURL
    @State private var state = FocusModeState.load()

    var body: some View {
        List {
            Section {
                step(1, "Open iPhone Settings › Focus and pick a Focus, for example Study or Work.")
                step(2, "Scroll down to Focus Filters and tap Add Filter.")
                step(3, "Choose FocusQuest and turn on Suggest a battle, Mute reminders or both.")
            } header: {
                Text("How to set it up")
            } footer: {
                Text("While that Focus is on, Home offers a battle right away and FocusQuest stays quiet. When the Focus ends, everything goes back to normal.")
            }
            Section {
                SettingsRow(title: "Focus filter", symbol: "moon.fill", color: .indigo, value: state.isActive ? "Active now" : "Not active")
            }
            Section {
                Button {
                    FQFeedback.shared.tap()
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    SettingsRow(title: "Open iPhone Settings", symbol: "gear", color: .gray, showsChevron: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Use with iPhone Focus")
        .navigationBarTitleDisplayMode(.inline)
        .settingsScrollEdges()
        .onReceive(NotificationCenter.default.publisher(for: FocusModeState.didChange)) { _ in state = FocusModeState.load() }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Color.white, in: Circle())
                .accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// C4: zkratky pro Siri, Spotlight a Action button.
private struct ShortcutsGuidePage: View {
    var body: some View {
        List {
            Section {
                phrase("Start a battle in FocusQuest", "Opens FocusQuest ready to fight your next boss.")
                phrase("Show my FocusQuest streak", "Says your current streak.")
                phrase("Pause my FocusQuest battle", "Uses your free (or extra) pause in a running battle.")
            } header: {
                Text("Say to Siri")
            } footer: {
                Text("The same actions are in the Shortcuts app and in Spotlight. Start battle can also fight a set length, for example 25 minutes.")
            }
            Section {
                Text("iPhone Settings › Action Button › Shortcut › FocusQuest › Start battle.")
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Action button")
            } footer: {
                Text("On iPhone 15 Pro and newer. One press opens FocusQuest with the next boss ready.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .settingsScrollEdges()
    }

    private func phrase(_ text: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("“\(text)”").font(.body.weight(.semibold))
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
