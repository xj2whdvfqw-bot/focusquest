import SwiftUI
import UIKit

/// Barevne tokeny spolecne pro appku i Live Activity.
/// Jedna akcentova barva pro interaktivni prvky, zbytek jsou neutralni tony.
/// Tokeny se samy prepinaji podle Light / Dark rezimu iOS.
enum FQColor {
    static let accent = adaptive(light: (0.00, 0.48, 0.42, 1), dark: (0.42, 0.90, 0.78, 1))
    /// Text a ikony na akcentove plose.
    static let onAccent = adaptive(light: (1, 1, 1, 1), dark: (0.02, 0.13, 0.11, 1))
    static let danger = adaptive(light: (0.82, 0.13, 0.24, 1), dark: (1.0, 0.33, 0.40, 1))
    static let caution = adaptive(light: (0.72, 0.42, 0.00, 1), dark: (1.0, 0.72, 0.30, 1))

    static let textPrimary = adaptive(light: (0.07, 0.09, 0.16, 1), dark: (1, 1, 1, 1))
    static let textSecondary = adaptive(light: (0.07, 0.09, 0.16, 0.68), dark: (1, 1, 1, 0.70))
    static let textTertiary = adaptive(light: (0.07, 0.09, 0.16, 0.50), dark: (1, 1, 1, 0.50))
    static let hairline = adaptive(light: (0.07, 0.09, 0.16, 0.10), dark: (1, 1, 1, 0.12))
    /// Jemna vypln stitku a cipu uvnitr karet.
    static let fill = adaptive(light: (0.07, 0.09, 0.16, 0.06), dark: (1, 1, 1, 0.08))
    /// Prazdna cast ukazatelu (HP, kruh postupu).
    static let track = adaptive(light: (0.07, 0.09, 0.16, 0.12), dark: (1, 1, 1, 0.12))

    // Nemenne barvy pro plochy, ktere jsou tmave vzdy (Live Activity, varovna obrazovka).
    static let mint = Color(red: 0.42, green: 0.90, blue: 0.78)
    static let alarm = Color(red: 1.0, green: 0.33, blue: 0.40)

    private typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    private static func adaptive(light: RGBA, dark: RGBA) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
        })
    }
}
