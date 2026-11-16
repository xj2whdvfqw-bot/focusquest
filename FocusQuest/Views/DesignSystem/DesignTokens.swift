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

/// Velka zaobleni: vzdusny "frosted glass" vzhled.
enum FQRadius {
    static let card: CGFloat = 32
    static let control: CGFloat = 20
    /// Pilulky (appky v onboardingu, volby casu): skoro polokruhove konce.
    static let pill: CGFloat = 26
    static let tile: CGFloat = 12
}

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
