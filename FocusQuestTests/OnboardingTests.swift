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
        XCTAssertEqual(CoachStep.hero.number, CoachStep.dailyTarget.number, "Hero tab and its daily target are one step")
        XCTAssertEqual(CoachStep.habits.screen, .stats)
        XCTAssertEqual(CoachStep.shop.screen, .path, "Tab steps wait on the previous tab")
        XCTAssertEqual(CoachStep.dailyTarget.screen, .hero)
        XCTAssertEqual(CoachStep.allCases.filter(\.isInFightSheet), [.focusing, .sound, .battle])
        XCTAssertTrue(CoachStep.fight.isAction)
        XCTAssertFalse(CoachStep.battle.isAction, "Battle is explained, not played")
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

    func testStepInsideFightSheetResumesAtFight() {
        let defaults = freshDefaults()
        let store = CoachMarkStore(defaults: defaults)
        store.finishOnboarding()
        store.startTutorial()
        store.advance(from: .fight)
        store.advance(from: .focusing)
        XCTAssertEqual(store.step, .sound)
        XCTAssertEqual(CoachMarkStore(defaults: defaults).step, .fight)
        store.leaveFightSheet()
        XCTAssertEqual(store.step, .quick)
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
