import XCTest
@testable import FocusQuest

/// Hrdina v bitve: druh utoku a rozdeleni sprite na telo a zbran.
@MainActor
final class BattleStageTests: XCTestCase {
    /// S1/M3: utok podle zbrane v Main hand; zbrane patri tride, takze odpovida tride zbrane.
    func testAttackFollowsTheEquippedWeapon() {
        var look = AvatarAppearance()
        look.equip("excalibur", in: .mainHand)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .warrior), .slash)
        look.equip("magic-staff", in: .mainHand)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .mage), .spell)
        look.equip("golden-bow", in: .mainHand)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .archer), .arrow)
        look.equip("twin-knives", in: .mainHand)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .rogue), .stab)
        // Zbran jine tridy (napr. po zmene tridy) se nepouzije: hrdina drzi vychozi zbran sve tridy.
        look.equip("excalibur", in: .mainHand)
        XCTAssertEqual(HeroAttack.of(appearance: look, heroClass: .mage), .spell)
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
        for heroClass in HeroClass.allCases {
            let weapon = EquipmentItem.weapons(for: heroClass).last!
            var look = AvatarAppearance()
            look.equip("viking-helmet", in: .head)
            look.equip("pocket-calculator", in: .offHand)
            look.equip(weapon.id, in: .mainHand)
            let all = AvatarSprite.layers(for: look, heroClass: heroClass)
            let split = AvatarSprite.battleLayers(for: look, heroClass: heroClass)
            XCTAssertEqual(Set(split.body + split.weapon), Set(all), "\(heroClass)")
            XCTAssertEqual(split.body.count + split.weapon.count, all.count)
            XCTAssertEqual(Set(split.weapon.map(\.id)), Set(weapon.layers.map(\.id)), "\(heroClass)")
        }
    }

    func testDefaultWeaponIsSeparatedWithoutShopWeapon() {
        let split = AvatarSprite.battleLayers(for: AvatarAppearance(), heroClass: .rogue)
        XCTAssertEqual(Set(split.weapon.map(\.id)), ["dagger-blade", "dagger-hilt"])
        XCTAssertFalse(split.body.contains { $0.id.hasPrefix("dagger-") })
    }
}
