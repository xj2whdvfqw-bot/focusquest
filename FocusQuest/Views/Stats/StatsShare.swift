import SwiftUI
import UIKit

// B4: sdileni statistik. Obrazek 1080 × 1920 (karta 360 × 640 bodu, ImageRenderer se skalou 3) ve stylu appky.
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

    static func make(stats: PlayerStats, profile: UserProfile, greetingName: String?, now: Date = Date(), calendar: Calendar = .current) -> ShareSnapshot {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let week = stats.sessionHistory.filter { $0.completedAt >= weekStart && $0.completedAt <= now }
        return ShareSnapshot(
            name: greetingName,
            hero: profile.avatar,
            heroClass: profile.heroClass,
            streak: stats.currentStreak(now: now, calendar: calendar),
            longestStreak: stats.longestStreak(calendar: calendar),
            weekMinutes: week.reduce(0) { $0 + max(0, $1.verifiedMinutes) },
            weekBosses: week.filter { $0.isQuick != true }.count,
            grid: HabitGrid.make(history: stats.sessionHistory, weeks: 5, now: now, calendar: calendar)
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

@MainActor
enum StatsShareRenderer {
    static let size = CGSize(width: 360, height: 640)

    static func render(_ snapshot: ShareSnapshot, template: ShareTemplate, showsName: Bool) -> UIImage? {
        let renderer = ImageRenderer(content: StatsShareCard(snapshot: snapshot, template: template, showsName: showsName)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark))
        // 360 × 640 bodu × 3 = 1080 × 1920 pixelu.
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Karta ke sdileni. ImageRenderer neumi materialy (rozmazani), proto je "sklo" z prechodu
/// a pruhlednych vyplni a sprity jsou staticke.
struct StatsShareCard: View {
    let snapshot: ShareSnapshot
    let template: ShareTemplate
    let showsName: Bool

    private static let ink = Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255)
    private static let flame = Color(red: 1.0, green: 0.55, blue: 0.20)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.14), Color(red: 0.12, green: 0.09, blue: 0.25), Color(red: 0.04, green: 0.12, blue: 0.16)], startPoint: .top, endPoint: .bottom)
            stars
            Circle()
                .fill(RadialGradient(colors: [(template == .streak ? Self.flame : FQColor.accent).opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 420, height: 420)
                .offset(y: -120)
            VStack(spacing: 0) {
                header
                Spacer(minLength: 18)
                HeroAvatarView(appearance: snapshot.hero, heroClass: snapshot.heroClass, size: 132)
                    .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 5)
                if showsName, let name = snapshot.name {
                    Text(name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(FQColor.textPrimary)
                        .lineLimit(1)
                        .padding(.top, 10)
                }
                Spacer(minLength: 18)
                switch template {
                case .weekly: weekly
                case .streak: streak
                }
                Spacer(minLength: 18)
                habits
                Spacer(minLength: 16)
                footer
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
        }
        .frame(width: StatsShareRenderer.size.width, height: StatsShareRenderer.size.height)
        .clipped()
    }

    private var header: some View {
        Text(template == .weekly ? "My focus week" : "On a roll")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(FQColor.textSecondary)
    }

    private var weekly: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.weekMinutes)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
                Text("min")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(FQColor.textSecondary)
            }
            Text("focused in the last 7 days")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
            HStack(spacing: 10) {
                tile(value: "\(snapshot.weekBosses)", label: snapshot.weekBosses == 1 ? "boss beaten" : "bosses beaten")
                tile(value: "\(snapshot.streak)", label: snapshot.streak == 1 ? "day streak" : "days streak", flame: true)
            }
        }
    }

    private var streak: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Self.flame, Color(red: 0.92, green: 0.31, blue: 0.09)], startPoint: .top, endPoint: .bottom))
                Text("\(snapshot.streak)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
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
            HStack(spacing: 10) {
                tile(value: "\(snapshot.weekMinutes)", label: "min this week")
                tile(value: "\(snapshot.weekBosses)", label: snapshot.weekBosses == 1 ? "boss beaten" : "bosses beaten")
            }
            .padding(.top, 6)
        }
    }

    private func tile(value: String, label: String, flame: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if flame {
                    Image(systemName: "flame.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Self.flame)
                }
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FQColor.textPrimary)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1) }
    }

    /// Mini Habits: 5 tydnu, dnesek vlevo nahore jako ve Stats.
    private var habits: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 5) {
                ForEach(Array(snapshot.grid.weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 5) {
                        ForEach(week) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(day.level == 0 ? Color.white.opacity(0.08) : HabitsCard.color(level: day.level))
                                .frame(width: 18, height: 18)
                                .overlay {
                                    if day.isToday {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                                    }
                                }
                        }
                    }
                }
            }
            Text("Habits · last 5 weeks")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(FQColor.textSecondary)
        }
        .padding(14)
        .background(Self.ink.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1) }
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
    }

    /// Par pixelovych hvezd v pozadi (pevne pozice, at je obrazek pokazde stejny).
    private var stars: some View {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (40, 70, 3), (300, 50, 2), (320, 160, 3), (60, 220, 2), (280, 300, 2),
            (30, 420, 3), (330, 470, 2), (190, 30, 2), (110, 140, 2), (250, 560, 3),
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(points.indices, id: \.self) { index in
                let point = points[index]
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: point.2, height: point.2)
                    .position(x: point.0, y: point.1)
            }
        }
        .frame(width: StatsShareRenderer.size.width, height: StatsShareRenderer.size.height)
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
    }

    /// Nahled presne toho, co se bude sdilet (zmensena karta 9:16).
    private var preview: some View {
        StatsShareCard(snapshot: snapshot, template: template, showsName: showsName)
            .scaleEffect(0.72)
            .frame(width: StatsShareRenderer.size.width * 0.72, height: StatsShareRenderer.size.height * 0.72)
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
        image = StatsShareRenderer.render(snapshot, template: template, showsName: showsName)
    }
}
