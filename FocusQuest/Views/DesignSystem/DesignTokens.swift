import SwiftUI

// Designove tokeny appky. Barvy jsou v Shared/FQColor.swift (sdili je i Live Activity).

/// Rozestupy: 8pt mrizka pro rozlozeni, 4pt pro drobne mezery uvnitr prvku.
enum FQSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum FQRadius {
    static let card: CGFloat = 24
    static let control: CGFloat = 16
    static let tile: CGFloat = 8
}

/// Typografie: systemove pismo SF, tri rezy (regular / medium / semibold), nic pod 12 pt.
/// Styly jsou navazane na Dynamic Type, takze respektuji velikost textu v iOS.
extension Font {
    static let fqLargeTitle = Font.largeTitle.weight(.semibold)
    static let fqTitle = Font.title2.weight(.semibold)
    static let fqHeadline = Font.headline
    static let fqBody = Font.body
    static let fqLabel = Font.subheadline.weight(.medium)
    static let fqSecondary = Font.subheadline
    static let fqMeta = Font.caption
}
