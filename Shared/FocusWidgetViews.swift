import SwiftUI
import WidgetKit

/// C1: obsah widgetu na plochu (maly a stredni). Je v Shared, aby ho appka umela ukazat v Debug nahledu
/// se skutecnymi daty (nahrada za App Group, dokud neni placeny ucet).
/// `snapshot` nil = widget nema data (bez App Group): ukaze vyzvu otevrit appku.
struct FocusWidgetContent: View {
    let snapshot: WidgetSnapshot?
    let family: WidgetFamily
    let date: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isTinted: Bool { renderingMode != .fullColor }
    private static let flame = Color(red: 1.0, green: 0.55, blue: 0.20)

    var body: some View {
        if let snapshot {
            switch family {
            case .systemMedium: medium(snapshot)
            default: small(snapshot)
            }
        } else {
            openPrompt
        }
    }

    // MARK: Maly

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                streakLabel(snapshot.streak(at: date))
                Spacer(minLength: 0)
                if let sprite = snapshot.nextBossSpriteID {
                    StaticPixelSprite(sprite: .boss(sprite), size: 40)
                        .widgetAccentable()
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 0)
            if let name = snapshot.nextBossName {
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            todayBar(snapshot)
        }
    }

    // MARK: Stredni

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                streakLabel(snapshot.streak(at: date))
                Spacer(minLength: 0)
                todayBar(snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 6) {
                if let sprite = snapshot.nextBossSpriteID {
                    StaticPixelSprite(sprite: .boss(sprite), size: 56)
                        .widgetAccentable()
                        .accessibilityHidden(true)
                }
                if let name = snapshot.nextBossName {
                    Text(name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: 9, weight: .bold))
                        Text("Fight · \(snapshot.nextBossMinutes ?? 0) min")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isTinted ? Color.white : Color(red: 42 / 255, green: 30 / 255, blue: 0))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isTinted ? Color.white.opacity(0.2) : FQColor.cta, in: Capsule())
                    .widgetAccentable()
                } else {
                    Text("All worlds cleared")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 128)
        }
    }

    // MARK: Casti

    private func streakLabel(_ days: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isTinted ? Color.white : Self.flame)
                    .widgetAccentable()
                Text("\(days)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            Text(days == 1 ? "day streak" : "days streak")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == 1 ? "1 day streak" : "\(days) days streak")
    }

    /// Dnesni minuty vs. Daily focus target: popisek a pixelovy prouzek.
    private func todayBar(_ snapshot: WidgetSnapshot) -> some View {
        let minutes = snapshot.todayMinutes(at: date)
        let goal = max(1, snapshot.dailyGoalMinutes)
        let fraction = min(1, Double(minutes) / Double(goal))
        return VStack(alignment: .leading, spacing: 4) {
            Text("Today \(minutes) / \(goal) min")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.18))
                    Rectangle()
                        .fill(isTinted ? Color.white : FQColor.accent)
                        .frame(width: proxy.size.width * fraction)
                        .widgetAccentable()
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today \(minutes) of \(goal) minutes")
    }

    /// Bez dat (App Group neni k dispozici, nebo appka jeste nebezela).
    private var openPrompt: some View {
        VStack(spacing: 8) {
            StaticPixelSprite(sprite: .boss("warmup-wisp"), size: family == .systemMedium ? 52 : 40)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text("Open FocusQuest")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Tap to start a battle")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Pozadi widgetu ve stylu appky: nocni prechod s par pixelovymi hvezdami.
struct FocusWidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.06, blue: 0.17), Color(red: 0.14, green: 0.10, blue: 0.28)], startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                let stars: [(CGFloat, CGFloat)] = [(0.12, 0.18), (0.78, 0.12), (0.9, 0.55), (0.35, 0.08), (0.6, 0.3)]
                ForEach(stars.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 2, height: 2)
                        .position(x: proxy.size.width * stars[index].0, y: proxy.size.height * stars[index].1)
                }
            }
        }
    }
}
