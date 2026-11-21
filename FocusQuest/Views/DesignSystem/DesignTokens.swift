import SwiftUI

// Designove tokeny appky. Barvy jsou v Shared/FQColor.swift (sdili je i Live Activity).

/// Rozestupy: 8pt mrizka pro rozlozeni, 4pt pro drobne mezery uvnitr prvku.
enum FQSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    /// Okraj obrazovky: o neco vzdusnejsi nez vnitrni rozestupy.
    static let gutter: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// Polomery rohu (FQRadius) jsou v Shared/FQRadius.swift: sdili je appka i Live Activity.

/// Typografie: SF Pro Rounded (systemove pismo, zaoblena varianta), tri rezy (regular / medium / semibold).
/// Vedlejsi text nikdy pod 13 pt. Pixelove pismo (Pixelify Sans) jen pro nadpisy obrazovek, viz `ScreenTitle`.
/// Styly jsou navazane na Dynamic Type, takze respektuji velikost textu v iOS.
extension Font {
    static let fqLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let fqTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let fqHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let fqBody = Font.system(.body, design: .rounded)
    static let fqLabel = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let fqSecondary = Font.system(.subheadline, design: .rounded)
    /// Nejmensi vedlejsi text: 13 pt (footnote).
    static let fqMeta = Font.system(.footnote, design: .rounded)
    /// Obri odpocet bitvy.
    static let fqTimer = Font.system(size: 84, weight: .medium, design: .rounded)

    /// Pixelove pismo nadpisu obrazovky (Pixelify Sans Medium, rez 500). Soubor je v Resources/Fonts
    /// a registruje ho UIAppFonts v Info.plist. Roste s Dynamic Type jako largeTitle.
    static func fqPixelTitle(size: CGFloat = FQType.screenTitleSize) -> Font {
        .custom(FQType.pixelFontName, size: size, relativeTo: .largeTitle)
    }
}

enum FQType {
    static let pixelFontName = "PixelifySans-Medium"
    static let screenTitleSize: CGFloat = 34
    /// Rozpal pismen nadpisu +5 % a mezery mezi slovy +12 % velikosti pisma.
    static let titleTracking: CGFloat = 0.05
    static let titleWordSpacing: CGFloat = 0.12
}

extension Color {
    /// Barva z 0xRRGGBB (barvy znacek v onboardingu).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Pevna velikost pisma z navrhu, ktera roste s Dynamic Type (nastaveni velikosti textu v iOS).
/// Zvetsi se nejvic 1,5x, aby se rozlozeni karet a tlacitek nerozpadlo. Pro ikony v pevnych
/// ramecich, casovace a dekorace zustava `.font(.system(size:))`.
struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let baseSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        baseSize = size
        self.weight = weight
        self.design = design
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: Self.textStyle(for: size))
    }

    func body(content: Content) -> some View {
        content.font(.system(size: min(scaledSize, baseSize * Self.maxScale), weight: weight, design: design))
    }

    static let maxScale: CGFloat = 1.5

    /// Textovy styl, se kterym velikost roste (podobne velke pismo roste podobne rychle).
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 26...: .title
        case 20..<26: .title3
        case 16..<20: .body
        case 13..<16: .subheadline
        default: .caption
        }
    }
}

extension View {
    /// `.font(.system(size:weight:design:))`, ale roste s Dynamic Type (viz ScaledSystemFont).
    func fqFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design))
    }
}
