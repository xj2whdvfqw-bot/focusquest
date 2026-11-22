import SwiftUI


struct PixelArtAvatarView: View {
    let sprite: PixelSprite
    var startled = false
    var hitFlash = false
    var isEnraged = false
    var size: CGFloat = 112
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Dychani (~3 snimky/s) stoji s Reduce Motion a kdyz appka neni na obrazovce (setri baterii).
    private var still: Bool { reduceMotion || scenePhase != .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.35, paused: still)) { timeline in
            let bob = startled || reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 2.4) * 2
            Canvas(opaque: false, rendersAsynchronously: true) { context, canvasSize in
                let rows = SpritePalette.rows(for: sprite, startled: startled)
                guard let first = rows.first, !first.isEmpty else { return }
                let cell = min(canvasSize.width / CGFloat(first.count), canvasSize.height / CGFloat(rows.count))
                let left = (canvasSize.width - cell * CGFloat(first.count)) / 2
                let top = (canvasSize.height - cell * CGFloat(rows.count)) / 2
                for (y, row) in rows.enumerated() {
                    for (x, symbol) in row.enumerated() where symbol != "." {
                        let color = hitFlash ? Color.white : (isEnraged ? Color.red : SpritePalette.color(for: symbol))
                        let rect = CGRect(x: left + CGFloat(x) * cell, y: top + CGFloat(y) * cell + bob, width: cell + 0.2, height: cell + 0.2)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .frame(width: size, height: size)
            .accessibilityLabel(SpritePalette.label(for: sprite))
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.12), value: startled)
    }
}

