import SwiftUI

/// Barevne tokeny spolecne pro appku i Live Activity.
/// Jedna akcentova barva (mint) pro interaktivni prvky, zbytek jsou neutralni tony.
enum FQColor {
    static let accent = Color(red: 0.42, green: 0.90, blue: 0.78)
    /// Text a ikony na akcentove plose.
    static let onAccent = Color(red: 0.02, green: 0.13, blue: 0.11)
    static let danger = Color(red: 1.0, green: 0.33, blue: 0.40)
    static let caution = Color(red: 1.0, green: 0.72, blue: 0.30)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textTertiary = Color.white.opacity(0.50)
    static let hairline = Color.white.opacity(0.12)
}
