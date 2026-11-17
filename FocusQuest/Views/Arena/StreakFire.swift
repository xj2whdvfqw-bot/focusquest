import SwiftUI

/// Pixelovy ohen kolem pilulky serie (easter egg v Arene, port `streakFire()` z prototypu).
/// Zapali se nahore uprostred, po smeru hodin obehne obrys za 0,9 s, 1,5 s hori a 0,8 s mizi.
/// Pohled je o `StreakFire.pad` bodu vetsi nez pilulka na kazde strane; vklada se jako
/// `.overlay { StreakFire(...).padding(-StreakFire.pad) }`.
struct StreakFire: View {
    /// Kdy ohen vzplanul; nova hodnota = nove zapaleni od zacatku.
    let start: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var simulation = Simulation()

    static let pad: CGFloat = 46

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                simulation.draw(
                    in: &context,
                    size: size,
                    elapsed: timeline.date.timeIntervalSince(start),
                    reduceMotion: reduceMotion
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: start) { simulation = Simulation() }
    }

    /// Stav castic mezi snimky. Trida, protoze Canvas kresli kazdy snimek znovu
    /// a castice musi prezit z jednoho snimku do dalsiho.
    final class Simulation {
        private struct Particle {
            var x, y, vx, vy: Double
            var life: Double
            let max: Double
        }

        private var particles: [Particle] = []
        private var lastElapsed: Double?

        private static let sweep = 0.9, hold = 1.5, fade = 0.8
        private static let pixel = 3.0
        /// Od nejsvetlejsi po nejtmavsi: #FFF6C4 #FFD64A #FF961E #EB5016 #A02412.
        private static let palette: [Color] = [
            Color(red: 255 / 255, green: 246 / 255, blue: 196 / 255),
            Color(red: 255 / 255, green: 214 / 255, blue: 74 / 255),
            Color(red: 255 / 255, green: 150 / 255, blue: 30 / 255),
            Color(red: 235 / 255, green: 80 / 255, blue: 22 / 255),
            Color(red: 160 / 255, green: 36 / 255, blue: 18 / 255),
        ]

        func draw(in context: inout GraphicsContext, size: CGSize, elapsed: Double, reduceMotion: Bool) {
            let el = max(0, elapsed)
            let dt = min(0.05, max(0, el - (lastElapsed ?? el)))
            lastElapsed = max(lastElapsed ?? el, el)

            let pad = Double(StreakFire.pad)
            let w = Double(size.width) - pad * 2, h = Double(size.height) - pad * 2
            guard w > 0, h > 0 else { return }
            let outline = Outline(pad: pad, width: w, height: h)

            let lit = min(1, el / Self.sweep)
            let power = el < Self.sweep + Self.hold ? 1 : max(0, 1 - (el - Self.sweep - Self.hold) / Self.fade)

            // Nove castice podel zapalene casti obrysu, vic na horici fronte.
            let rate = reduceMotion ? 30.0 : 170.0
            let count = Int((rate * dt * (0.4 + lit) * power).rounded()) + (el < Self.sweep ? 6 : 0)
            for _ in 0..<count {
                let atFront = el < Self.sweep && Double.random(in: 0..<1) < 0.45
                let t = atFront ? lit - Double.random(in: 0..<0.05) : Double.random(in: 0..<1) * lit
                let (ox, oy, nx, ny) = outline.point(at: t)
                let speed = 22 + Double.random(in: 0..<38)
                particles.append(Particle(
                    x: ox + nx * 2 + Double.random(in: -1.5..<1.5),
                    y: oy + ny * 2 + Double.random(in: -1.5..<1.5),
                    vx: nx * speed * 0.9 + Double.random(in: -5..<5),
                    vy: ny * speed * 0.9 - 26 - Double.random(in: 0..<18),
                    life: 0,
                    max: 0.3 + Double.random(in: 0..<0.4)
                ))
            }

            // Pohyb: castice leti ven a nahoru, zpomaluji a stoupaji.
            for index in particles.indices {
                particles[index].life += dt
                particles[index].x += particles[index].vx * dt
                particles[index].y += particles[index].vy * dt
                particles[index].vx *= 0.96
                particles[index].vy -= 30 * dt
            }
            particles.removeAll { $0.life >= $0.max }
            // Mlade nejdriv, starsi navrch (stejne poradi jako v prototypu).
            particles.sort { $0.life / $0.max < $1.life / $1.max }

            let px = Self.pixel
            for particle in particles {
                let k = particle.life / particle.max
                let shade = Self.palette[min(Self.palette.count - 1, max(0, Int(k * Double(Self.palette.count))))]
                // Mlada castice 3x3 pixely se svetlym stredem, pak 2x2, nakonec 1x1.
                let cells = k < 0.3 ? 3.0 : k < 0.65 ? 2.0 : 1.0
                let side = cells * px
                fill(&context, x: particle.x - side / 2, y: particle.y - side / 2, side: side, color: shade)
                if cells == 3 {
                    fill(&context, x: particle.x - px / 2, y: particle.y - px / 2, side: px, color: Self.palette[0])
                }
            }

            // 1px zhava linka po obrysu s bezicim blikanim.
            let steps = Int((outline.perimeter / px).rounded())
            let lastStep = Int(Double(steps) * lit)
            let flicker = Int(el * 1000 / 90)
            context.opacity = power
            if steps > 0 {
                for step in 0...lastStep {
                    let (x, y, _, _) = outline.point(at: Double(step) / Double(steps))
                    let hot = (step + flicker) % 4
                    let color = power < 1 ? Self.palette[3] : hot == 0 ? Self.palette[1] : hot == 1 ? Self.palette[2] : Self.palette[3]
                    fill(&context, x: x - px / 2, y: y - px / 2, side: px, color: color)
                }
            }
            context.opacity = 1
        }

        /// Ctverec zarovnany na pixelovou mrizku 3 body.
        private func fill(_ context: inout GraphicsContext, x: Double, y: Double, side: Double, color: Color) {
            let px = Self.pixel
            let rect = CGRect(x: (x / px).rounded() * px, y: (y / px).rounded() * px, width: side, height: side)
            context.fill(Path(rect), with: .color(color))
        }
    }

    /// Obrys pilulky: bod a normala pro t z 0...1, od horniho stredu po smeru hodin.
    private struct Outline {
        let pad: Double, width: Double, height: Double

        private var radius: Double { height / 2 }
        private var straight: Double { max(0, width - 2 * radius) }
        var perimeter: Double { 2 * straight + 2 * .pi * radius }

        func point(at t: Double) -> (Double, Double, Double, Double) {
            var d = (t.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * perimeter
            let cx = pad + width / 2, top = pad, bottom = pad + height
            let left = pad + radius, right = pad + width - radius, cy = pad + height / 2
            if d < straight / 2 { return (cx + d, top, 0, -1) }
            d -= straight / 2
            if d < .pi * radius {
                let a = -Double.pi / 2 + d / radius
                return (right + cos(a) * radius, cy + sin(a) * radius, cos(a), sin(a))
            }
            d -= .pi * radius
            if d < straight { return (right - d, bottom, 0, 1) }
            d -= straight
            if d < .pi * radius {
                let a = Double.pi / 2 + d / radius
                return (left + cos(a) * radius, cy + sin(a) * radius, cos(a), sin(a))
            }
            d -= .pi * radius
            return (left + d, top, 0, -1)
        }
    }
}
