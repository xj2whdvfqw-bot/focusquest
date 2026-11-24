import XCTest
import SwiftUI
import UIKit
@testable import FocusQuest

/// L1: tutorial projde vsech 13 kroku jen pres Next a kazdy krok ukaze bublinu (s prvkem i bez nej),
/// Skip stoji v bezpecne zone ve vysce ozubeneho kola a Home se vejde nad listu zalozek bez rolovani.
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

    /// Ramecky prvku zhruba tam, kde v appce jsou (Home, lista zalozek, Stats, Hero).
    private func sampleFrames(in space: CoachSpace) -> [CoachTarget: CGRect] {
        let width = space.size.width
        let tabTop = space.size.height - FQTabBarMetrics.bottom - FQTabBarMetrics.height
        let tabWidth = (width - 2 * FQTabBarMetrics.sideInset) / 5
        func tab(_ index: Int) -> CGRect {
            CGRect(x: FQTabBarMetrics.sideInset + 5 + CGFloat(index) * tabWidth, y: tabTop + 5, width: tabWidth - 10, height: 52)
        }
        let contentTop = space.safeTop + FQSpace.sm
        return [
            .fight: CGRect(x: 16, y: tabTop - 24 - 44 - 12 - 52, width: width - 32, height: 52),
            .quick: CGRect(x: width / 2 - 110, y: tabTop - 24 - 44, width: 220, height: 44),
            .streak: CGRect(x: 16, y: contentTop + CoachMetrics.skipClearance + 56 + 16, width: 130, height: 64),
            .tabPath: tab(1),
            .tabShop: tab(2),
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

    /// E1: 13 kroku jen pres Next. Kazdy krok ma bublinu u prvku (prvek nalezen) i uprostred (prvek
    /// chybi), nic se nepreskoci a po Finish tutorial skonci.
    func testNextWalksAllThirteenStepsAndEveryStepShowsABubble() {
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
        XCTAssertNil(store.step, "Finish ends the tutorial")
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

    /// E1 + E3: kazdy krok se opravdu vykresli s bublinou (zlute tlacitko Next/Finish), s nalezenym prvkem
    /// i bez nej. Bez spusteneho sledovani (ImageRenderer nespousti task) = prvni snimek po Next.
    func testEveryStepRendersAVisibleBubble() throws {
        let store = CoachMarkStore(defaults: freshDefaults())
        store.finishOnboarding()
        store.startTutorial()
        let space = CoachSpace(size: CGSize(width: 402, height: 874), safeTop: 0, safeBottom: 0)
        let frames = sampleFrames(in: space)
        var rendered = 0
        while let step = store.step, rendered < 40 {
            store.screen = step.screen
            for withTarget in [true, false] {
                store.setFramesForTesting(withTarget ? frames : [:])
                // ImageRenderer neumi materialy: bublina se sklem by se nevykreslila vubec (build #77),
                // proto plna vypln stejneho tvaru. Overlay je v appce vzdy tmavy (okno .dark).
                let renderer = ImageRenderer(content: CoachMarkOverlay(plainBubbleForSnapshot: true)
                    .environment(store)
                    .environment(\.colorScheme, .dark)
                    .frame(width: space.size.width, height: space.size.height))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage, "\(step): nothing rendered")
                let hole = withTarget ? frames[step.target]?.insetBy(dx: -40, dy: -40) : nil
                let yellow = try yellowPixels(in: image, outside: hole)
                XCTAssertGreaterThan(yellow, 400, "\(step) \(withTarget ? "with" : "without") target: no Next button visible")
                rendered += 1
                if (step == .battle && withTarget) || (step == .settings && !withTarget) {
                    attach(image, name: "coach-\(step)-\(withTarget ? "target" : "centered")")
                }
            }
            store.next(from: step)
        }
        XCTAssertEqual(rendered, CoachStep.total * 2)
        XCTAssertNil(store.step)
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
