import SwiftUI

extension View {
    func glassmorphic(alert: Bool = false, radius: CGFloat = 24) -> some View {
        modifier(GlassmorphicModifier(alert: alert, radius: radius))
    }
}

struct GlassmorphicModifier: ViewModifier {
    let alert: Bool
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(alert ? 0.75 : 0.38), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: alert ? Color(red: 1, green: 0.12, blue: 0.3).opacity(0.35) : .black.opacity(0.35), radius: 20, y: 10)
    }
}

struct FocusQuestBackdrop: View {
    var alert = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.12, green: 0.08, blue: 0.17), Color(red: 0.06, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                Circle().fill(alert ? Color.red.opacity(0.28) : Color.cyan.opacity(0.12)).frame(width: 210, height: 210).blur(radius: 65).position(x: proxy.size.width * 0.88, y: 120)
                Circle().fill(Color.orange.opacity(0.1)).frame(width: 220, height: 220).blur(radius: 70).position(x: proxy.size.width * 0.08, y: proxy.size.height * 0.76)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: alert)
    }
}

struct SectionEyebrow: View {
    let title: String
    var body: some View { Text(title.uppercased()).font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(.white.opacity(0.58)) }
}