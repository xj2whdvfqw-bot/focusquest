import SwiftUI
import UIKit

/// Nastaveni (list z ozubeneho kola): Sounds & notifications, Background, Feedback, patička a "✓ Done".
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScreenScaffold {
            if showsSounds {
                soundsPage.transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainPage.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: showsSounds)
        // Zavreni tahem dolu; ne behem potvrzeni "Reset progress" a ne behem mazani.
        // VoiceOver escape: ze stranky zvuku zpet na Nastaveni, z hlavni stranky zavrit.
        .fqSheetDismissal(blocked: showsResetConfirmation || isResetting) {
            if showsSounds { showsSounds = false } else { onClose?() }
        }
        .task { notifications = await NotificationPermission.current() }
        // Navrat z Nastaveni iPhonu: prepinace ukazi skutecny stav.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notifications = await NotificationPermission.current() } }
        }    }

    // MARK: - Hlavni stranka

    @ViewBuilder private var mainPage: some View {
        ScreenTitle(title: "Settings")
            .padding(.top, FQSpace.md)
        card {
            Button { showsSounds = true } label: {
                linkRow(icon: "bell", title: "Sounds & notifications", detail: soundsSummary)
            }
            .buttonStyle(.plain)
        }
        ScreenSection(title: "Background") {
            card {
                Button { onOpenBackgrounds?() } label: {
                    linkRow(icon: nil, title: profile.selectedBackground?.name ?? ShopBackground.worldName, detail: "Change it in Shop › Backgrounds")
                }
                .buttonStyle(.plain)
            }
        }
        ScreenSection(title: "Feedback") {
            card {
                Button { contactDeveloper() } label: {
                    linkRow(icon: "envelope", title: "Contact the developer", detail: "Report a bug or suggest an idea")
                }
                .buttonStyle(.plain)
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
                .buttonStyle(.plain)
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
        doneButton
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

    /// "Lo-fi · 3 of 3 sounds on · reminder off"
    private var soundsSummary: String {
        let prefs = model.preferences
        let reminder = notifications == .denied ? "notifications off" : "reminder \(prefs.isDailyReminderEnabled ? "on" : "off")"
        return "\(prefs.battleSound.title) · \(prefs.soundEffectsOnCount) of 3 sounds on · \(reminder)"
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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
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
                toggleRow("Tap and battle sounds", detail: "Clicks, hits and small effects", isOn: binding(\.isSFXEnabled))
                HairlineDivider()
                toggleRow("Achievement sounds", detail: "Victory jingle and level up", isOn: binding(\.isAchievementSoundEnabled))
                HairlineDivider()
                toggleRow("Alarm sound", detail: "Beeps when the phone is lifted", isOn: binding(\.isAlarmSoundEnabled))
                HairlineDivider()
                toggleRow("Vibrate on the alarm", detail: "When the phone is lifted mid-battle", isOn: binding(\.isHapticsEnabled))
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
        doneButton
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Stavebni prvky

    private var doneButton: some View {
        Button { onClose?() } label: {
            Label("Done", systemImage: "checkmark")
                .fqFont(size: 15, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .padding(.horizontal, FQSpace.xl)
                .frame(minHeight: 44)
                .overlay(Capsule().strokeBorder(FQColor.textSecondary.opacity(0.55), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Done, close settings")
    }

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
        .tint(FQColor.accent)
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
