import SwiftUI
import UIKit

/// Prvni spusteni: 3 stranky se "Skip".
/// 1. pravidla hry, 2. predmety, 3. povoleni (pohyb, notifikace) a prvni 5minutova bitva.
struct OnboardingView: View {
    @ObservedObject var arena: ArenaViewModel
    /// Konec onboardingu; `startBattle` = hrac chce hned 5minutovou bitvu.
    let onFinish: (_ startBattle: Bool) -> Void

    @State private var page = 1
    /// Skutecny stav povoleni notifikaci v iOS.
    @State private var notifications = NotificationPermission.notDetermined
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private static let pageCount = 3

    var body: some View {
        ZStack {
            FocusQuestBackdrop(scene: .enchantedForest)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < Self.pageCount {
                        Button("Skip") { onFinish(false) }
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(FQColor.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(.plain)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, FQSpace.lg)
                ScrollView {
                    Group {
                        switch page {
                        case 1: rulesPage
                        case 2: subjectsPage
                        default: permissionsPage
                        }
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, FQSpace.lg)
                    .padding(.vertical, FQSpace.lg)
                    .id(page)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .scrollIndicators(.hidden)
                dots.padding(.bottom, FQSpace.md)
            }
        }
        .animation(.easeOut(duration: 0.25), value: page)
        .interactiveDismissDisabled()
    }

    // MARK: - 1. Pravidla

    private var rulesPage: some View {
        VStack(spacing: FQSpace.xl) {
            PixelArtAvatarView(sprite: .companion("lo-fi-cat"), size: 112)
                .accessibilityHidden(true)
            heading("Put your phone down.\nBeat the boss.")
            VStack(alignment: .leading, spacing: FQSpace.lg) {
                rule("iphone", title: "Face-down on the desk", detail: "Every boss has a fixed time. Lie still, it loses HP.")
                rule("flame", title: "Picked it up?", detail: "10 seconds to put it back. The first slip is forgiven.")
                rule("trophy", title: "Win", detail: "XP, coins and the next boss on your path.")
            }
            .padding(FQSpace.lg)
            .glassCard()
            ctaButton("Got it", symbol: nil) { page = 2 }
        }
    }

    private func rule(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: FQSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(FQColor.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                Text(detail).font(.fqSecondary).foregroundStyle(FQColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2. Predmety

    /// Dlazdice: predmety hrace a prvnich 12 navrhu, ktere jeste nema.
    private var tiles: [String] {
        let have = arena.visibleSubjects.map(\.title)
        let haveKeys = Set(have.map { $0.lowercased() })
        let extra = StudySubject.suggestions.prefix(12).filter { !haveKeys.contains($0.lowercased()) }
        return have + extra
    }

    private var subjectsPage: some View {
        let selected = Set(arena.visibleSubjects.map { $0.title.lowercased() })
        return VStack(spacing: FQSpace.lg) {
            heading("What are you studying?")
            Text("Tap a few. You can change them any time.")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
            ChipFlow(spacing: FQSpace.sm) {
                ForEach(tiles, id: \.self) { title in
                    let isOn = selected.contains(title.lowercased())
                    Button { withAnimation(.easeOut(duration: 0.15)) { arena.toggleOnboardingSubject(named: title) } } label: {
                        Text(title).fqChip(selected: isOn)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
                AddSubjectChip(model: arena, taken: arena.visibleSubjects) { _ in }
            }
            .frame(maxWidth: .infinity)
            ctaButton(selected.isEmpty ? "Skip for now" : "Continue", symbol: nil) { page = 3 }
        }
    }

    // MARK: - 3. Povoleni

    private var permissionsPage: some View {
        VStack(spacing: FQSpace.lg) {
            heading("Almost ready")
            Text("Nothing leaves your phone.")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
            VStack(spacing: 0) {
                // Senzor polohy (CoreMotion) systemove povoleni nepotrebuje, proto jen informace bez prepinace.
                motionInfoRow
                HairlineDivider()
                permissionRow("Notifications", detail: notificationsDetail, isOn: notifications == .allowed) {
                    if notifications == .denied { openNotificationSettings() }
                    else { Task { notifications = await NotificationPermission.request() } }
                }
            }
            .padding(.horizontal, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .glassCard()
            ctaButton("Start a 5 min battle", symbol: "play.fill") { onFinish(true) }
            Button("Look around first") { onFinish(false) }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .task { notifications = await NotificationPermission.current() }
        // Navrat z Nastaveni iPhonu: prepinac ukaze, co hrac v iOS zmenil.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notifications = await NotificationPermission.current() } }
        }
    }

    private var motionInfoRow: some View {
        HStack(spacing: FQSpace.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Motion sensor").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                Text("Knows when the phone is lifted. No permission needed.")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: FQSpace.sm)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(FQColor.accent)
                .accessibilityHidden(true)
        }
        .padding(.vertical, FQSpace.sm)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func permissionRow(_ title: String, detail: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: FQSpace.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.fqBody).foregroundStyle(FQColor.textPrimary)
                    Text(detail).font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                }
                Spacer(minLength: FQSpace.sm)
                // Vzhled systemoveho prepinace; zapnuti spusti systemovy dotaz.
                Capsule()
                    .fill(isOn ? FQColor.accent : Color.white.opacity(0.2))
                    .frame(width: 51, height: 31)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                    .animation(.easeOut(duration: 0.2), value: isOn)
            }
            .padding(.vertical, FQSpace.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var notificationsDetail: String {
        notifications == .denied ? "Off in iPhone Settings. Tap to open." : "Battle results, breaks, one daily nudge"
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }

    // MARK: - Stavebni prvky

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundStyle(FQColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// Zlute hlavni tlacitko (stejne jako Fight v Arene).
    private func ctaButton(_ title: String, symbol: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
            }
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(FQColor.onCta)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FQColor.cta, in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(1...Self.pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? FQColor.textPrimary : FQColor.textTertiary)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page) of \(Self.pageCount)")
    }
}
