import SwiftUI

/// Pozadi vsech obrazovek: tmave platno s nekolika rozmazanymi barevnymi svetly.
/// Sklenene karty maji diky nim co "lamat", ale platno zustava klidne a neutralni.
struct FocusQuestBackdrop: View {
    var alert = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.04, blue: 0.10), Color(red: 0.07, green: 0.06, blue: 0.16), Color(red: 0.03, green: 0.09, blue: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                glow(alert ? FQColor.danger : FQColor.accent, diameter: width * 1.1, opacity: alert ? 0.50 : 0.30)
                    .position(x: width * (drift ? 0.92 : 0.74), y: height * (drift ? 0.10 : 0.18))
                glow(Color(red: 0.36, green: 0.38, blue: 0.98), diameter: width * 1.3, opacity: 0.36)
                    .position(x: width * (drift ? 0.06 : 0.24), y: height * (drift ? 0.52 : 0.42))
                glow(Color(red: 0.76, green: 0.36, blue: 0.92), diameter: width * 1.0, opacity: 0.24)
                    .position(x: width * (drift ? 0.84 : 0.66), y: height * (drift ? 0.84 : 0.94))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: alert)
        .onAppear {
            guard !reduceMotion, !drift else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, diameter: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(0)], center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
    }
}
