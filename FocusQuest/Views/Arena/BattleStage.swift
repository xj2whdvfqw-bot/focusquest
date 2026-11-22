import SwiftUI

/// Cim hrdina utoci: podle nasazene zbrane z obchodu, jinak podle povolani.
enum HeroAttack: Equatable, Sendable {
    /// Mec: svih a oblouk pres bosse.
    case slash
    /// Hul nebo carodej: zarici koule letici k bossovi.
    case spell
    /// Lukostrelec: sip.
    case arrow
    /// Zlodej: dve rychla bodnuti dykou.
    case stab
    /// Valecnik bez mece: vypad se stitem.
    case bash

    static func of(appearance: AvatarAppearance, heroClass: HeroClass) -> HeroAttack {
        switch appearance.equippedItemID(in: .weapon) {
        case "wooden-sword", "excalibur": return .slash
        case "magic-staff": return .spell
        default: break
        }
        return switch heroClass {
        case .warrior: .bash
        case .mage: .spell
        case .archer: .arrow
        case .rogue: .stab
        }
    }

    /// Kdy (s od zacatku utoku) zbran nebo strela zasahne bosse.
    var impact: Double {
        switch self {
        case .slash: 0.28
        case .spell: 0.46
        case .arrow: 0.36
        case .stab: 0.22
        case .bash: 0.30
        }
    }
}

extension AvatarSprite {
    /// Vrstvy hrdiny rozdelene na telo a zbran (cim utoci), aby se zbran dala zvlast natocit a sklopit.
    /// Vrstvy jsou tytez jako v obchode a profilu, jen rozdelene do dvou skupin.
    static func battleLayers(for appearance: AvatarAppearance, heroClass: HeroClass) -> (body: [AvatarLayer], weapon: [AvatarLayer]) {
        let all = layers(for: appearance, heroClass: heroClass)
        let weaponIDs: Set<String>
        if let id = appearance.equippedItemID(in: .weapon), let item = EquipmentItem.item(withID: id) {
            weaponIDs = Set(item.layers.map(\.id))
        } else {
            weaponIDs = switch heroClass {
            case .rogue: ["class-dagger", "class-hilt"]
            case .archer: ["class-bow", "class-string"]
            case .mage: ["class-orb", "class-spark"]
            case .warrior: ["class-shield", "class-crest"]
            }
        }
        return (all.filter { !weaponIDs.contains($0.id) }, all.filter { weaponIDs.contains($0.id) })
    }
}

/// Scena bitvy: hrdina vlevo, boss vpravo.
///
/// Rytmus je navazany na cas bitvy: kazdych `attackInterval` s hrdina zautoci, boss se otrese,
/// zablika a vyskoci cislo poskozeni (pruh zdravi dal ubyva podle odpoctu). Pri vyhre prijde
/// financi uder a boss padne, pri uteku hrdina sklopi zbran a boss utece.
///
/// Uspora baterie: vse se pocita z hodin v jednom TimelineView. Behem utoku bezi 30 snimku/s,
/// mezi utoky 2 snimky/s (hrdina jen prešlapuje o pixel), na pozadi nebo se zamcenym telefonem stoji.
/// S Reduce Motion je scena staticka (zadne utoky ani cisla, meni se jen pruh zdravi).
struct BattleStage: View {
    enum Phase: Equatable {
        /// Pred startem (cekani na polozeni telefonu).
        case waiting
        case fighting
        case paused
        /// Vyhra: financi uder, boss padne.
        case won
        /// Boss utekl: hrdina sklopi zbran, boss odbehne.
        case escaped
    }

    let boss: Boss
    let appearance: AvatarAppearance
    let heroClass: HeroClass
    let phase: Phase
    /// Sekundy bitvy; kazda `attackInterval`-ta spusti utok.
    let elapsed: Int
    var bossSize: CGFloat = 120
    var heroSize: CGFloat = 84

    static let attackInterval = 5
    /// Jak dlouho drzi BattleView vysledek, nez financi scena dobehne.
    static let finaleSeconds = 1.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var event: StageEvent?
    @State private var eventCounter = 0

    private var attack: HeroAttack { HeroAttack.of(appearance: appearance, heroClass: heroClass) }
    private var animates: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        let layers = AvatarSprite.battleLayers(for: appearance, heroClass: heroClass)
        // Behem utoku plynule (30 snimku/s), jinak 2 snimky/s; na pozadi a s Reduce Motion stoji.
        TimelineView(.animation(minimumInterval: event == nil ? 0.5 : 1.0 / 30, paused: !animates)) { context in
            GeometryReader { proxy in
                scene(at: shownDate(context.date), size: proxy.size, layers: layers)
            }
        }
        #if DEBUG
        .onAppear { if Self.debugFrozenAt != nil { start(.attack(index: 6)) } }
        #endif
        .onChange(of: elapsed) { old, new in
            guard phase == .fighting, animates, new > old, new > 0, new % Self.attackInterval == 0 else { return }
            start(.attack(index: new / Self.attackInterval))
        }
        .onChange(of: phase) { old, new in
            guard animates else { event = nil; return }
            let wasRunning = old == .fighting || old == .paused
            switch new {
            case .won where wasRunning: start(.finalBlow)
            case .escaped where wasRunning: start(.escape)
            case .waiting, .paused: event = nil
            default: break
            }
        }
        // Zvuk a vibrace v okamziku zasahu, pak se udalost ukonci a snimkovani zpomali.
        .task(id: event?.id) {
            guard let current = event else { return }
            #if DEBUG
            if Self.debugFrozenAt != nil { return }
            #endif
            let impact = current.impactTime(for: attack)
            if let impact {
                try? await Task.sleep(for: .seconds(impact))
                guard !Task.isCancelled else { return }
                // Bezny utok je bez zvuku (zvuk poskozeni byl odstranen); zni jen financi uder.
                if current.kind == .finalBlow {
                    FQFeedback.shared.play(.hit)
                    FQFeedback.shared.haptic(.heavy)
                }
            }
            try? await Task.sleep(for: .seconds(current.duration - (impact ?? 0)))
            guard !Task.isCancelled, event?.id == current.id else { return }
            event = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch phase {
        case .won: "Your hero defeated \(boss.name)"
        case .escaped: "\(boss.name) ran away"
        default: "Your hero, \(heroClass.displayName), fights \(boss.name)"
        }
    }

    /// Cas snimku; v Debug rezimu "battle-hit" (screenshot z CI) stoji scena uprostred utoku.
    private func shownDate(_ date: Date) -> Date {
        #if DEBUG
        if let frozen = Self.debugFrozenAt, let event { return event.start.addingTimeInterval(frozen) }
        #endif
        return date
    }

    #if DEBUG
    /// CI screenshot "battle-hit": kriticky zasah zastaveny 0,55 s od zacatku utoku.
    private static let debugFrozenAt: Double? = UserDefaults.standard.string(forKey: "initialTab") == "battle-hit" ? 0.55 : nil
    #endif

    private func start(_ kind: StageEvent.Kind) {
        eventCounter += 1
        event = StageEvent(id: eventCounter, kind: kind, start: .now)
    }

    // MARK: - Snimek sceny

    @ViewBuilder
    private func scene(at date: Date, size: CGSize, layers: (body: [AvatarLayer], weapon: [AvatarLayer])) -> some View {
        let frame = StageFrame.make(
            event: event, attack: attack, phase: phase, date: date,
            size: size, heroSize: heroSize, bossSize: bossSize, animates: animates
        )
        let heroCenter = CGPoint(x: size.width * 0.24, y: size.height * 0.6)
        let bossCenter = CGPoint(x: size.width * 0.70, y: size.height * 0.5)
        let weaponOnRight = Self.isOnRight(layers.weapon)
        ZStack {
            // Stiny na zemi.
            groundShadow(width: heroSize * 0.7).position(x: heroCenter.x, y: heroCenter.y + heroSize * 0.46)
            groundShadow(width: bossSize * 0.62)
                .opacity(frame.bossOpacity)
                .position(x: bossCenter.x + frame.bossOffset.width, y: bossCenter.y + bossSize * 0.44)
            // Zare za bossem v barve sveta.
            Circle()
                .fill(RadialGradient(colors: [boss.accent.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: bossSize * 0.55))
                .frame(width: bossSize * 1.1, height: bossSize * 1.1)
                .opacity(frame.bossOpacity)
                .position(bossCenter)

            PixelArtAvatarView(sprite: .boss(boss.pixelSpriteConfig), hitFlash: frame.bossFlash, size: bossSize)
                .scaleEffect(x: frame.bossFacingAway ? -1 : 1, y: 1)
                .rotationEffect(.degrees(frame.bossTilt), anchor: .bottom)
                .opacity(frame.bossOpacity)
                .position(x: bossCenter.x + frame.bossOffset.width, y: bossCenter.y + frame.bossOffset.height)

            hero(layers, weaponOnRight: weaponOnRight, frame: frame)
                .position(x: heroCenter.x + frame.heroOffset.width, y: heroCenter.y + frame.heroOffset.height)

            effects(frame: frame, hero: heroCenter, boss: bossCenter, weaponOnRight: weaponOnRight)
        }
        .frame(width: size.width, height: size.height)
    }

    private func hero(_ layers: (body: [AvatarLayer], weapon: [AvatarLayer]), weaponOnRight: Bool, frame: StageFrame) -> some View {
        // Ruka drzici zbran: prava (sloupec 13) nebo leva (sloupce 0-2), radek 9-10 mrizky 16x16.
        let anchor = UnitPoint(x: weaponOnRight ? 13.5 / 16 : 1.5 / 16, y: 9.5 / 16)
        return ZStack {
            PixelLayerStack(layers: layers.body)
            PixelLayerStack(layers: layers.weapon)
                .rotationEffect(.degrees(weaponOnRight ? frame.weaponAngle : -frame.weaponAngle * 0.3), anchor: anchor)
                .offset(y: weaponOnRight ? 0 : frame.weaponDrop * heroSize)
        }
        .frame(width: heroSize, height: heroSize)
        .rotationEffect(.degrees(frame.heroTilt), anchor: .bottom)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
    }

    private func groundShadow(width: CGFloat) -> some View {
        Ellipse().fill(Color.black.opacity(0.28)).frame(width: width, height: width * 0.18)
    }

    /// Oblouk mece, strely, jiskry zasahu, cislo poskozeni a K.O.
    @ViewBuilder
    private func effects(frame: StageFrame, hero: CGPoint, boss bossCenter: CGPoint, weaponOnRight: Bool) -> some View {
        if let slash = frame.slashProgress {
            SlashArc(progress: slash)
                .stroke(Color.white.opacity(0.9 * (1 - max(0, slash - 0.6) / 0.4)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: bossSize * 0.95, height: bossSize * 0.95)
                .shadow(color: boss.accent.opacity(0.8), radius: 6)
                .position(bossCenter)
        }
        if let flightValue = frame.projectile {
            let flight = CGFloat(flightValue)
            let start = CGPoint(x: hero.x + heroSize * 0.35, y: hero.y + heroSize * 0.05)
            let end = CGPoint(x: bossCenter.x - bossSize * 0.15, y: bossCenter.y)
            let point = CGPoint(x: start.x + (end.x - start.x) * flight, y: start.y + (end.y - start.y) * flight - sin(flight * .pi) * 10)
            if attack == .spell {
                ForEach(0..<3, id: \.self) { trail in
                    let back = CGFloat(trail) * 0.08
                    Circle()
                        .fill(Color(red: 0.55, green: 0.86, blue: 1.0).opacity(0.7 - Double(trail) * 0.22))
                        .frame(width: 16 - CGFloat(trail) * 4, height: 16 - CGFloat(trail) * 4)
                        .position(x: point.x - (end.x - start.x) * back, y: point.y - (end.y - start.y) * back)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(red: 0.55, green: 0.86, blue: 1.0), radius: 8)
                    .position(point)
            } else {
                PixelArrow().frame(width: 26, height: 6).position(point)
            }
        }
        if let burst = frame.burst {
            ImpactBurst(progress: burst, color: attack == .spell ? Color(red: 0.55, green: 0.86, blue: 1.0) : .white)
                .frame(width: bossSize, height: bossSize)
                .position(x: bossCenter.x - bossSize * 0.12, y: bossCenter.y)
        }
        if let rise = frame.damageRise, let damage = frame.damage {
            Text(damage.crit ? "-\(damage.amount)!" : "-\(damage.amount)")
                .fqFont(size: damage.crit ? 28 : 22, weight: .heavy, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(damage.crit ? FQColor.cta : .white)
                .shadow(color: .black.opacity(0.85), radius: 0, x: 1, y: 2)
                .opacity(rise < 0.7 ? 1 : 1 - (rise - 0.7) / 0.3)
                .position(x: bossCenter.x + bossSize * 0.18, y: bossCenter.y - bossSize * 0.38 - 34 * CGFloat(rise))
        }
        if let knockout = frame.knockout {
            Text("K.O.!")
                .fqFont(size: 34, weight: .heavy, design: .rounded)
                .foregroundStyle(FQColor.cta)
                .shadow(color: .black.opacity(0.85), radius: 0, x: 1, y: 2)
                .scaleEffect(0.6 + 0.4 * min(1, knockout * 3))
                .opacity(min(1, knockout * 4))
                .position(x: bossCenter.x, y: bossCenter.y - bossSize * 0.25 - 16 * CGFloat(knockout))
        }
    }

    /// Je zbran v prave ruce (blize k bossovi)?
    private static func isOnRight(_ layers: [AvatarLayer]) -> Bool {
        layers.contains { layer in
            layer.rows.contains { row in row.enumerated().contains { $0.offset >= 8 && $0.element == "#" } }
        }
    }
}

// MARK: - Udalosti a vypocet snimku

private struct StageEvent: Equatable {
    enum Kind: Equatable {
        case attack(index: Int)
        case finalBlow
        case escape
    }

    let id: Int
    let kind: Kind
    let start: Date

    var duration: Double {
        switch kind {
        case .attack: 1.5
        case .finalBlow: BattleStage.finaleSeconds
        case .escape: 1.6
        }
    }

    func impactTime(for attack: HeroAttack) -> Double? {
        switch kind {
        case .attack, .finalBlow: attack.impact
        case .escape: nil
        }
    }

    /// Poskozeni ~10 HP za sekundu bitvy, s malym rozptylem; kazdy 7. utok je kriticky (dvojnasobek).
    var damage: (amount: Int, crit: Bool)? {
        guard case let .attack(index) = kind else { return nil }
        let base = BattleStage.attackInterval * 10
        let spread = [-6, 3, -2, 7, 0, -4, 5][index % 7]
        let crit = index % 7 == 6
        return ((base + spread) * (crit ? 2 : 1), crit)
    }
}

/// Jeden snimek sceny: posuny, natoceni a efekty spocitane z casu od zacatku udalosti.
private struct StageFrame {
    var heroOffset: CGSize = .zero
    var heroTilt: Double = 0
    var weaponAngle: Double = 0
    /// Posun leve zbrane dolu (zlomek velikosti hrdiny) pri sklopeni.
    var weaponDrop: CGFloat = 0
    var bossOffset: CGSize = .zero
    var bossTilt: Double = 0
    var bossOpacity: Double = 1
    var bossFlash = false
    var bossFacingAway = false
    var slashProgress: Double?
    var projectile: Double?
    var burst: Double?
    var damageRise: Double?
    var damage: (amount: Int, crit: Bool)?
    var knockout: Double?

    static func make(event: StageEvent?, attack: HeroAttack, phase: BattleStage.Phase, date: Date,
                     size: CGSize, heroSize: CGFloat, bossSize: CGFloat, animates: Bool) -> StageFrame {
        var frame = StageFrame()
        // Konecny stav po vyhre / uteku (i bez animace): boss pryc, pri uteku sklopena zbran.
        switch phase {
        case .won: frame.bossOpacity = 0
        case .escaped:
            frame.bossOpacity = 0
            frame.weaponAngle = 125
            frame.weaponDrop = 0.16
            frame.heroTilt = -4
            frame.heroOffset.height = 2
        default: break
        }
        guard animates else { return frame }
        // Klidove presapnuti o pixel dvakrat za sekundu (hrdina a boss maji vlastni dychani).
        if event == nil, phase == .fighting || phase == .waiting {
            let beat = Int(date.timeIntervalSinceReferenceDate * 2) % 2
            frame.heroOffset.height = beat == 0 ? 0 : -heroSize / 16
        }
        guard let event else { return frame }
        let t = date.timeIntervalSince(event.start)
        let lunge = Double(max(0, size.width * 0.46 - heroSize * 0.5 - bossSize * 0.28))

        switch event.kind {
        case .attack, .finalBlow:
            let final = event.kind == .finalBlow
            frame.bossOpacity = 1
            frame.apply(attack: attack, t: t, lunge: lunge, power: final ? 1.3 : 1)
            let impact = attack.impact
            let hits = attack == .stab ? [impact, impact + 0.3] : [impact]
            for hit in hits where t >= hit {
                let q = (t - hit) / 0.3
                if t - hit < 0.1 { frame.bossFlash = true }
                if q < 1 {
                    let amplitude = final ? 9.0 : 6.0
                    frame.bossOffset.width = CGFloat(sin(q * .pi * 6) * amplitude * (1 - q))
                }
            }
            if t >= impact {
                frame.burst = clamp((t - impact) / 0.35)
                if frame.burst == 1 { frame.burst = nil }
            }
            if final {
                // Boss se po zasahu skacenim prevrati a zmizi, nad nim K.O., hrdina vyskoci radosti.
                let fall = clamp((t - impact - 0.25) / 0.6)
                frame.bossTilt = 80 * easeIn(fall)
                frame.bossOffset.height = 10 * fall
                frame.bossOpacity = 1 - clamp((t - impact - 0.55) / 0.5)
                if t >= impact + 0.1 { frame.knockout = clamp((t - impact - 0.1) / 1.2) }
                let jump = clamp((t - impact - 0.75) / 0.4)
                if jump > 0, jump < 1 { frame.heroOffset.height -= CGFloat(14 * sin(jump * .pi)) }
            } else if t >= impact {
                frame.damage = event.damage
                frame.damageRise = clamp((t - impact) / 1.0)
                if frame.damageRise == 1 { frame.damageRise = nil }
            }

        case .escape:
            // Hrdina sklopi zbran a sesune se; boss se otoci a odbehne doprava.
            let lower = easeOut(clamp(t / 0.4))
            frame.weaponAngle = 125 * lower
            frame.weaponDrop = 0.16 * lower
            frame.heroTilt = -4 * lower
            frame.heroOffset.height = 2 * lower
            frame.bossFacingAway = t >= 0.45
            let run = clamp((t - 0.5) / 0.9)
            frame.bossOffset.width = CGFloat(easeIn(run)) * size.width * 0.6
            frame.bossOffset.height = run > 0 ? CGFloat(-abs(sin(t * .pi * 7)) * 6) : 0
            frame.bossOpacity = 1 - clamp((t - 1.1) / 0.35)
        }
        return frame
    }

    /// Pohyb hrdiny a zbrane podle druhu utoku.
    private mutating func apply(attack: HeroAttack, t: Double, lunge: Double, power: Double) {
        switch attack {
        case .slash:
            // Napřah dozadu, vypad k bossovi se svihem, navrat.
            let windup = easeOut(clamp(t / 0.15))
            let strike = easeOut(clamp((t - 0.15) / 0.13))
            let back = easeInOut(clamp((t - 0.38) / 0.3))
            heroOffset.width = CGFloat((-6 * windup + (6 + lunge) * strike) * (1 - back))
            weaponAngle = (-40 * windup + (150 + 30 * (power - 1)) * strike) * (1 - back)
            if t >= 0.18, t < 0.6 { slashProgress = clamp((t - 0.18) / 0.3) }
        case .stab:
            // Dve rychla bodnuti: dyka miri na bosse.
            for start in [0.06, 0.36] {
                let q = clamp((t - start) / 0.3)
                if q > 0, q < 1 {
                    heroOffset.width = CGFloat(lunge * 0.85 * sin(q * .pi))
                    weaponAngle = 90 * sin(q * .pi)
                }
            }
        case .bash:
            // Vypad se stitem a mirnym naklonem.
            let q = clamp((t - 0.08) / 0.45)
            let push = sin(q * .pi)
            heroOffset.width = CGFloat((lunge + 4) * push * power)
            heroTilt = 8 * push
        case .spell:
            // Hrdina povyskoci, zvedne zbran a vysle kouli.
            let hop = clamp(t / 0.36)
            heroOffset.height = -10 * sin(hop * .pi)
            weaponAngle = 25 * sin(hop * .pi)
            if t >= 0.2, t < HeroAttack.spell.impact { projectile = easeIn(clamp((t - 0.2) / (HeroAttack.spell.impact - 0.2))) }
        case .arrow:
            // Kratke prikrceni a vystrel sipu.
            let q = clamp(t / 0.3)
            heroOffset.width = -5 * sin(q * .pi)
            if t >= 0.2, t < HeroAttack.arrow.impact { projectile = clamp((t - 0.2) / (HeroAttack.arrow.impact - 0.2)) }
        }
    }
}

private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
private func easeOut(_ q: Double) -> Double { 1 - (1 - q) * (1 - q) }
private func easeIn(_ q: Double) -> Double { q * q }
private func easeInOut(_ q: Double) -> Double { q < 0.5 ? 2 * q * q : 1 - pow(-2 * q + 2, 2) / 2 }

// MARK: - Efekty

/// Oblouk svihu mece pres bosse (zleva nahore doprava dolu), kresli se postupne.
private struct SlashArc: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let end = -70 + 140 * min(1, progress * 1.6)
        let start = -70 + 140 * max(0, (progress - 0.45) / 0.55)
        guard end > start else { return path }
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                    startAngle: .degrees(start - 45), endAngle: .degrees(end - 45), clockwise: false)
        return path
    }
}

/// Jiskry zasahu: osm pixelovych ctverecku odletajicich od mista zasahu.
private struct ImpactBurst: View {
    let progress: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let distance = CGFloat(10 + 34 * progress)
            let side = CGFloat(7 * (1 - progress * 0.5))
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let rect = CGRect(x: center.x + cos(angle) * distance - side / 2, y: center.y + sin(angle) * distance - side / 2, width: side, height: side)
                context.fill(Path(rect), with: .color(color.opacity(1 - progress)))
            }
        }
    }
}

/// Pixelovy sip letici doprava.
private struct PixelArrow: View {
    var body: some View {
        Canvas { context, size in
            let cell = size.height / 3
            let wood = Color(red: 0.58, green: 0.38, blue: 0.20)
            context.fill(Path(CGRect(x: cell * 2, y: cell, width: size.width - cell * 4, height: cell)), with: .color(wood))
            context.fill(Path(CGRect(x: size.width - cell * 2, y: 0, width: cell * 2, height: cell * 3)), with: .color(Color(red: 0.88, green: 0.92, blue: 0.98)))
            context.fill(Path(CGRect(x: 0, y: 0, width: cell * 2, height: cell)), with: .color(.white))
            context.fill(Path(CGRect(x: 0, y: cell * 2, width: cell * 2, height: cell)), with: .color(.white))
        }
    }
}
