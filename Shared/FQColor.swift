import SwiftUI
import UIKit

/// Barevne tokeny spolecne pro appku i Live Activity.
/// Jedna akcentova barva pro interaktivni prvky, zbytek jsou neutralni tony.
/// Tokeny se samy prepinaji podle Light / Dark rezimu iOS.
enum FQColor {
    /// Postup, uspech, odskrtnuti: rgb(107,230,199).
    static let accent = adaptive(light: (0.00, 0.48, 0.42, 1), dark: (107 / 255, 230 / 255, 199 / 255, 1))
    /// Text a ikony na akcentove plose.
    static let onAccent = adaptive(light: (1, 1, 1, 1), dark: (0.02, 0.13, 0.11, 1))
    /// Ustup, mazani, nastvany boss: rgb(255,84,102).
    static let danger = adaptive(light: (0.82, 0.13, 0.24, 1), dark: (1.0, 84 / 255, 102 / 255, 1))
    /// Zluta jen pro hlavni akce (Fight, Start Battle, Next boss): #FFD83D s textem #2A1E00.
    static let cta = Color(red: 1.0, green: 216 / 255, blue: 61 / 255)
    static let onCta = Color(red: 42 / 255, green: 30 / 255, blue: 0)
    /// Vypln sklenenych karet: rgba(13,11,28,0.60) nad rozmazanim.
    static let card = Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.60)
    /// Karta na svetlem pozadi (Daybreak, Sunset, Pyramids, Farm, Wind Farm): o neco tmavsi sklo.
    static let cardOnBright = Color(red: 13 / 255, green: 11 / 255, blue: 28 / 255).opacity(0.64)
    static let caution = adaptive(light: (0.72, 0.42, 0.00, 1), dark: (1.0, 0.72, 0.30, 1))

    static let textPrimary = adaptive(light: (0.07, 0.09, 0.16, 1), dark: (1, 1, 1, 1))
    /// Vedlejsi text: bila 78 %.
    static let textSecondary = adaptive(light: (0.07, 0.09, 0.16, 0.68), dark: (1, 1, 1, 0.78))
    /// Treti uroven textu: bila 50 %.
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
