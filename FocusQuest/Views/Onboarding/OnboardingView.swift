import SwiftUI
import UIKit

/// Prvni spusteni: 4 stranky, ktere jde listovat swipem doleva i doprava (strankovany pager).
/// 1. pravidla hry, 2. predmety, 3. tvorba hrdiny (trida a vzhled), 4. povoleni.
/// Volby se ukladaji hned do modelu, takze se pri navratu na predchozi stranku neztrati.
struct OnboardingView: View {
    @ObservedObject var arena: ArenaViewModel
    @ObservedObject var profile: ProfileViewModel
    /// Konec onboardingu (posledni stranka nebo Skip).
    let onFinish: () -> Void

    @State private var page = 1
    /// Skutecny stav povoleni notifikaci v iOS.
    @State private var notifications = NotificationPermission.notDetermined
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private static let pageCount = 4

    var body: some View {
        ZStack {
            FocusQuestBackdrop(scene: .enchantedForest)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < Self.pageCount {
                        Button("Skip", action: onFinish)
                            .fqFont(size: 17, weight: .semibold, design: .rounded)
                            .foregroundStyle(FQColor.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(.fqPress)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, FQSpace.lg)
                // Strankovany pager: swipe je hlavni ovladani, tlacitka jen pomahaji.
                TabView(selection: $page) {
                    pageContainer(rulesPage).tag(1)
                    pageContainer(subjectsPage).tag(2)
                    pageContainer(heroPage).tag(3)
                    pageContainer(permissionsPage).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                dots.padding(.vertical, FQSpace.md)
            }
        }
        // Ikony v onboardingu jsou ciste bile.
        .foregroundStyle(.white)
        .interactiveDismissDisabled()
        .task { notifications = await NotificationPermission.current() }
        // Navrat z Nastaveni iPhonu: prepinac ukaze, co hrac v iOS zmenil.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { notifications = await NotificationPermission.current() } }
        }
    }

    /// Kazda stranka roluje sama (velke pismo, maly displej).
    private func pageContainer<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FQSpace.lg)
                .padding(.vertical, FQSpace.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func go(to target: Int) {
        withAnimation(reduceMotion ? nil : FQMotion.pop) { page = target }
    }

    // MARK: - 1. Pravidla

    private var rulesPage: some View {
        VStack(spacing: FQSpace.xl) {
            PixelArtAvatarView(sprite: .companion("lo-fi-cat"), size: 112)
                .accessibilityHidden(true)
            heading("Put your phone down.\nBeat the boss.")
            VStack(alignment: .leading, spacing: FQSpace.lg) {
                rule("iphone", title: "Face-down on the desk", detail: "Every boss has a fixed time. Lie still, it loses HP.")
                rule("flame", title: "Picked it up?", detail: "10 seconds to put it back, or the boss escapes.")
                rule("trophy", title: "Win", detail: "XP, coins and the next boss on your path.")
            }
            .padding(FQSpace.lg)
            .fqCard()
            ctaButton("Got it") { go(to: 2) }
        }
    }

    private func rule(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: FQSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(.white)
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
                    .buttonStyle(.fqPress)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
                AddSubjectChip(model: arena, taken: arena.visibleSubjects) { _ in }
            }
            .frame(maxWidth: .infinity)
            ctaButton(selected.isEmpty ? "Skip for now" : "Continue") { go(to: 3) }
        }
    }

    // MARK: - 3. Hrdina

    /// Stejna konfigurace jako na zalozce Hero: trida (cipy) a vzhled (HeroLookEditor). Uklada se hned.
    private var heroPage: some View {
        VStack(spacing: FQSpace.lg) {
            heading("Create your hero")
            HeroAvatarView(appearance: profile.profile.avatar, heroClass: profile.profile.heroClass, size: 112)
                .animation(FQMotion.quick, value: profile.profile.avatar)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FQSpace.md) {
                Text("Class").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                ChipFlow(spacing: FQSpace.sm) {
                    ForEach(HeroClass.allCases) { heroClass in
                        FQChip(title: heroClass.displayName, isSelected: heroClass == profile.profile.heroClass, compact: true) {
                            profile.updateHeroClass(heroClass)
                        }
                        .accessibilityLabel("Class \(heroClass.displayName)")
                    }
                }
                HairlineDivider()
                HeroLookEditor(appearance: profile.profile.avatar) { profile.updateAvatar($0) }
            }
            .padding(FQSpace.lg)
            .fqCard()
            Text("You can change all of this later on the Hero tab.")
                .font(.fqMeta)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
            ctaButton("Continue") { go(to: 4) }
        }
    }

    // MARK: - 4. Povoleni

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
                permissionRow("Notifications", detail: notificationsDetail, isOn: notifications == .allowed || notifications == .silent) {
                    if notifications == .denied { openNotificationSettings() }
                    else { Task { notifications = await NotificationPermission.request() } }
                }
            }
            .padding(.horizontal, FQSpace.lg)
            .padding(.vertical, FQSpace.xs)
            .fqCard()
            ctaButton("Start my quest", action: onFinish)
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
                .foregroundStyle(.white)
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
                    .fill(isOn ? FQColor.toggleOn : Color.white.opacity(0.2))
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
        .buttonStyle(.fqPress)
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
            .fqFont(size: 28, weight: .heavy, design: .rounded)
            .foregroundStyle(FQColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// Zlute hlavni tlacitko (stejne jako Fight v Arene).
    private func ctaButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fqFont(size: 20, weight: .heavy, design: .rounded)
                .foregroundStyle(FQColor.onCta)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(FQColor.cta, in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
        }
        .buttonStyle(.fqPress)
    }

    /// Tecky stranek; klepnuti na tecku na ni prejde (swipe je hlavni ovladani).
    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(1...Self.pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? FQColor.textPrimary : FQColor.textTertiary)
                    .frame(width: 7, height: 7)
                    .frame(width: 16, height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture { go(to: index) }
            }
        }
        .animation(FQMotion.quick, value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page) of \(Self.pageCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: go(to: min(Self.pageCount, page + 1))
            case .decrement: go(to: max(1, page - 1))
            @unknown default: break
            }
        }
    }
}
