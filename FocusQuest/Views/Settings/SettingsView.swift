import StoreKit
import SwiftUI

/// Nastaveni (list z ozubeneho kola): Sounds & notifications, Background, Feedback, patička a "✓ Done".
/// Zvuky a notifikace jsou na samostatne strance se zpetnym "‹ Settings".
struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var profile: ProfileViewModel
    var onClose: (() -> Void)? = nil
    /// Otevre Shop › Backgrounds (list se predtim zavre).
    var onOpenBackgrounds: (() -> Void)? = nil

    @State private var showsSounds = false
    @Environment(\.requestReview) private var requestReview
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
        .sheet(item: $model.selectedDocument) { LegalDocumentSheetView(document: $0).presentationDetents([.medium, .large]) }
    }

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
                HairlineDivider()
                Button { requestReview() } label: {
                    linkRow(icon: "star", title: "Rate this app", detail: "A quick rating helps a lot")
                }
                .buttonStyle(.plain)
            }
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
        return "\(prefs.battleSound.title) · \(prefs.soundEffectsOnCount) of 3 sounds on · reminder \(prefs.isDailyReminderEnabled ? "on" : "off")"
    }

    private var footer: some View {
        VStack(spacing: FQSpace.xs) {
            Text("FocusQuest version \(Self.appVersion)")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
            HStack(spacing: FQSpace.sm) {
                Button("Privacy Policy") { model.selectedDocument = .privacy }
                Text("·").accessibilityHidden(true)
                Button("Terms of Use") { model.selectedDocument = .terms }
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
                .font(.system(size: 22, weight: .semibold, design: .rounded))
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
                toggleRow("Daily reminder", detail: "A nudge at 17:00 if you haven't focused", isOn: binding(\.isDailyReminderEnabled))
                HairlineDivider()
                toggleRow("Battle finished", detail: "When the countdown ends", isOn: binding(\.isBattleDoneNotificationEnabled))
                HairlineDivider()
                toggleRow("Break is over", detail: "When your 5 minute break ends", isOn: binding(\.isBreakOverNotificationEnabled))
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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
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

    private func binding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.update { $0[keyPath: keyPath] = value } })
    }
}
