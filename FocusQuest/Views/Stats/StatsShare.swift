import SwiftUI
import UIKit

// B4: sdileni statistik. Obrazek 1080 × 1920 (karta 360 × 640 bodu, ImageRenderer se skalou 3) ve stylu appky,
// od K1 i na sirku 1920 × 1080.
// Na obrazku nejsou zadna osobni data krome jmena hrdiny, a to jen kdyz ho hrac zapne.

/// Co je na obrazku. Spocita se z historie bitev a profilu.
struct ShareSnapshot: Equatable {
    let name: String?
    let hero: AvatarAppearance
    let heroClass: HeroClass
    let streak: Int
    let longestStreak: Int
    /// Overene minuty za poslednich 7 dni vcetne dneska.
    let weekMinutes: Int
    /// Porazeni bossove za poslednich 7 dni (bez rychlych 5minutovych bitev).
    let weekBosses: Int
    /// Mini Habits: poslednich 5 tydnu.
    let grid: HabitGrid

    /// K1/D5: jmeno je vzdy `profile.username` (ne zastupne "Hero" z pozdravu); bez zadaneho jmena nil.
    static func make(stats: PlayerStats, profile: UserProfile, frozenDayKeys: Set<String> = [], now: Date = Date(), calendar: Calendar = .current) -> ShareSnapshot {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let week = stats.sessionHistory.filter { $0.completedAt >= weekStart && $0.completedAt <= now }
        return ShareSnapshot(
            name: profile.username == UserProfile.defaultUsername ? nil : UserProfile.cleanName(profile.username),
            hero: profile.avatar,
            heroClass: profile.heroClass,
            streak: stats.currentStreak(frozenDayKeys: frozenDayKeys, now: now, calendar: calendar),
            longestStreak: stats.longestStreak(calendar: calendar),
            weekMinutes: week.reduce(0) { $0 + max(0, $1.verifiedMinutes) },
            weekBosses: week.filter { $0.isQuick != true }.count,
            grid: HabitGrid.make(history: stats.sessionHistory, firstDay: profile.firstUseDate, frozenDayKeys: frozenDayKeys, now: now, calendar: calendar).recentWeeks(5)
        )
    }
}

enum ShareTemplate: String, CaseIterable, Identifiable {
    case weekly, streak
    var id: String { rawValue }
    var title: String { self == .weekly ? "This week" : "Streak" }
}

/// Milniky serie, po kterych Home jednou nabidne sdileni.
enum StreakMilestone {
    static let days = [7, 30, 100]
    /// Uz nabidnute milniky (cisla oddelena carkou).
    static let storageKey = "fq.offeredStreakMilestones"

    /// Milnik, ktery serie prave dosahla a jeste nebyl nabidnuty.
    static func due(streak: Int, offered: String) -> Int? {
        guard days.contains(streak) else { return nil }
        return parse(offered).contains(streak) ? nil : streak
    }

    static func adding(_ milestone: Int, to offered: String) -> String {
        (parse(offered) + [milestone]).sorted().map(String.init).joined(separator: ",")
    }

    private static func parse(_ text: String) -> [Int] {
        text.split(separator: ",").compactMap { Int($0) }
    }

    /// Dalsi milnik nad aktualni serii (pro sablonu Streak).
    static func next(after streak: Int) -> Int? { days.first { $0 > streak } }
}

/// K1/D5: format obrazku. Story 1080 × 1920 (Instagram, TikTok), Wide 1920 × 1080 (na sirku).
enum ShareFormat: String, CaseIterable, Identifiable {
    case story, wide
    var id: String { rawValue }
    var title: String { self == .story ? "Story" : "Wide" }
    /// Velikost v bodech; obrazek se renderuje se skalou 3.
    var size: CGSize { self == .story ? CGSize(width: 360, height: 640) : CGSize(width: 640, height: 360) }
    /// Bezpecny okraj ze vsech stran: 7,5 % sirky obrazku. Nic se ho nedotkne.
    var margin: CGFloat { (size.width * 0.075).rounded() }
}

@MainActor
enum StatsShareRenderer {
    static let scale: CGFloat = 3

    static func render(_ snapshot: ShareSnapshot, template: ShareTemplate, showsName: Bool, format: ShareFormat = .story) -> UIImage? {
        render(StatsShareCard(snapshot: snapshot, template: template, showsName: showsName, format: format), size: format.size, opaque: true)
    }

    /// Jen obsah bez pozadi (pruhledny obrazek): testy podle nej overuji bezpecne okraje.
    static func renderContentOnly(_ snapshot: ShareSnapshot, template: ShareTemplate, showsName: Bool, format: ShareFormat) -> UIImage? {
        render(StatsShareCard(snapshot: snapshot, template: template, showsName: showsName, format: format, drawsBackground: false), size: format.size, opaque: false)
    }

    private static func render(_ card: StatsShareCard, size: CGSize, opaque: Bool) -> UIImage? {
        let renderer = ImageRenderer(content: card
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark))
        // 360 × 640 bodu × 3 = 1080 × 1920 pixelu (Wide 1920 × 1080).
        renderer.scale = scale
        renderer.isOpaque = opaque
        return renderer.uiImage
    }
}

/// Karta ke sdileni. ImageRenderer neumi materialy (rozmazani), proto je "sklo" z prechodu
/// a pruhlednych vyplni a sprity jsou staticke.
/// K1/D5: obsah lezi v pevnem ramu s okrajem 7,5 % sirky; pozadi (zare, hvezdy) je jen `background`,
/// takze uz nemuze kartu roztahnout a obsah oriznout.
struct StatsShareCard: View {
    let snapshot: ShareSnapshot
    let template: ShareTemplate
    let showsName: Bool
    var format: ShareFormat = .story
    var drawsBackground = true

    private static let ink = Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255)
    private static let flame = Color(red: 1.0, green: 0.55, blue: 0.20)

    private enum Metrics {
        static let hero: CGFloat = 88
        static let cell: CGFloat = 12
        static let cellGap: CGFloat = 3
        static let tileGap: CGFloat = 12
    }

    private var size: CGSize { format.size }
    private var name: String? { showsName ? snapshot.name : nil }

    var body: some View {
        Group {
            switch format {
            case .story: storyLayout
            case .wide: wideLayout
            }
        }
        .padding(format.margin)
        .frame(width: size.width, height: size.height)
        .background { if drawsBackground { backdrop } }
        .clipped()
    }

    // MARK: Rozvrzeni

    private var storyLayout: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 14)
            heroBlock
            Spacer(minLength: 14)
            templateBlock
            Spacer(minLength: 14)
            habits
            Spacer(minLength: 14)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wideLayout: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 24) {
                VStack(spacing: 12) {
                    header
                    heroBlock
                }
                .frame(width: 150)
                templateBlock
                    .frame(maxWidth: .infinity)
                habits
            }
            .frame(maxHeight: .infinity)
            Spacer(minLength: 12)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heroBlock: some View {
        VStack(spacing: 8) {
            HeroAvatarView(appearance: snapshot.hero, heroClass: snapshot.heroClass, size: Metrics.hero, outlined: false)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 4)
            if let name {
                Text(name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    @ViewBuilder private var templateBlock: some View {
        switch template {
        case .weekly: weekly
        case .streak: streak
        }
    }

    // MARK: Pozadi

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.14), Color(red: 0.12, green: 0.09, blue: 0.25), Color(red: 0.04, green: 0.12, blue: 0.16)], startPoint: .top, endPoint: .bottom)
            stars
            Circle()
                .fill(RadialGradient(colors: [(template == .streak ? Self.flame : FQColor.accent).opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 400, height: 400)
                .offset(x: format == .wide ? -170 : 0, y: format == .wide ? -20 : -120)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: Bloky

    private var header: some View {
        Text(template == .weekly ? "My focus week" : "On a roll")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(FQColor.textSecondary)
            .lineLimit(1)
    }

    private var weekly: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.weekMinutes)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("min")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(FQColor.textSecondary)
            }
            Text("focused in the last 7 days")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(1)
            HStack(spacing: Metrics.tileGap) {
                tile(value: "\(snapshot.weekBosses)", label: snapshot.weekBosses == 1 ? "boss beaten" : "bosses beaten")
                tile(value: "\(snapshot.streak)", label: snapshot.streak == 1 ? "day streak" : "days streak", flame: true)
            }
            .padding(.top, 8)
        }
    }

    private var streak: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Self.flame, Color(red: 0.92, green: 0.31, blue: 0.09)], startPoint: .top, endPoint: .bottom))
                Text("\(snapshot.streak)")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(snapshot.streak == 1 ? "day in a row" : "days in a row")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(FQColor.textPrimary)
            Group {
                if let next = StreakMilestone.next(after: snapshot.streak) {
                    Text("Next milestone: \(next) days")
                } else {
                    Text("Longest streak: \(snapshot.longestStreak) days")
                }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(FQColor.textSecondary)
            .lineLimit(1)
            HStack(spacing: Metrics.tileGap) {
                tile(value: "\(snapshot.weekMinutes)", label: "min this week")
                tile(value: "\(snapshot.weekBosses)", label: snapshot.weekBosses == 1 ? "boss beaten" : "bosses beaten")
            }
            .padding(.top, 8)
        }
    }

    private func tile(value: String, label: String, flame: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if flame {
                    Image(systemName: "flame.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Self.flame)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
                    .lineLimit(1)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1) }
    }

    /// Mini Habits: celych 5 tydnu (7 radku pondeli az nedele × 5 sloupcu), stejna logika jako ve Stats:
    /// dny pred prvnim dnem jsou prazdne misto, budouci dny carkovane, dnesek s bilym rameckem, led u freeze.
    private var habits: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: Metrics.cellGap) {
                    ForEach(snapshot.grid.rowLetters.indices, id: \.self) { index in
                        Text(snapshot.grid.rowLetters[index])
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(FQColor.textTertiary)
                            .frame(width: 10, height: Metrics.cell)
                    }
                }
                HStack(alignment: .top, spacing: Metrics.cellGap) {
                    ForEach(Array(snapshot.grid.weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: Metrics.cellGap) {
                            ForEach(week) { day in cell(day) }
                        }
                    }
                }
            }
            Text("Habits · last 5 weeks")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Self.ink.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1) }
    }

    @ViewBuilder private func cell(_ day: HabitDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        Group {
            if day.isBeforeStart {
                Color.clear
            } else if day.isFuture {
                shape.strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else {
                shape
                    .fill(day.isFrozen && day.minutes == 0 ? HabitsCard.ice : day.level == 0 ? Color.white.opacity(0.08) : HabitsCard.color(level: day.level))
                    .overlay {
                        if day.isToday { shape.strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5) }
                    }
            }
        }
        .frame(width: Metrics.cell, height: Metrics.cell)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FQColor.cta)
            Text("FocusQuest")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(FQColor.textPrimary)
            Text("· beat procrastination")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
        }
        .lineLimit(1)
    }

    /// Par pixelovych hvezd v pozadi (pevne pozice v pomeru k velikosti, at je obrazek pokazde stejny).
    private var stars: some View {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.11, 0.11, 3), (0.83, 0.08, 2), (0.89, 0.25, 3), (0.17, 0.34, 2), (0.78, 0.47, 2),
            (0.08, 0.66, 3), (0.92, 0.73, 2), (0.53, 0.05, 2), (0.31, 0.22, 2), (0.69, 0.88, 3),
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(points.indices, id: \.self) { index in
                let point = points[index]
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: point.2, height: point.2)
                    .position(x: point.0 * size.width, y: point.1 * size.height)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Nahled a sdileni: prepinac sablon, volitelne jmeno a systemove sdileni (ShareLink).
struct StatsShareSheet: View {
    let snapshot: ShareSnapshot
    var initialTemplate: ShareTemplate = .weekly
    /// Nadpis nahore (napr. "7-day streak!" po dosazeni milniku).
    var headline: String = "Share your progress"
    let onClose: () -> Void

    @State private var template: ShareTemplate = .weekly
    @State private var format: ShareFormat = .story
    @State private var showsName = false
    @State private var image: UIImage?
    @State private var didSetUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FQSpace.lg) {
                    Picker("Template", selection: $template) {
                        ForEach(ShareTemplate.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fqTapSound(onChangeOf: template)

                    // K1/D5: Story 9:16 pro Instagram a TikTok, Wide 16:9 na sirku.
                    Picker("Format", selection: $format) {
                        ForEach(ShareFormat.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fqTapSound(onChangeOf: format)

                    preview

                    if snapshot.name != nil {
                        Toggle(isOn: $showsName.fqTapFeedback()) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show my name").font(.fqBody).foregroundStyle(FQColor.textPrimary)
                                Text("Nothing else personal is on the picture.").font(.fqMeta).foregroundStyle(FQColor.textSecondary)
                            }
                        }
                        .tint(.green)
                        .padding(FQSpace.md)
                        .fqCard()
                    } else {
                        Text("Nothing personal is on the picture.")
                            .font(.fqMeta)
                            .foregroundStyle(FQColor.textSecondary)
                    }

                    if let image {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("My FocusQuest progress", image: Image(uiImage: image))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .fqFont(size: 17, weight: .heavy, design: .rounded)
                                .foregroundStyle(FQColor.onCta)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 52)
                                .background(FQColor.cta, in: Capsule())
                        }
                        .simultaneousGesture(TapGesture().onEnded { FQFeedback.shared.tap() })
                    }
                }
                .padding(.horizontal, FQSpace.lg)
                .padding(.bottom, FQSpace.xl)
            }
            .navigationTitle(headline)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { FQFeedback.shared.tap(); onClose() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didSetUp else { return }
            didSetUp = true
            template = initialTemplate
            renderImage()
        }
        .onChange(of: template) { renderImage() }
        .onChange(of: showsName) { renderImage() }
        .onChange(of: format) { renderImage() }
    }

    /// Nahled presne toho, co se bude sdilet (zmensena karta).
    private var preview: some View {
        let scale: CGFloat = format == .story ? 0.72 : 0.52
        return StatsShareCard(snapshot: snapshot, template: template, showsName: showsName, format: format)
            .scaleEffect(scale)
            .frame(width: format.size.width * scale, height: format.size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1) }
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        switch template {
        case .weekly: "Picture: \(snapshot.weekMinutes) minutes focused this week, \(snapshot.weekBosses) bosses beaten, \(snapshot.streak) day streak"
        case .streak: "Picture: \(snapshot.streak) days in a row, \(snapshot.weekMinutes) minutes this week"
        }
    }

    private func renderImage() {
        image = StatsShareRenderer.render(snapshot, template: template, showsName: showsName, format: format)
    }
}
