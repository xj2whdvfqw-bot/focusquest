import SwiftUI

/// Uvodni onboarding pri prvnim spusteni (F2, 1A): stranky jdou listovat swipem, tecky dole, zpet sipkou
/// i swipem. Volby jsou v jednom konceptu (`Draft`), takze se pri listovani neztrati; do profilu se ulozi
/// az tlacitkem Start. Notifikace se tu neresi (zadaji se kontextove po prvni bitve).
struct OnboardingView: View {
    @ObservedObject var arena: ArenaViewModel
    @ObservedObject var profile: ProfileViewModel
    /// Konec onboardingu (Start na posledni strance).
    let onFinish: () -> Void

    private enum Page: Int, CaseIterable {
        case welcome, howItWorks, name, focus, hero, ready
    }

    private struct Draft {
        var name = ""
        var focus: [String] = ["Work"]
        var custom: [String] = []
        var heroClass: HeroClass = .warrior
        var avatar = AvatarAppearance()
    }

    /// Navrhy "Na co si chces udelat cas" (ne predmety ke studiu).
    static let focusSuggestions = ["Work", "School", "Reading", "Project", "Exercise", "Creative", "Languages"]

    @State private var page = Page.welcome
    @State private var draft = Draft()
    @State private var customDraft = ""
    @FocusState private var nameFocused: Bool
    @FocusState private var customFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var displayName: String { UserProfile.cleanName(draft.name) ?? "Hero" }

    var body: some View {
        ZStack {
            FocusQuestBackdrop(scene: .enchantedForest)
            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    pageContainer(welcomePage).tag(Page.welcome)
                    pageContainer(howItWorksPage).tag(Page.howItWorks)
                    pageContainer(namePage).tag(Page.name)
                    pageContainer(focusPage).tag(Page.focus)
                    heroPage.tag(Page.hero)
                    pageContainer(readyPage).tag(Page.ready)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Spodni cast je mimo stranky: Continue je vzdy nad teckami, nic ho neschova.
                VStack(spacing: FQSpace.md) {
                    ctaButton
                    dots
                }
                .padding(.horizontal, FQSpace.gutter)
                .padding(.bottom, FQSpace.sm)
            }
        }
        .foregroundStyle(.white)
        .interactiveDismissDisabled()
        .onAppear(perform: loadDraft)
        .onChange(of: page) { _, value in
            // Jmeno: klavesnice naskoci sama; jinde zmizi.
            nameFocused = value == .name
            if value != .focus { customFocused = false }
        }
    }

    // MARK: - Ramec

    private var topBar: some View {
        HStack {
            if page != .welcome {
                Button { go(to: page.rawValue - 1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.fqPress)
                .accessibilityLabel("Back")
            }
            Spacer()
            // Skip jen u uvodnich stranek: preskoci na jmeno, volby hrdiny se nepreskakuji.
            if page.rawValue < Page.name.rawValue {
                Button("Skip") { go(to: Page.name.rawValue) }
                    .fqFont(size: 17, weight: .semibold, design: .rounded)
                    .foregroundStyle(FQColor.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.fqPress)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, FQSpace.md)
    }

    private func pageContainer<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FQSpace.gutter)
                .padding(.vertical, FQSpace.lg)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func go(to index: Int) {
        guard let target = Page(rawValue: min(max(index, 0), Page.allCases.count - 1)) else { return }
        withAnimation(reduceMotion ? nil : FQMotion.pop) { page = target }
    }

    // MARK: - 1. Vitej

    private var welcomePage: some View {
        VStack(spacing: FQSpace.xl) {
            duel(size: 104)
                .padding(.top, FQSpace.xl)
            heading("Focus.\nYour hero fights.")
            Text("FocusQuest turns focus time into battles. Stay with your task and your hero beats the boss.")
                .font(.fqBody)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Hrdina proti bossovi: hrdina dycha, boss se pohupuje (s Reduce Motion stoji).
    private func duel(size: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: FQSpace.lg) {
            HeroAvatarView(appearance: draft.avatar, heroClass: draft.heroClass, size: size)
                .modifier(IdleBob(amplitude: 3, period: 1.6, enabled: !reduceMotion))
            Text("VS")
                .fqFont(size: 22, weight: .heavy, design: .rounded)
                .foregroundStyle(FQColor.cta)
                .padding(.bottom, size * 0.35)
            PixelArtAvatarView(sprite: .boss(Self.welcomeBoss.pixelSpriteConfig), size: size)
                .modifier(IdleBob(amplitude: 6, period: 2.2, enabled: !reduceMotion))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your hero facing a boss")
    }

    private static let welcomeBoss: Boss = BossWorld.allCases.first?.bosses.first ?? .warmUpWisp

    // MARK: - 2. Jak to funguje

    private var howItWorksPage: some View {
        VStack(spacing: FQSpace.xl) {
            heading("How it works")
            VStack(alignment: .leading, spacing: FQSpace.lg) {
                rule("timer", title: "You focus", detail: "Pick a boss and start a focus session.")
                rule("figure.fencing", title: "Your hero fights", detail: "While you stay focused, the boss loses HP.")
                rule("sparkles", title: "You grow", detail: "Win coins and gear, unlock new worlds.")
            }
            .padding(FQSpace.lg)
            .fqCard()
        }
        .padding(.top, FQSpace.xl)
    }

    private func rule(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: FQSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(FQColor.cta)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.fqHeadline).foregroundStyle(FQColor.textPrimary)
                Text(detail).font(.fqSecondary).foregroundStyle(FQColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 3. Jmeno

    private var namePage: some View {
        VStack(spacing: FQSpace.lg) {
            heading("What should we call you?")
            Text("Your hero will greet you by this name.")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
            TextField("", text: $draft.name, prompt: Text("Your name").foregroundStyle(FQColor.textTertiary))
                .fqFont(size: 22, weight: .semibold, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($nameFocused)
                .onSubmit { go(to: Page.focus.rawValue) }
                .onChange(of: draft.name) { _, value in
                    if value.count > UserProfile.nameLimit { draft.name = String(value.prefix(UserProfile.nameLimit)) }
                }
                .padding(.horizontal, FQSpace.lg)
                .frame(minHeight: 56)
                .fqCard()
                .accessibilityLabel("Your name")
            if !trimmedName.isEmpty && UserProfile.cleanName(draft.name) == nil {
                Text("Use letters, numbers or spaces.")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.caution)
            }
        }
        .padding(.top, FQSpace.xl)
    }

    // MARK: - 4. Na co si chces udelat cas

    private var focusOptions: [String] {
        var seen = Set<String>()
        return (Self.focusSuggestions + draft.custom).filter { seen.insert(StudySubject.matchKey($0)).inserted }
    }

    private func isSelected(_ title: String) -> Bool {
        draft.focus.contains { StudySubject.matchKey($0) == StudySubject.matchKey(title) }
    }

    private var focusPage: some View {
        VStack(spacing: FQSpace.lg) {
            heading("What do you want to make time for?")
            Text("Pick as many as you like. You'll choose one before each battle.")
                .font(.fqSecondary)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            ChipFlow(spacing: FQSpace.sm) {
                ForEach(focusOptions, id: \.self) { title in
                    let on = isSelected(title)
                    Button { toggleFocus(title) } label: { Text(title).fqChip(selected: on) }
                        .buttonStyle(.fqPress)
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
                customField
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, FQSpace.lg)
    }

    /// Vlastni polozka: psani primo v cipu, Enter ji prida a vybere.
    private var customField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FQColor.textSecondary)
                .accessibilityHidden(true)
            TextField("", text: $customDraft, prompt: Text("Your own").foregroundStyle(FQColor.textTertiary))
                .fqFont(size: 15, weight: .medium, design: .rounded)
                .foregroundStyle(FQColor.textPrimary)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($customFocused)
                .onSubmit(addCustom)
                .frame(width: 110)
                .accessibilityLabel("Add your own")
        }
        .padding(.horizontal, FQChipMetrics.padding)
        .frame(height: FQChipMetrics.height)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])) }
    }

    private func toggleFocus(_ title: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            if isSelected(title) {
                draft.focus.removeAll { StudySubject.matchKey($0) == StudySubject.matchKey(title) }
            } else {
                draft.focus.append(title)
            }
        }
    }

    private func addCustom() {
        let name = customDraft.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        customDraft = ""
        guard !StudySubject.matchKey(name).isEmpty else { return }
        let title = String((name.prefix(1).uppercased() + name.dropFirst()).prefix(24))
        withAnimation(.easeOut(duration: 0.15)) {
            if !focusOptions.contains(where: { StudySubject.matchKey($0) == StudySubject.matchKey(title) }) { draft.custom.append(title) }
            if !isSelected(title) { draft.focus.append(title) }
        }
    }

    // MARK: - 5. Hrdina

    /// Hrdina je pripnuty nahore a vzdy cely videt; roluje se jen panel s volbami.
    private var heroPage: some View {
        VStack(spacing: FQSpace.md) {
            heading("Create your hero")
                .padding(.top, FQSpace.sm)
            HeroAvatarView(appearance: draft.avatar, heroClass: draft.heroClass, size: 120)
                .keyframeAnimator(initialValue: 1.0, trigger: HeroLook(heroClass: draft.heroClass, avatar: draft.avatar)) { view, scale in
                    view.scaleEffect(scale, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        // Reduce Motion: bez poskoceni.
                        MoveKeyframe(1.0)
                        CubicKeyframe(reduceMotion ? 1.0 : 1.08, duration: 0.1)
                        SpringKeyframe(1.0, duration: 0.25, spring: .bouncy)
                    }
                }
                .frame(height: 124)
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: FQSpace.md) {
                    VStack(alignment: .leading, spacing: FQSpace.xs) {
                        Text("Class").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                        FadingHorizontalScroll {
                            HStack(spacing: FQSpace.sm) {
                                ForEach(HeroClass.allCases) { heroClass in
                                    FQChip(title: heroClass.displayName, isSelected: heroClass == draft.heroClass, compact: true) {
                                        draft.heroClass = heroClass
                                    }
                                    .accessibilityLabel("Class \(heroClass.displayName)")
                                }
                            }
                        }
                    }
                    HairlineDivider()
                    HeroLookEditor(appearance: draft.avatar) { draft.avatar = $0 }
                }
                .padding(FQSpace.lg)
                .fqCard()
                .padding(.horizontal, FQSpace.gutter)
                .padding(.bottom, FQSpace.lg)
                Text("You can change all of this later on the Hero tab.")
                    .font(.fqMeta)
                    .foregroundStyle(FQColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, FQSpace.lg)
            }
            .scrollIndicators(.hidden)
            // Obsah pod hrdinou mizi do ztracena, ne ostrou hranou.
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(maxWidth: 560)
    }

    private struct HeroLook: Equatable {
        let heroClass: HeroClass
        let avatar: AvatarAppearance
    }

    // MARK: - 6. Pripraven

    private var readyPage: some View {
        VStack(spacing: FQSpace.xl) {
            duel(size: 96)
                .padding(.top, FQSpace.xl)
            heading("Ready, \(displayName)?")
            Text("We'll show you around in a few quick steps.")
                .font(.fqBody)
                .foregroundStyle(FQColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Stavebni prvky

    private func heading(_ text: String) -> some View {
        Text(text)
            .fqFont(size: 28, weight: .heavy, design: .rounded)
            .foregroundStyle(FQColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.5), radius: 6)
            .accessibilityAddTraits(.isHeader)
    }

    private var canContinue: Bool {
        switch page {
        case .name: trimmedName.isEmpty || UserProfile.cleanName(draft.name) != nil
        case .focus: !draft.focus.isEmpty
        default: true
        }
    }

    /// Zlute hlavni tlacitko (stejne jako Fight na Home).
    private var ctaButton: some View {
        let title = page == .ready ? "Start" : "Continue"
        return Button {
            if page == .focus && !customDraft.isEmpty { addCustom() }
            if page == .ready { finish() } else { go(to: page.rawValue + 1) }
        } label: {
            Text(title)
                .fqFont(size: 20, weight: .heavy, design: .rounded)
                .foregroundStyle(FQColor.onCta)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(FQColor.cta, in: RoundedRectangle(cornerRadius: FQRadius.pill, style: .continuous))
        }
        .buttonStyle(.fqPress)
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.4)
        .animation(FQMotion.quick, value: canContinue)
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(Page.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == page ? FQColor.textPrimary : FQColor.textTertiary)
                    .frame(width: item == page ? 18 : 7, height: 7)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture { go(to: item.rawValue) }
            }
        }
        .animation(FQMotion.quick, value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(page.rawValue + 1) of \(Page.allCases.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: go(to: page.rawValue + 1)
            case .decrement: go(to: page.rawValue - 1)
            @unknown default: break
            }
        }
    }

    // MARK: - Data

    private func loadDraft() {
        let current = profile.profile
        draft.heroClass = current.heroClass
        draft.avatar = current.avatar
        if current.username != UserProfile.defaultUsername { draft.name = current.username }
    }

    /// Start: jmeno, hrdina a polozky "focus" se ulozi, pak Home a tutorial.
    private func finish() {
        profile.updateDisplayName(draft.name)
        profile.updateHeroClass(draft.heroClass)
        profile.updateAvatar(draft.avatar)
        profile.completeHeroCreation()
        let used = Set(profile.stats.sessionHistory.compactMap { $0.subject?.id })
        arena.applyOnboardingFocus(draft.focus.isEmpty ? ["Work"] : draft.focus, keeping: used)
        onFinish()
    }
}

/// Jemne pohupovani postavy na uvodni strance.
private struct IdleBob: ViewModifier {
    let amplitude: CGFloat
    let period: Double
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -amplitude : 0)
            } animation: { _ in .easeInOut(duration: period / 2) }
        } else {
            content
        }
    }
}

/// Vodorovna rada, ktera pretece: na kraji, kam jde jeste rolovat, mekce mizi (napoveda ke scrollu).
struct FadingHorizontalScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var contentFrame = CGRect.zero
    @State private var width: CGFloat = 0

    private static var fade: CGFloat { 28 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .scrollView(axis: .horizontal)) } action: { contentFrame = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .mask {
            let leading = contentFrame.minX < -1
            let trailing = contentFrame.maxX > width + 1
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(leading ? 0 : 1), .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.fade)
                Rectangle()
                LinearGradient(colors: [.black, .black.opacity(trailing ? 0 : 1)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.fade)
            }
        }
    }
}
