import SwiftUI

/// Pozadi vsech obrazovek: syta barevna mesh gradient plocha (fialova, magenta, modra, tyrkys),
/// ktera pomalu plyne. Sklenene karty ji rozmazou a prosvitne jimi - jako ve visionOS.
/// Na iOS 17 (bez MeshGradient) ji nahradi nekolik velkych rozmazanych barevnych svetel.
struct FocusQuestBackdrop: View {
    var alert = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            if #available(iOS 18.0, *) {
                MeshGradient(width: 3, height: 3, points: meshPoints, colors: meshColors(isDark: isDark), smoothsColors: true)
            } else {
                fallbackGlows(isDark: isDark)
            }
            // Ve tmavem rezimu barvy lehce ztlumime, aby text na kartach zustal citelny.
            if isDark { Color.black.opacity(0.18) }
            // Varovani pri zvednuti telefonu: cela plocha zcervena.
            LinearGradient(colors: [FQColor.alarm.opacity(0.55), FQColor.danger.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .opacity(alert ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: alert)
        .onAppear {
            guard !reduceMotion, !drift else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }

    /// Prostredni body mesh site se pomalu posouvaji, okraje zustavaji na miste.
    private var meshPoints: [SIMD2<Float>] {
        [
            [0, 0], [drift ? 0.62 : 0.38, 0], [1, 0],
            [0, drift ? 0.38 : 0.58], [drift ? 0.34 : 0.66, drift ? 0.60 : 0.42], [1, drift ? 0.62 : 0.40],
            [0, 1], [drift ? 0.40 : 0.64, 1], [1, 1]
        ]
    }

    private func meshColors(isDark: Bool) -> [Color] {
        isDark
            ? [
                Color(red: 0.16, green: 0.06, blue: 0.42), Color(red: 0.46, green: 0.12, blue: 0.78), Color(red: 0.86, green: 0.18, blue: 0.58),
                Color(red: 0.06, green: 0.26, blue: 0.86), Color(red: 0.30, green: 0.10, blue: 0.58), Color(red: 0.96, green: 0.38, blue: 0.32),
                Color(red: 0.00, green: 0.52, blue: 0.62), Color(red: 0.12, green: 0.18, blue: 0.66), Color(red: 0.52, green: 0.14, blue: 0.74)
            ]
            : [
                Color(red: 0.50, green: 0.60, blue: 1.00), Color(red: 0.78, green: 0.56, blue: 1.00), Color(red: 1.00, green: 0.60, blue: 0.78),
                Color(red: 0.42, green: 0.82, blue: 0.98), Color(red: 0.72, green: 0.66, blue: 1.00), Color(red: 1.00, green: 0.74, blue: 0.56),
                Color(red: 0.44, green: 0.92, blue: 0.80), Color(red: 0.56, green: 0.66, blue: 1.00), Color(red: 0.88, green: 0.60, blue: 1.00)
            ]
    }

    private func fallbackGlows(isDark: Bool) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                (isDark ? Color(red: 0.18, green: 0.08, blue: 0.40) : Color(red: 0.70, green: 0.68, blue: 1.00))
                glow(isDark ? Color(red: 0.86, green: 0.18, blue: 0.58) : Color(red: 1.00, green: 0.60, blue: 0.78), diameter: width * 1.3)
                    .position(x: width * (drift ? 0.95 : 0.75), y: height * (drift ? 0.08 : 0.18))
                glow(isDark ? Color(red: 0.06, green: 0.26, blue: 0.86) : Color(red: 0.42, green: 0.82, blue: 0.98), diameter: width * 1.5)
                    .position(x: width * (drift ? 0.05 : 0.22), y: height * (drift ? 0.50 : 0.40))
                glow(isDark ? Color(red: 0.00, green: 0.52, blue: 0.62) : Color(red: 0.44, green: 0.92, blue: 0.80), diameter: width * 1.2)
                    .position(x: width * (drift ? 0.30 : 0.15), y: height * 0.95)
                glow(isDark ? Color(red: 0.96, green: 0.38, blue: 0.32) : Color(red: 1.00, green: 0.74, blue: 0.56), diameter: width * 1.0)
                    .position(x: width * (drift ? 0.85 : 0.95), y: height * (drift ? 0.72 : 0.62))
            }
        }
    }

    private func glow(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
    }
}
