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

/// Toast s volitelnou akci (Undo). Toast s akci zustane 5 s, bez ni 2,6 s.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var actionTitle: String? = nil
    var action: (@MainActor () -> Void)? = nil

    var duration: Duration { action == nil ? .seconds(2.6) : .seconds(5) }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }

    /// Toast po smazani s Undo na 5 s.
    static func undo(_ text: String, action: @escaping @MainActor () -> Void) -> ToastMessage {
        ToastMessage(text: text, actionTitle: "Undo", action: action)
    }
}

/// Kratke oznameni nahore uprostred: kremova pixelova bublina s tmavym obrysem 3 pt a tvrdym stinem.
struct PixelToast: View {
    let message: String
    var actionTitle: String? = nil
    var action: (@MainActor () -> Void)? = nil

    static let ink = Color(red: 27 / 255, green: 22 / 255, blue: 48 / 255)
    static let paper = Color(red: 1, green: 250 / 255, blue: 240 / 255)
    /// Barva akce v toastu (Undo).
    static let actionColor = Color(red: 180 / 255, green: 83 / 255, blue: 10 / 255)

    var body: some View {
        HStack(spacing: 14) {
            Text(message)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .foregroundStyle(Self.actionColor)
                    // Dotykova plocha 44 pt, ale bublina kvuli ni nevyroste.
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.vertical, -12)
                    .buttonStyle(.plain)
            }
        }
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Self.ink)
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
            .accessibilityElement(children: .contain)
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
    /// Kolik mista nad bossem bublina ma. Kdyz se nevejde, rozsiri se (mene radku) a pak zmensi pismo;
    /// vzdy roste od spodni hrany nahoru, takze bosse pod sebou neprekryje.
    var maxHeight: CGFloat? = nil

    static let widest: CGFloat = 300

    var body: some View {
        if let maxHeight {
            ViewThatFits(in: .vertical) {
                bubble(width: 240, size: 15)
                bubble(width: Self.widest, size: 15)
                bubble(width: Self.widest, size: 13)
                bubble(width: Self.widest, size: 11)
            }
            .frame(width: Self.widest, height: maxHeight, alignment: .bottom)
        } else {
            bubble(width: 240, size: 15)
        }
    }

    private func bubble(width: CGFloat, size: CGFloat) -> some View {
        CappedWidth(maxWidth: width) {
            Text(text)
                .font(.system(size: size, weight: .heavy, design: .rounded))
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

/// Jeden zobrazeny toast: akce (Undo) toast zavre a provede se; po `duration` zmizi sam.
private struct ToastHost: View {
    @Binding var toast: ToastMessage?
    let current: ToastMessage

    var body: some View {
        PixelToast(message: current.text, actionTitle: current.actionTitle, action: tapAction)
            // Do Sendable ulohy jdou jen id a delka (ToastMessage s akci Sendable neni).
            .task(id: current.id) { [id = current.id, duration = current.duration, binding = $toast] in
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled, binding.wrappedValue?.id == id else { return }
                withAnimation(.easeOut(duration: 0.2)) { binding.wrappedValue = nil }
            }
            .onAppear { UIAccessibility.post(notification: .announcement, argument: current.text) }
    }

    private var tapAction: (@MainActor () -> Void)? {
        guard current.action != nil else { return nil }
        return { runAction() }
    }

    private func runAction() {
        let action = current.action
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        action?()
    }
}

/// Pixelovy prichod toastu: 3 skoky dolu o 8 pt za 0,22 s (jako steps(3) v prototypu).
/// Pri Omezit pohyb se toast ukaze rovnou.
struct SteppedSlideIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private static let steps = 3
    private static let distance: CGFloat = 8

    func body(content: Content) -> some View {
        let progress = reduceMotion ? 1 : CGFloat(step) / CGFloat(Self.steps)
        content
            .offset(y: -Self.distance * (1 - progress))
            .opacity(Double(progress == 0 ? 0 : progress))
            .task {
                guard !reduceMotion else { return }
                for next in 1...Self.steps {
                    try? await Task.sleep(for: .milliseconds(73))
                    guard !Task.isCancelled else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { step = next }
                }
            }
    }
}

extension View {
    /// Zobrazi toast s volitelnou akci (Undo) nahore uprostred; sam zmizi po `duration`.
    func pixelToast(_ toast: Binding<ToastMessage?>) -> some View {
        overlay(alignment: .top) {
            if let current = toast.wrappedValue {
                ToastHost(toast: toast, current: current)
                    .padding(.top, FQSpace.sm)
                    .modifier(SteppedSlideIn())
                    // Objevi se 3 kroky (SteppedSlideIn), mizi plynulym zeslabenim.
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                    .id(current.id)
            }
        }
    }

    /// Zobrazi `message` jako PixelToast nahore uprostred; po 2,6 s ho sam schova.
    func pixelToast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .top) {
            if let text = message.wrappedValue {
                PixelToast(message: text)
                    .padding(.top, FQSpace.sm)
                    .modifier(SteppedSlideIn())
                    // Objevi se 3 kroky (SteppedSlideIn), mizi plynulym zeslabenim.
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
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
