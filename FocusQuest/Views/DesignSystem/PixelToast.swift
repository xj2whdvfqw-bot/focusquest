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
