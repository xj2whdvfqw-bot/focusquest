import SwiftUI
import UIKit

/// Obdelnik s pixelove schodovitymi rohy (dva schody po `step` bodech), jako bublina v pixel artu.
struct PixelBubbleShape: Shape {
    var step: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let s = step, d = step * 2
        let (x0, y0, x1, y1) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        var path = Path()
        path.addLines([
            CGPoint(x: x0, y: y0 + d), CGPoint(x: x0 + s, y: y0 + d), CGPoint(x: x0 + s, y: y0 + s),
            CGPoint(x: x0 + d, y: y0 + s), CGPoint(x: x0 + d, y: y0),
            CGPoint(x: x1 - d, y: y0), CGPoint(x: x1 - d, y: y0 + s), CGPoint(x: x1 - s, y: y0 + s),
            CGPoint(x: x1 - s, y: y0 + d), CGPoint(x: x1, y: y0 + d),
            CGPoint(x: x1, y: y1 - d), CGPoint(x: x1 - s, y: y1 - d), CGPoint(x: x1 - s, y: y1 - s),
            CGPoint(x: x1 - d, y: y1 - s), CGPoint(x: x1 - d, y: y1),
            CGPoint(x: x0 + d, y: y1), CGPoint(x: x0 + d, y: y1 - s), CGPoint(x: x0 + s, y: y1 - s),
            CGPoint(x: x0 + s, y: y1 - d), CGPoint(x: x0, y: y1 - d),
        ])
        path.closeSubpath()
        return path
    }
}

/// Kratke oznameni nahore uprostred: kremova pixelova bublina s tmavym obrysem 3 pt a tvrdym stinem.
struct PixelToast: View {
    let message: String

    static let ink = Color(red: 27 / 255, green: 22 / 255, blue: 48 / 255)
    static let paper = Color(red: 1, green: 250 / 255, blue: 240 / 255)

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Self.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 15)
            .background {
                ZStack {
                    PixelBubbleShape().fill(Self.ink)
                    PixelBubbleShape().fill(Self.paper).padding(3)
                }
                .compositingGroup()
                .shadow(color: Color(red: 10 / 255, green: 8 / 255, blue: 24 / 255).opacity(0.45), radius: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// Pixelova bublina se schodovitym ocaskem dole uprostred (`tail` bodu vysoky).
/// `inset` 0 = tmavy obrys, 3 = vypln uvnitr obrysu (stejne jako ::before a ::after v prototypu).
struct PixelSpeechBubbleShape: Shape {
    var inset: CGFloat = 0
    var tail: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail).insetBy(dx: inset, dy: inset)
        let mid = rect.midX
        var tailPath = Path()
        if inset == 0 {
            // Obrys ocasku: schod 12 bodu siroky, pod nim spicka 4 body.
            tailPath.addRect(CGRect(x: mid - 6, y: rect.maxY - tail - 1, width: 12, height: tail - 6 + 1))
            tailPath.addRect(CGRect(x: mid - 2, y: rect.maxY - 6, width: 4, height: 4))
        } else {
            // Vypln ocasku prekryje spodni obrys tela, takze bublina a ocasek splynou.
            tailPath.addRect(CGRect(x: mid - inset, y: body.maxY - 1, width: inset * 2, height: rect.maxY - 6 - body.maxY + 1))
        }
        // Sjednoceni misto addRect: prekryvajici se casti s opacnym smerem by se jinak vyrusily.
        return PixelBubbleShape().path(in: body).union(tailPath)
    }
}

/// Bublina bosse v Arene: kremova, nebo cervena, kdyz je boss nastvany.
struct PixelSpeechBubble: View {
    let text: String
    var angry = false

    var body: some View {
        CappedWidth(maxWidth: 240) {
            Text(text)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(angry ? Color.white : PixelToast.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 22)
                .background {
                    ZStack {
                        PixelSpeechBubbleShape().fill(PixelToast.ink)
                        PixelSpeechBubbleShape(inset: 3).fill(angry ? FQColor.danger : PixelToast.paper)
                    }
                    .compositingGroup()
                    .shadow(color: Color(red: 10 / 255, green: 8 / 255, blue: 24 / 255).opacity(0.45), radius: 0, y: 4)
                }
        }
    }
}

/// Nabidne obsahu nejvys `maxWidth` a prevezme jeho skutecnou velikost,
/// takze kratka hlaska ma uzkou bublinu a dlouha se zalomi.
struct CappedWidth: Layout {
    let maxWidth: CGFloat

    init(maxWidth: CGFloat) { self.maxWidth = maxWidth }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        return child.sizeThatFits(ProposedViewSize(width: min(proposal.width ?? maxWidth, maxWidth), height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(bounds.size))
    }
}

extension View {
    /// Zobrazi `message` jako PixelToast nahore uprostred; po 2,6 s ho sam schova.
    func pixelToast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .top) {
            if let text = message.wrappedValue {
                PixelToast(message: text)
                    .padding(.top, FQSpace.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(text)
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.6))
                        guard !Task.isCancelled, message.wrappedValue == text else { return }
                        withAnimation(.easeOut(duration: 0.2)) { message.wrappedValue = nil }
                    }
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: text) }
            }
        }
    }
}
