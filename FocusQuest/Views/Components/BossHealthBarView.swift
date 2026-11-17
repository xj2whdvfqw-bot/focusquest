import SwiftUI

/// Tenky pruh zdravi bosse bez cisla.
struct BossHealthBarView: View {
    /// Podil zbyvajiciho zdravi 0...1. Bitva ho pocita po sekundach, aby pruh ubyval plynule.
    let fraction: Double
    var tint: Color = FQColor.accent

    private var clamped: Double { min(1, max(0, fraction)) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FQColor.track)
                Capsule().fill(tint).frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 1), value: clamped)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Boss health")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}
