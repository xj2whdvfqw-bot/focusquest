import SwiftUI

/// Kostra obrazovky: pozadi + rolovaci sloupec se stejnymi okraji a rozestupy sekci.
struct ScreenScaffold<Content: View>: View {
    var alert = false
    /// Ktera pixelova krajina je za obrazovkou.
    var scene: BackdropScene = .enchantedForest
    /// Obsah je aspon tak vysoky jako obrazovka, takze Spacer v nem odsune
    /// hlavni akci dolu k palci (Arena). Kdyz se obsah nevejde, normalne roluje.
    var fillsHeight = false
    /// Svisla mezera mezi bloky obsahu.
    var spacing: CGFloat = FQSpace.xl
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            FocusQuestBackdrop(alert: alert, scene: scene)
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing) {
                        content()
                    }
                    // Svetla pozadi: bily text dostane silny stin, aby byl citelny.
                    .modifier(BrightTextShadow())
                    .padding(.horizontal, FQSpace.lg)
                    .padding(.top, FQSpace.sm)
                    .padding(.bottom, fillsHeight ? FQSpace.lg : FQSpace.xxl)
                    // Na iPadu drzi obsah v citelne sirce misto roztazeni pres cely displej.
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: fillsHeight ? proxy.size.height : nil, alignment: .top)
                    // Po prepnuti zalozky se obsah plynule objevi (krajina za nim stoji).
                    .modifier(TabSwitchEntrance())
                }
                .scrollIndicators(.hidden)
            }
            // Obsah roluje pod stavovy radek a Dynamic Island; tmavy prechod ho tam ztlumi.
            StatusBarFade()
        }
        // Krajina je vzdy nocni, takze text a sklo musi byt vzdy v tmavem rezimu (i v listech).
        .preferredColorScheme(.dark)
    }
}

/// Prechod za stavovym radkem a Dynamic Islandem: rgba(6,5,16,.75) nahore -> pruhledna, 90 pt od horni
/// hrany displeje. Obsah pod nim jezdit muze, cas zustane citelny. Stejny na vsech zalozkach i v bitve.
/// GeometryReader saha az pod stavovy radek: uvnitr bezpecne zony by mel horni odsazeni 0
/// a prechod by se nikdy nekreslil (proto driv obsah prejizdel pres hodiny).
/// V listu (sheet) stavovy radek neni (horni odsazeni 0), tam se nekresli.
struct StatusBarFade: View {
    static let height: CGFloat = 90
    static let topOpacity = 0.75

    var body: some View {
        GeometryReader { proxy in
            if proxy.safeAreaInsets.top > 0 {
                let ink = Color(red: 6 / 255, green: 5 / 255, blue: 16 / 255)
                LinearGradient(colors: [ink.opacity(Self.topOpacity), ink.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
            Text(Self.styled(title))
                .font(.fqPixelTitle())
                .foregroundStyle(FQColor.textPrimary)
                // Nadpis lezi primo na pixelove krajine; mekka zare ho oddeli od hvezd a mesice.
                .shadow(color: .black.opacity(0.45), radius: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Pixelove pismo potrebuje vic vzduchu: +5 % mezi pismeny a +12 % navic za kazdou mezerou,
    /// jinak splyvaji slova i tvary jako G.
    static func styled(_ title: String, size: CGFloat = FQType.screenTitleSize) -> AttributedString {
        var text = AttributedString(title)
        text.tracking = size * FQType.titleTracking
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(afterCharacter: index)
            if text.characters[index] == " " {
                text[index..<next].tracking = size * (FQType.titleTracking + FQType.titleWordSpacing)
            }
            index = next
        }
        return text
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
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(FQColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .glassControl(in: Circle(), interactive: true)
            }
            .buttonStyle(.fqPress)
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
        .glassControl(in: RoundedRectangle(cornerRadius: FQRadius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Ctvercova dlazdice s ikonou, jako v systemovem Nastaveni.
struct IconTile: View {
    let symbol: String
    var color: Color = FQColor.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
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
    var animationDuration: Double = 0.4
    @ViewBuilder let label: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(FQColor.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(FQColor.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: animationDuration), value: progress)
            label()
        }
    }
}

/// Ikona a text jako jeden vycentrovany blok: ikona je na zacatku prvniho radku (soucast textu),
/// dalsi radky jsou taky na stred. Pro samostatna sdeleni uprostred obrazovky a na prekryvech.
struct CenteredIconText: View {
    let text: String
    let systemImage: String

    init(_ text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        Text("\(Image(systemName: systemImage)) \(text)")
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}
