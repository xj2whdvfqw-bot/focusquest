import SwiftUI

/// Kostra obrazovky: pozadi + rolovaci sloupec se stejnymi okraji a rozestupy sekci.
struct ScreenScaffold<Content: View>: View {
    var alert = false
    /// Ktera pixelova krajina je za obrazovkou.
    var scene: BackdropScene = .enchantedForest
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: alert, scene: scene)
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
        // Krajina je vzdy nocni, takze text a sklo musi byt vzdy v tmavem rezimu (i v listech).
        .preferredColorScheme(.dark)
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
                // Nadpis lezi primo na pixelove krajine; stin ho oddeli od hvezd a mesice.
                .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Otevira list Nastaveni odkudkoli. MainTabView ho vlozi do prostredi;
/// kde v prostredi neni (tvorba hrdiny, samotne Nastaveni), ozubene kolo se nezobrazi.
@Observable
@MainActor
final class SettingsPresenter {
    var isPresented = false
}

/// Male ozubene kolo vpravo nahore, ktere otevre Nastaveni.
struct SettingsGearButton: View {
    @Environment(SettingsPresenter.self) private var presenter: SettingsPresenter?

    var body: some View {
        if let presenter {
            Button { presenter.isPresented = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .glassControl(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }
}

/// Nadpis obrazovky s ozubenym kolem Nastaveni v pravem hornim rohu.
struct ScreenHeader: View {
    var eyebrow: String?
    let title: String

    var body: some View {
        HStack(alignment: .top, spacing: FQSpace.sm) {
            ScreenTitle(eyebrow: eyebrow, title: title)
            Spacer(minLength: FQSpace.sm)
            SettingsGearButton()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Rozbalovaci volba v radku karty: aktualni hodnota na jednom radku + sipky.
/// (Systemovy Picker ve stylu .menu hodnotu lamal na dva radky a pretekal z karty.)
struct ValueMenu<Value: Hashable, Options: View>: View {
    let title: String
    let valueText: String
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    var body: some View {
        Menu {
            Picker(title, selection: $selection) { options() }
        } label: {
            HStack(spacing: FQSpace.xs) {
                Text(valueText).font(.fqBody).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.fqMeta.weight(.semibold))
            }
            .foregroundStyle(FQColor.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .layoutPriority(1)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
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
            Circle().stroke(FQColor.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(FQColor.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            label()
        }
    }
}
