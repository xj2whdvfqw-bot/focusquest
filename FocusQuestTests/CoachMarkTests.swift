import XCTest
import SwiftUI
import UIKit
@testable import FocusQuest

/// L1, M1: tutorial projde vsech 14 kroku jen pres Next a kazdy krok ukaze bublinu (s prvkem i bez nej),
/// cile hlasi ramecky v `.global` a prvky ve Fight setupu cekaji na dojety list, Skip stoji v bezpecne
/// zone ve vysce ozubeneho kola a Home se vejde nad listu zalozek bez rolovani.
@MainActor
final class CoachMarkTests: XCTestCase {
    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "focusquest.tests.coach." + name
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// iPhone 17 a iPhone SE (3. gen.): velikost displeje a bezpecna zona.
    private let phones = [
        CoachSpace(size: CGSize(width: 402, height: 874), safeTop: 62, safeBottom: 34),
        CoachSpace(size: CGSize(width: 375, height: 667), safeTop: 20, safeBottom: 0),
    ]

    /// Ramecky prvku zhruba tam, kde v appce jsou (Home, Fight setup, lista zalozek, Stats, Hero).
    private func sampleFrames(in space: CoachSpace) -> [CoachTarget: CGRect] {
        let width = space.size.width
        let tabTop = space.size.height - FQTabBarMetrics.bottom - FQTabBarMetrics.height
        let tabWidth = (width - 2 * FQTabBarMetrics.sideInset) / 5
        func tab(_ index: Int) -> CGRect {
            CGRect(x: FQTabBarMetrics.sideInset + 5 + CGFloat(index) * tabWidth, y: tabTop + 5, width: tabWidth - 10, height: 52)
        }
        let contentTop = space.safeTop + FQSpace.sm
        // Fight setup ~470 bodu vysoky: nadpis, Focusing (chipy ve 2 radcich), Sound, Start Battle.
        let sheetTop = space.size.height - 470
        let focusing = CGRect(x: 20, y: sheetTop + 78, width: width - 40, height: 106)
        let sound = CGRect(x: 20, y: focusing.maxY + 20, width: width - 40, height: 92)
        return [
            .focusing: focusing,
            .sound: sound,
            .start: CGRect(x: 20, y: sound.maxY + 24, width: width - 40, height: 72),
            .heroCard: CGRect(x: 16, y: contentTop + CoachMetrics.skipClearance + 56 + 24, width: width - 32, height: 120),
            .fight: CGRect(x: 16, y: tabTop - 24 - 44 - 12 - 52, width: width - 32, height: 52),
            .quick: CGRect(x: width / 2 - 110, y: tabTop - 24 - 44, width: 220, height: 44),
            .streak: CGRect(x: 16, y: contentTop + CoachMetrics.skipClearance + 56 + 16, width: 130, height: 64),
            .tabPath: tab(1),
            .tabShop: tab(2),
            // P1/I6: cedule pod stankem v Shopu (pod hlavickou, striskou a hrdinou).
            .shopStall: CGRect(x: 16, y: contentTop + 44 + 8 + 33 + 136 + 15, width: width - 32, height: 66),
            .tabStats: tab(3),
            .tabHero: tab(4),
            .gear: CGRect(x: width - 60, y: contentTop, width: 44, height: 44),
            .habits: CGRect(x: 16, y: contentTop + CoachMetrics.skipClearance + 56 + 24 + 28, width: width - 32, height: 210),
            .statNumbers: CGRect(x: 16, y: contentTop + CoachMetrics.skipClearance + 56 + 24 + 28 + 210 + 24, width: width - 32, height: 170),
            .dailyTarget: CGRect(x: 16, y: contentTop + CoachMetrics.skipClearance + 56 + 24 + 120 + 24 + 28, width: width - 32, height: 150),
        ]
    }

    private func assertBubbleOnScreen(_ layout: CoachLayout, in space: CoachSpace, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(layout.bubble.width, 200, "\(label): bubble too narrow", file: file, line: line)
        XCTAssertGreaterThanOrEqual(layout.bubble.minY, space.bubbleTop - 0.5, "\(label): bubble under Skip", file: file, line: line)
        XCTAssertLessThanOrEqual(layout.bubble.maxY, space.bubbleBottom + 0.5, "\(label): bubble off the bottom", file: file, line: line)
        XCTAssertGreaterThanOrEqual(layout.bubble.minX, FQSpace.lg - 0.5, "\(label): bubble off the left edge", file: file, line: line)
        XCTAssertLessThanOrEqual(layout.bubble.maxX, space.size.width - FQSpace.lg + 0.5, "\(label): bubble off the right edge", file: file, line: line)
    }

    /// E1, M1: 14 kroku jen pres Next. Kazdy krok ma bublinu u prvku (prvek nalezen) i uprostred (prvek
    /// chybi), nic se nepreskoci a po Finish tutorial skonci.
    func testNextWalksAllFourteenStepsAndEveryStepShowsABubble() {
        let store = CoachMarkStore(defaults: freshDefaults())
        store.finishOnboarding()
        store.startTutorial()
        var visited: [CoachStep] = []
        while let step = store.step, visited.count < 20 {
            visited.append(step)
            for space in phones {
                let label = "\(step) on \(Int(space.size.height))"
                let height = CoachMetrics.bubbleEstimate
                let frame = try? XCTUnwrap(sampleFrames(in: space)[step.target], "\(label): no sample frame")
                if let frame {
                    let anchored = CoachLayout.anchored(to: frame, target: step.target, bubbleHeight: height, in: space)
                    XCTAssertTrue(anchored.hasHole, "\(label): spotlight missing")
                    XCTAssertFalse(anchored.isCentered)
                    XCTAssertFalse(anchored.bubble.intersects(anchored.hole), "\(label): bubble covers the spotlight")
                    assertBubbleOnScreen(anchored, in: space, label)
                }
                // Pojistka: prvek se nenasel do 1 s = bublina uprostred bez vyrezu.
                XCTAssertEqual(CoachLayout.resolve(frame: nil, elapsed: CoachMetrics.fallbackSeconds, hasLayout: true), .centered)
                let centered = CoachLayout.centered(bubbleHeight: height, in: space)
                XCTAssertTrue(centered.isCentered)
                XCTAssertFalse(centered.hasHole, "\(label): fallback must not spotlight anything")
                assertBubbleOnScreen(centered, in: space, label + " fallback")
            }
            store.next(from: step)
        }
        XCTAssertEqual(visited, CoachStep.allCases, "Next goes through every step in order, none skipped")
        XCTAssertEqual(visited.count, 14)
        XCTAssertNil(store.step, "Finish ends the tutorial")
    }

    /// M1/F1: cile hlasi ramecky v `.global`. Sonda korene je prevede do okna (v hlavnim okne posun 0,
    /// v listu i kdyby `.global` pocital od horni hrany listu). Prvek v listu se ukaze az po dojeti listu,
    /// po zavreni listu zmizi; nulovy ramecek se nebere.
    func testGlobalFramesMapToTheWindowAndPanelTargetsWaitForThePanel() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "The test host app has no window scene")
        let window = UIWindow(windowScene: scene)
        window.isHidden = false
        defer { window.isHidden = true }
        let store = CoachMarkStore(defaults: freshDefaults())
        store.finishOnboarding()
        store.startTutorial()

        // Hlavni okno: `.global` = souradnice okna.
        let home = UUID()
        let homeProbe = CoachRootProbeView(frame: window.bounds)
        window.addSubview(homeProbe)
        store.attachRoot(home, probe: homeProbe, isSheet: false)
        store.updateRoot(home, globalOrigin: .zero, isSheet: false)
        let fight = CGRect(x: 16, y: 600, width: 300, height: 52)
        store.report(UUID(), target: .fight, frame: fight, root: home)
        XCTAssertEqual(store.frames[.fight], fight)
        XCTAssertFalse(store.sheetOnScreen)
        store.report(UUID(), target: .quick, frame: .zero, root: home)
        XCTAssertNil(store.frames[.quick], "An unmeasured target is ignored")

        // Fight setup 300 bodu od horni hrany; `.global` v nem pocita od horni hrany listu.
        let sheet = UUID()
        let sheetProbe = CoachRootProbeView(frame: CGRect(x: 0, y: 300, width: window.bounds.width, height: 400))
        sheetProbe.waitsForPresentation = true
        window.addSubview(sheetProbe)
        store.attachRoot(sheet, probe: sheetProbe, isSheet: true)
        store.updateRoot(sheet, globalOrigin: .zero, isSheet: true)
        let chipsReporter = UUID()
        let chips = CGRect(x: 20, y: 80, width: 300, height: 100)
        store.report(chipsReporter, target: .focusing, frame: chips, root: sheet)
        XCTAssertTrue(store.sheetOnScreen)
        XCTAssertNil(store.frames[.focusing], "The spotlight waits until the panel has arrived")
        RunLoop.main.run(until: Date().addingTimeInterval(CoachMetrics.sheetSettleFallback + 0.3))
        store.refreshFrames()
        XCTAssertEqual(store.frames[.focusing], chips.offsetBy(dx: 0, dy: 300), "Sheet-relative .global is moved into the window")
        XCTAssertEqual(store.frames[.fight], fight)

        // `.global` uz v souradnicich okna: posun 0, ramecek stejny.
        store.updateRoot(sheet, globalOrigin: CGPoint(x: 0, y: 300), isSheet: true)
        store.report(chipsReporter, target: .focusing, frame: chips.offsetBy(dx: 0, dy: 300), root: sheet)
        XCTAssertEqual(store.frames[.focusing], chips.offsetBy(dx: 0, dy: 300), "Window-based .global stays as it is")

        // List zavreny: jeho prvky zmizi a Home se zase muze zvyraznit.
        sheetProbe.removeFromSuperview()
        store.refreshFrames()
        XCTAssertFalse(store.sheetOnScreen)
        XCTAssertNil(store.frames[.focusing])
        XCTAssertEqual(store.frames[.fight], fight)
        // Skryta zalozka (sonda mimo okno): jeji prvky se vynechaji.
        homeProbe.removeFromSuperview()
        store.refreshFrames()
        XCTAssertNil(store.frames[.fight])
    }

    /// E1: bublina je videt vzdy. Bez predchozi bubliny hned uprostred, jinak se na prvek ceka nejdeleji 1 s.
    func testMissingTargetFallsBackToCenteredBubbleWithinOneSecond() {
        let frame = CGRect(x: 20, y: 300, width: 100, height: 44)
        XCTAssertEqual(CoachLayout.resolve(frame: frame, elapsed: 0, hasLayout: false), .anchored(frame))
        XCTAssertEqual(CoachLayout.resolve(frame: nil, elapsed: 0, hasLayout: false), .centered, "Nothing on screen yet: centered at once")
        XCTAssertEqual(CoachLayout.resolve(frame: nil, elapsed: 0.4, hasLayout: true), .waiting, "Previous bubble stays with the new text")
        XCTAssertEqual(CoachLayout.resolve(frame: nil, elapsed: 0.99, hasLayout: true), .waiting)
        XCTAssertEqual(CoachLayout.resolve(frame: nil, elapsed: 1.0, hasLayout: true), .centered)
        XCTAssertEqual(CoachMetrics.fallbackSeconds, 1)
        // Prvek mimo obrazovku nebo nezmereny se nebere.
        let space = phones[0]
        XCTAssertFalse(space.isUsable(.zero))
        XCTAssertFalse(space.isUsable(CGRect(x: 20, y: 900, width: 100, height: 44)))
        XCTAssertTrue(space.isUsable(CGRect(x: 342, y: 70, width: 44, height: 44)), "The gear sits beside Skip and is usable")
    }

    /// G1: typ prechodu pro kazdy Next. Stejna obrazovka (A) = jedna spolecna animace, zmena obrazovky (B)
    /// = overlay zmizi a objevi se na stabilnim cili.
    func testEveryNextHasTheRightTransition() {
        let screenChanges: Set<CoachStep> = [.fight, .battle, .streak, .path, .shop, .statNumbers]
        for step in CoachStep.allCases.dropLast() {
            let next = CoachStep(rawValue: step.rawValue + 1)!
            let expected: CoachTransition = screenChanges.contains(step) ? .screenChange : .sameScreen
            XCTAssertEqual(step.transition(to: next), expected, "\(step.number) → \(next.number)")
        }
        // Vyslovne z G1: 1→2 a 4→5 (Fight setup), 6→7, 7→8, 8→9, 11→12 (zalozky), 12→13 a 5→6 na miste.
        XCTAssertEqual(CoachStep.fight.transition(to: .focusing), .screenChange)
        XCTAssertEqual(CoachStep.battle.transition(to: .quick), .screenChange)
        XCTAssertEqual(CoachStep.quick.transition(to: .streak), .sameScreen)
        XCTAssertEqual(CoachStep.streak.transition(to: .path), .screenChange)
        XCTAssertEqual(CoachStep.hero.transition(to: .dailyTarget), .sameScreen)
        XCTAssertEqual(CoachMetrics.hideDuration, 0.15)
        XCTAssertEqual(CoachMetrics.revealDuration, 0.2)
        XCTAssertEqual(CoachMetrics.revealScale, 0.96)
    }

    /// G1/A: overlay zna predem, kam cil po odrolovani dojede (`scrollTo(anchor: nil)` roluje jen tolik,
    /// aby byl cely videt), takze bublina a vyrez jedou rovnou tam ve stejne pruzine jako obrazovka.
    func testSameScreenTargetIsPredictedWhereScrollingLeavesIt() {
        let viewport = CGRect(x: 0, y: 62, width: 402, height: 700)
        let visible = CGRect(x: 16, y: 300, width: 370, height: 150)
        XCTAssertEqual(CoachLayout.scrolledIntoView(visible, viewport: viewport), visible, "A visible target does not move")
        let below = CGRect(x: 16, y: 700, width: 370, height: 150)
        XCTAssertEqual(CoachLayout.scrolledIntoView(below, viewport: viewport).maxY, viewport.maxY, "Scrolled up just enough")
        let above = CGRect(x: 16, y: 10, width: 370, height: 150)
        XCTAssertEqual(CoachLayout.scrolledIntoView(above, viewport: viewport).minY, viewport.minY, "Scrolled down just enough")
        XCTAssertEqual(CoachLayout.scrolledIntoView(below, viewport: .zero), below, "No scroll view: measured frame")

        let store = CoachMarkStore(defaults: freshDefaults())
        store.setFramesForTesting([.dailyTarget: below, .gear: visible], viewports: [.dailyTarget: viewport])
        XCTAssertEqual(store.settledFrame(for: .dailyTarget)?.maxY, viewport.maxY)
        XCTAssertEqual(store.settledFrame(for: .gear), visible)
        XCTAssertNil(store.settledFrame(for: .habits))
    }

    /// E2: Skip je v bezpecne zone (pod stavovym radkem) ve vysce ozubeneho kola a nadpisy pod nim uhnou.
    func testSkipSitsInTheSafeAreaBesideTheGear() {
        for space in phones {
            let skipTop = space.safeTop + CoachMetrics.skipTop
            XCTAssertGreaterThanOrEqual(skipTop, space.safeTop, "Skip must not cover the clock")
            // Ozubene kolo zalozek: horni okraj obsahu FQSpace.sm pod bezpecnou zonou, 44 bodu.
            XCTAssertEqual(skipTop, space.safeTop + FQSpace.sm)
            XCTAssertEqual(CoachMetrics.skipRowHeight, 44)
            XCTAssertEqual(space.skipRowBottom, space.safeTop + FQSpace.sm + 44)
            XCTAssertGreaterThan(space.bubbleTop, space.skipRowBottom, "Bubble never slides under Skip")
            XCTAssertGreaterThanOrEqual(CoachMetrics.skipClearance, CoachMetrics.skipRowHeight, "Titles move below Skip")
        }
    }

    /// E1 + E3: kazdy krok se opravdu ukaze s bublinou (zlute tlacitko Next/Finish), s nalezenym prvkem
    /// i bez nej. Overlay bezi ve skutecnem okne jako v appce (vcetne sledovani prvku a skla) a okno
    /// se vyfoti pres drawHierarchy. ImageRenderer bublinu nevykreslil vubec (buildy #77 a #78),
    /// ani s plnou vyplni, proto se nepouziva.
    func testEveryStepShowsABubbleInARealWindow() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "The test host app has no window scene")
        let screen = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        let insets = screen?.safeAreaInsets ?? .zero
        let store = CoachMarkStore(defaults: freshDefaults())
        store.finishOnboarding()
        store.startTutorial()
        var rendered = 0
        while let step = store.step, rendered < 40 {
            store.screen = step.screen
            for withTarget in [true, false] {
                let window = UIWindow(windowScene: scene)
                let space = CoachSpace(size: window.bounds.size, safeTop: insets.top, safeBottom: insets.bottom)
                let frames = sampleFrames(in: space)
                // M1/F1: kroky 2–4 stoji v dojetem Fight setupu.
                store.setFramesForTesting(withTarget ? frames : [:], sheetOnScreen: step.isInFightSheet)
                window.windowLevel = .alert + 1
                window.overrideUserInterfaceStyle = .dark
                window.backgroundColor = .clear
                let host = UIHostingController(rootView: CoachMarkOverlay().environment(store))
                host.view.backgroundColor = .clear
                window.rootViewController = host
                window.isHidden = false
                // Overlay se vykresli a jeho sledovani prvku probehne jako v appce.
                RunLoop.main.run(until: Date().addingTimeInterval(0.5))
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                window.isHidden = true
                window.rootViewController = nil
                let hole = withTarget ? frames[step.target]?.insetBy(dx: -40, dy: -40) : nil
                let yellow = try yellowPixels(in: image, outside: hole)
                XCTAssertGreaterThan(yellow, 400, "\(step) \(withTarget ? "with" : "without") target: no Next button visible")
                rendered += 1
                if ([.focusing, .battle, .hero].contains(step) && withTarget) || (step == .settings && !withTarget) {
                    attach(image, name: "coach-\(step)-\(withTarget ? "target" : "centered")")
                }
            }
            store.next(from: step)
        }
        XCTAssertEqual(rendered, CoachStep.total * 2)
        XCTAssertNil(store.step)
        // Diagnostika (bez kontroly): samotny obsah bubliny pres ImageRenderer.
        if let image = ImageRenderer(content: CoachBubbleContent(step: .battle) {}
            .frame(width: 340)
            .environment(\.colorScheme, .dark)).uiImage {
            attach(image, name: "coach-bubble-content-imagerenderer")
        }
    }

    /// E4: Home se vejde nad listu zalozek bez rolovani na iPhonu SE, 17 i Pro Max, i behem tutorialu
    /// (nadpis uhne pod Skip) a s kartou Focus rezimu.
    func testHomeFitsAboveTheTabBarWithoutScrolling() {
        // Vyska obrazovky Home: displej bez bezpecne zony a rezervy pod plovouci listou.
        let phones: [(name: String, height: CGFloat, top: CGFloat, bottom: CGFloat)] = [
            ("SE", 667, 20, 0), ("17", 874, 62, 34), ("Pro Max", 956, 62, 34),
        ]
        for phone in phones {
            let reserve = max(0, FQTabBarMetrics.bottom + FQTabBarMetrics.height + FQTabBarMetrics.contentGap - phone.bottom)
            let available = phone.height - phone.top - phone.bottom - reserve
            for clearance in [0, CoachMetrics.skipClearance] {
                for focusCard in [CGFloat(0), 64] {
                    let probe = ArenaLayout(available: available, top: 1, bossText: 1, actions: 1)
                    let top = (probe.compact ? 128 : 136) + clearance + focusCard
                    let actions: CGFloat = probe.compact ? 100 : 108
                    let layout = ArenaLayout(available: available, top: top, bossText: 81, actions: actions)
                    let label = "\(phone.name) clearance \(Int(clearance)) card \(Int(focusCard))"
                    XCTAssertLessThanOrEqual(layout.minimumHeight(top: top, bossText: 81, actions: actions), available + 0.5, "\(label): Home overflows")
                    XCTAssertGreaterThanOrEqual(layout.bossFrame, ArenaLayout.minBoss, label)
                    XCTAssertGreaterThanOrEqual(layout.bottomPadding - ArenaLayout.tabBarOverlap, FQSpace.md, "\(label): too close to the tab bar")
                }
            }
        }
        XCTAssertEqual(ArenaLayout.tabBarOverlap, 8)
    }

    // MARK: - Pomocne

    /// Pocet zlutych pixelu (barva tlacitka Next, FQColor.cta) mimo zadanou oblast (zare kolem vyrezu).
    private func yellowPixels(in image: UIImage, outside excluded: CGRect?) throws -> Int {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn)
        let scaleX = CGFloat(width) / image.size.width
        let scaleY = CGFloat(height) / image.size.height
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                if let excluded, excluded.contains(CGPoint(x: CGFloat(x) / scaleX, y: CGFloat(y) / scaleY)) { continue }
                let index = (y * width + x) * 4
                let r = buffer[index], g = buffer[index + 1], b = buffer[index + 2], a = buffer[index + 3]
                if a > 200, r > 220, g > 170, g < 245, b < 120 { count += 1 }
            }
        }
        return count
    }

    private func attach(_ image: UIImage, name: String) {
        guard let png = image.pngData() else { return }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name + ".png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
