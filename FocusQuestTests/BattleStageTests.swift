import XCTest
@testable import FocusQuest

/// Hrdina v bitve: druh utoku a rozdeleni sprite na telo a zbran.
@MainActor
final class BattleStageTests: XCTestCase {
    func testAttackFollowsTheEquippedWeaponFirst() {
        var look = AvatarAppearance()
        look.equip("excalibur", in: .weapon)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .mage), .slash)
        look.equip("wooden-sword", in: .weapon)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .archer), .slash)
        look.equip("magic-staff", in: .weapon)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .warrior), .spell)
    }

    func testAttackWithoutWeaponFollowsTheHeroClass() {
        let look = AvatarAppearance()
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .warrior), .slash, "O1/H3: the warrior swings an axe")
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .mage), .spell)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .archer), .arrow)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .rogue), .stab)
    }

    /// V bitve jsou presne tytez vrstvy jako v obchode a profilu, jen rozdelene na telo a zbran.
    func testBattleLayersMatchTheShopSprite() {
        var look = AvatarAppearance()
        look.equip("viking-helmet", in: .head)
        look.equip("excalibur", in: .weapon)
        for heroClass in HeroClass.allCases {
            let all = AvatarSprite.layers(for: look, heroClass: heroClass)
            let split = AvatarSprite.battleLayers(for: look, heroClass: heroClass)
            XCTAssertEqual(Set(split.body + split.weapon), Set(all), "\(heroClass)")
            XCTAssertEqual(split.body.count + split.weapon.count, all.count)
            XCTAssertEqual(Set(split.weapon.map(\.id)), Set(EquipmentItem.item(withID: "excalibur")!.layers.map(\.id)))
        }
    }

    func testClassWeaponIsSeparatedWithoutShopWeapon() {
        let split = AvatarSprite.battleLayers(for: AvatarAppearance(), heroClass: .rogue)
        XCTAssertEqual(Set(split.weapon.map(\.id)), ["class-dagger", "class-hilt"])
        XCTAssertFalse(split.body.contains { $0.id.hasPrefix("class-dagger") })
    }
}
