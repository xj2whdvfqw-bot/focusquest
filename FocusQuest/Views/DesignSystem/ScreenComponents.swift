import SwiftUI

/// Kostra obrazovky: pozadi + rolovaci sloupec se stejnymi okraji a rozestupy sekci.
struct ScreenScaffold<Content: View>: View {
    var alert = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: alert)
            ScrollView {
                VStack(alignment: .leading, spacing: FQSpace.xl) {
                    content()
                }
                .padding(.horizontal, FQSpace.lg)
                .padding(.top, FQSpace.sm)
                .padding(.bottom, FQSpace.xxl)
                // Na iPadu drzi obsah v citelne sirce misto roztazeni pres cely displej.
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Velky nadpis obrazovky s volitelnym nadtitulkem.
struct ScreenTitle: View {
    var eyebrow: String?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.xs) {
            if let eyebrow {
                Text(eyebrow).font(.fqLabel).foregroundStyle(FQColor.textSecondary)
            }
            Text(title).font(.fqLargeTitle).foregroundStyle(FQColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Nadpis sekce nad kartou.
struct SectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.fqLabel).foregroundStyle(FQColor.textSecondary)
            Spacer(minLength: FQSpace.sm)
            if let detail {
                Text(detail).font(.fqMeta).foregroundStyle(FQColor.textTertiary)
            }
        }
        .padding(.horizontal, FQSpace.xs)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Sekce = nadpis + obsah tesne pod nim (mensi mezera uvnitr skupiny nez mezi skupinami).
struct ScreenSection<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: FQSpace.sm) {
            SectionHeader(title: title, detail: detail)
            content()
        }
    }
}

/// Maly skleneny stitek se stavovou teckou.
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: FQSpace.sm) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.fqMeta.weight(.medium)).foregroundStyle(FQColor.textPrimary)
        }
        .padding(.horizontal, FQSpace.md)
        .padding(.vertical, FQSpace.sm)
        .glassControl(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Ctvercova dlazdice s ikonou, jako v systemovem Nastaveni.
struct IconTile: View {
    let symbol: String
    var color: Color = FQColor.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Vlasova linka mezi radky uvnitr karty.
struct HairlineDivider: View {
    var body: some View {
        Rectangle().fill(FQColor.hairline).frame(height: 1)
    }
}

/// Kruhovy ukazatel postupu s obsahem uprostred.
struct ProgressRing<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    @ViewBuilder let label: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(FQColor.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            label()
        }
    }
}
