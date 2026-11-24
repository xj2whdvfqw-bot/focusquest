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

    func testTutorialHasThirteenStepsInUsageOrder() {
        XCTAssertEqual(CoachStep.allCases.first, .fight)
        XCTAssertEqual(CoachStep.allCases.last?.number, CoachStep.total)
        XCTAssertEqual(CoachStep.total, 13)
        XCTAssertEqual(CoachStep.allCases.map(\.number), Array(1...13), "Every step has its own number")
        XCTAssertEqual(CoachStep.habits.screen, .stats)
        XCTAssertEqual(CoachStep.path.screen, .path, "K1: tab steps stand on their own tab")
        XCTAssertEqual(CoachStep.shop.screen, .shop)
        XCTAssertEqual(CoachStep.stats.screen, .stats)
        XCTAssertEqual(CoachStep.dailyTarget.screen, .hero)
        // L1/E1: tutorial neotvira listy. Kroky o Fight sheetu stoji na Home a ukazuji tlacitko Fight.
        for step in [CoachStep.fight, .focusing, .sound, .battle] {
            XCTAssertEqual(step.screen, .home, "\(step) must stay on Home")
            XCTAssertEqual(step.target, .fight, "\(step) highlights Fight")
        }
        XCTAssertEqual(CoachStep.quick.target, .quick, "Step 5 highlights the link itself")
        // K1/D3: vsude Next, posledni krok Finish, zadne "Got it".
        XCTAssertEqual(CoachStep.allCases.dropLast().map(\.buttonTitle), Array(repeating: "Next", count: 12))
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

    /// L1/E1: kroky o Fight sheetu uz v listu nejsou, takze se po spusteni vrati presne tam, kde hrac skoncil.
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
