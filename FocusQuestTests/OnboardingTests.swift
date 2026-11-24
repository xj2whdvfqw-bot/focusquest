import XCTest
@testable import FocusQuest

/// Onboarding a tutorial (F2): jmeno hrace, poradi kroku, ulozeni a pokracovani.
@MainActor
final class OnboardingTests: XCTestCase {
    /// Ciste UserDefaults pro jeden test.
    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "focusquest.tests.onboarding." + name
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testNameAllowsDiacriticsAndSpacesButNotSymbols() {
        XCTAssertEqual(UserProfile.cleanName("  Tomáš   Novák "), "Tomáš Novák")
        XCTAssertEqual(UserProfile.cleanName("Al"), "Al")
        XCTAssertNil(UserProfile.cleanName("   "))
        XCTAssertNil(UserProfile.cleanName("<script>"))
        XCTAssertNil(UserProfile.cleanName(String(repeating: "a", count: 21)))
        XCTAssertNil(UserProfile.cleanName("--"), "Needs a letter or digit")
    }

    func testTutorialHasFourteenStepsInUsageOrder() {
        XCTAssertEqual(CoachStep.allCases.first, .fight)
        XCTAssertEqual(CoachStep.allCases.last?.number, CoachStep.total)
        XCTAssertEqual(CoachStep.total, 14)
        XCTAssertEqual(CoachStep.allCases.map(\.number), Array(1...14), "Every step has its own number")
        XCTAssertEqual(CoachStep.habits.screen, .stats)
        XCTAssertEqual(CoachStep.path.screen, .path, "K1: tab steps stand on their own tab")
        XCTAssertEqual(CoachStep.shop.screen, .shop)
        XCTAssertEqual(CoachStep.stats.screen, .stats)
        // M1/F2: Hero ve dvou krocich (karta hrdiny, Daily focus target), pak Settings.
        XCTAssertEqual(Array(CoachStep.allCases.suffix(3)), [.hero, .dailyTarget, .settings])
        XCTAssertEqual(CoachStep.hero.number, 12)
        XCTAssertEqual(CoachStep.dailyTarget.number, 13)
        XCTAssertEqual(CoachStep.settings.number, 14)
        for step in [CoachStep.hero, .dailyTarget, .settings] { XCTAssertEqual(step.screen, .hero) }
        XCTAssertEqual(CoachStep.hero.target, .heroCard)
        XCTAssertEqual(CoachStep.dailyTarget.target, .dailyTarget)
        XCTAssertEqual(CoachStep.settings.target, .gear)
        XCTAssertEqual(CoachStep.hero.title, "Your hero")
        XCTAssertEqual(CoachStep.dailyTarget.title, "Daily focus target")
        // M1/F1: krok 1 ukaze Fight na Home, kroky 2–4 stoji v otevrenem Fight setupu (nad Home).
        XCTAssertEqual(CoachStep.fight.target, .fight)
        XCTAssertEqual([CoachStep.focusing, .sound, .battle].map(\.target), [.focusing, .sound, .start])
        for step in CoachStep.allCases {
            XCTAssertEqual(step.isInFightSheet, [.focusing, .sound, .battle].contains(step), "\(step)")
        }
        for step in [CoachStep.fight, .focusing, .sound, .battle, .quick, .streak] {
            XCTAssertEqual(step.screen, .home, "\(step) stands on Home")
        }
        XCTAssertEqual(CoachStep.quick.target, .quick, "Step 5 highlights the link itself")
        // K1/D3: vsude Next, posledni krok Finish, zadne "Got it".
        XCTAssertEqual(CoachStep.allCases.dropLast().map(\.buttonTitle), Array(repeating: "Next", count: 13))
        XCTAssertEqual(CoachStep.settings.buttonTitle, "Finish")
        for step in CoachStep.allCases {
            XCTAssertFalse(step.text.contains("Tap "), "\(step) still asks to tap the highlighted element")
        }
        for step in CoachStep.allCases {
            let sentences = step.text.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            XCTAssertLessThanOrEqual(sentences.count, 2, "\(step) has more than two sentences")
        }
    }

    func testTutorialStepIsSavedAndResumed() {
        let defaults = freshDefaults()
        let store = CoachMarkStore(defaults: defaults)
        XCTAssertFalse(store.onboardingDone)
        XCTAssertNil(store.step)
        store.finishOnboarding()
        store.startTutorial()
        store.advance(from: .fight)
        store.advance(from: .fight)
        XCTAssertEqual(store.step, .focusing, "A double tap advances only once")
        store.advance(from: .focusing)
        store.advance(from: .sound)
        store.advance(from: .battle)
        store.advance(from: .quick)

        let reopened = CoachMarkStore(defaults: defaults)
        XCTAssertTrue(reopened.onboardingDone)
        XCTAssertEqual(reopened.step, .streak)
    }

    /// Krok se po spusteni vrati presne tam, kde hrac skoncil (M1/F1: v kroku 2–4 MainTabView znovu otevre Fight setup).
    func testEveryStepResumesWhereItStopped() {
        let defaults = freshDefaults()
        let store = CoachMarkStore(defaults: defaults)
        store.finishOnboarding()
        store.startTutorial()
        store.next(from: .fight)
        store.next(from: .focusing)
        XCTAssertEqual(store.step, .sound)
        XCTAssertEqual(CoachMarkStore(defaults: defaults).step, .sound)
    }

    func testSkipAndResetOnboarding() {
        let defaults = freshDefaults()
        let store = CoachMarkStore(defaults: defaults)
        store.finishOnboarding()
        store.startTutorial()
        store.skipTutorial()
        XCTAssertNil(CoachMarkStore(defaults: defaults).step)
        store.advance(from: .settings)
        XCTAssertNil(store.step)
        store.resetOnboarding()
        XCTAssertFalse(CoachMarkStore(defaults: defaults).onboardingDone)
    }

    func testLastStepFinishesTheTutorial() {
        let defaults = freshDefaults()
        let store = CoachMarkStore(defaults: defaults)
        store.finishOnboarding()
        store.startTutorial()
        for step in CoachStep.allCases { store.advance(from: step) }
        XCTAssertNil(store.step)
    }
}
