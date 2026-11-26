import XCTest
import SwiftUI
import UIKit
@testable import FocusQuest

/// S1/M2–M5: sloty vybavy, zbrane trid a zmena tridy jen za Class Potion.
/// Try-on vsech kombinaci slotu pro vsechny 4 tridy: nic se neprekryva (model i vykresleny snimek).
@MainActor
final class EquipmentSlotTests: XCTestCase {
    private struct Cell: Hashable { let x: Int; let y: Int }

    private func cells(_ layers: [AvatarLayer]) -> Set<Cell> {
        var result = Set<Cell>()
        for layer in layers {
            for (y, row) in layer.rows.enumerated() {
                for (x, cell) in row.enumerated() where cell == "#" { result.insert(Cell(x: x, y: y)) }
            }
        }
        return result
    }

    /// Volby kazdeho slotu (nil = prazdny); Main hand jen zbrane dane tridy.
    private func options(_ slot: EquipmentSlot, _ heroClass: HeroClass) -> [EquipmentItem?] {
        let items = EquipmentItem.catalog.filter { $0.slot == slot && $0.fits(heroClass) }
        let optional = items.map { Optional($0) }
        return slot == .mainHand ? optional : [nil] + optional
    }

    /// Vsechny kombinace slotu pro tridu.
    private func combinations(_ heroClass: HeroClass) -> [[EquipmentItem]] {
        EquipmentSlot.allCases.reduce([[EquipmentItem]()]) { partial, slot in
            partial.flatMap { combo in options(slot, heroClass).map { item in item.map { combo + [$0] } ?? combo } }
        }
    }

    private func look(_ items: [EquipmentItem]) -> AvatarAppearance {
        var look = AvatarAppearance()
        for item in items { look.equip(item.isClassDefault ? nil : item.id, in: item.slot) }
        return look
    }

    // MARK: - M2: sloty

    func testEveryItemHasASlotAndTheGadgetsSitWhereTheSpecSays() {
        XCTAssertEqual(EquipmentItem.item(withID: "pocket-calculator")?.slot, .offHand)
        XCTAssertEqual(EquipmentItem.item(withID: "focus-headphones")?.slot, .neck)
        XCTAssertEqual(EquipmentItem.item(withID: "jetpack")?.slot, .back)
        for hat in ["viking-helmet", "wizard-hat", "royal-crown"] { XCTAssertEqual(EquipmentItem.item(withID: hat)?.slot, .head) }
        // Sluchatka kolem krku (radky 6-7), ne na hlave.
        let phones = cells(EquipmentItem.item(withID: "focus-headphones")!.layers)
        XCTAssertTrue(phones.allSatisfy { (6...7).contains($0.y) }, "Headphones sit around the neck")
        // Gadget v leve ruce (sloupce 0-3), zbrane v prave (12-15).
        XCTAssertTrue(cells(EquipmentItem.item(withID: "pocket-calculator")!.layers).allSatisfy { $0.x <= 3 })
        for weapon in EquipmentItem.catalog where weapon.slot == .mainHand {
            XCTAssertTrue(cells(weapon.layers).allSatisfy { $0.x >= 12 }, "\(weapon.name) is in the right hand")
        }
    }

    /// Kazda kombinace slotu x 4 tridy: viditelne pixely veci z ruznych slotu a doplnku tridy se neprekryvaji
    /// (u veci za telem se pocita jen to, co z ni kouka zpoza tela) a kazda nasazena vec je opravdu nakreslena.
    func testNoSlotCombinationOverlapsForAnyClass() {
        for heroClass in HeroClass.allCases {
            let body = cells(AvatarSprite.bodyLayers(for: AvatarAppearance(), heroClass: heroClass))
            let marks = AvatarSprite.classMarks(heroClass)
            let accessory = cells(marks.filter { !$0.behindBody }.map(\.layer)).union(cells(marks.filter(\.behindBody).map(\.layer)).subtracting(body))
            let combos = combinations(heroClass)
            XCTAssertGreaterThan(combos.count, 100, "\(heroClass)")
            for combo in combos {
                let label = "\(heroClass): " + combo.map(\.name).joined(separator: " + ")
                var groups: [(String, Set<Cell>)] = [("class accessory", accessory)]
                for item in combo {
                    let footprint = cells(item.layers)
                    groups.append((item.name, item.drawsBehindBody ? footprint.subtracting(body) : footprint))
                }
                for i in groups.indices {
                    XCTAssertFalse(groups[i].1.isEmpty, "\(label): \(groups[i].0) is invisible")
                    for j in groups.indices where j > i {
                        let shared = groups[i].1.intersection(groups[j].1)
                        XCTAssertTrue(shared.isEmpty, "\(label): \(groups[i].0) overlaps \(groups[j].0) at \(shared.map { "\($0.x),\($0.y)" })")
                    }
                }
                let ids = Set(AvatarSprite.layers(for: look(combo), heroClass: heroClass).map(\.id))
                for item in combo {
                    XCTAssertTrue(item.layers.allSatisfy { ids.contains($0.id) }, "\(label): \(item.name) is not drawn")
                }
            }
        }
    }

    /// Snapshot: hrdina s plnou vybavou (kazda zbran tridy) se vykresli a kazdy pixel kazde veci ma na snimku
    /// barvu teto veci (nic ji nezakryva). Try-on z obchodu nahradi jen vec ve stejnem slotu.
    func testTryOnSnapshotShowsEverySlotUncovered() throws {
        let size: CGFloat = 160
        let cell = Int(size) / AvatarSprite.gridSize
        let heads = EquipmentItem.catalog.filter { $0.slot == .head }
        let boots = EquipmentItem.catalog.filter { $0.slot == .feet }
        for heroClass in HeroClass.allCases {
            for (index, weapon) in EquipmentItem.weapons(for: heroClass).enumerated() {
                let kit = [heads[index % heads.count], weapon, EquipmentItem.item(withID: "pocket-calculator")!,
                           EquipmentItem.item(withID: "focus-headphones")!, boots[index % boots.count], EquipmentItem.item(withID: "jetpack")!]
                let label = "\(heroClass) " + kit.map(\.name).joined(separator: " + ")
                let appearance = look(kit)
                let layers = AvatarSprite.layers(for: appearance, heroClass: heroClass)
                let renderer = ImageRenderer(content: HeroAvatarView(appearance: appearance, heroClass: heroClass, size: size, outlined: true))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.cgImage, label)
                XCTAssertEqual(image.width, Int(size))
                let bitmap = Bitmap(image)
                let body = cells(AvatarSprite.bodyLayers(for: appearance, heroClass: heroClass))
                for item in kit {
                    for layer in item.layers {
                        for spot in cells([layer]) where !(item.drawsBehindBody && body.contains(spot)) {
                            // Nejvyssi vrstva v tomto pixelu musi byt vrstva teto veci.
                            let top = layers.last { Array($0.rows[spot.y])[spot.x] == "#" }
                            XCTAssertTrue(top?.id.hasPrefix(item.id + "-") == true, "\(label): \(item.name) covered by \(top?.id ?? "-") at \(spot.x),\(spot.y)")
                            guard let top else { continue }
                            let color = bitmap.color(x: spot.x * cell + cell / 2, y: spot.y * cell + cell / 2)
                            XCTAssertEqual(color.red, top.rgb.red, accuracy: 0.03, "\(label): \(top.id) at \(spot.x),\(spot.y)")
                            XCTAssertEqual(color.green, top.rgb.green, accuracy: 0.03, "\(label): \(top.id) at \(spot.x),\(spot.y)")
                            XCTAssertEqual(color.blue, top.rgb.blue, accuracy: 0.03, "\(label): \(top.id) at \(spot.x),\(spot.y)")
                        }
                    }
                }
                // Try-on jine helmy zmeni jen Head.
                let other = heads[(index + 1) % heads.count]
                let tried = ShopView.tryingOn(other, over: appearance, heroClass: heroClass)
                XCTAssertEqual(tried.equippedItemID(in: .head), other.id)
                for slot in EquipmentSlot.allCases where slot != .head {
                    XCTAssertEqual(tried.equippedItemID(in: slot), appearance.equippedItemID(in: slot), "\(label): try-on changed \(slot)")
                }
            }
        }
    }

    /// S1/M1: obrys hrdiny lezi jen vedle hrdiny (zadny pixel obrysu neni pres hrdinu) a obkresli ho kolem dokola.
    func testOutlineRingsTheSprite() {
        let layers = AvatarSprite.layers(for: AvatarAppearance(), heroClass: .rogue)
        let mask = PixelOutline.mask(layers)
        let ring = PixelOutline.ring(mask)
        XCTAssertEqual(ring.count, AvatarSprite.gridSize + 2)
        XCTAssertTrue(ring.allSatisfy { $0.count == AvatarSprite.gridSize + 2 })
        for (y, row) in mask.enumerated() {
            for (x, filled) in row.enumerated() {
                let ringCell = Array(ring[y + 1])[x + 1] == "#"
                if filled { XCTAssertFalse(ringCell, "Outline over the hero at \(x),\(y)") }
                // Kazdy plny pixel na okraji ma obrys aspon z jedne strany.
                let neighbours = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                let open = neighbours.filter { n in n.1 < 0 || n.1 >= mask.count || n.0 < 0 || n.0 >= row.count || !mask[n.1][n.0] }
                if filled, !open.isEmpty {
                    XCTAssertTrue(open.contains { n in Array(ring[n.1 + 1])[n.0 + 1] == "#" }, "No outline next to \(x),\(y)")
                }
            }
        }
    }

    // MARK: - M3: zbrane trid

    func testEveryClassHasThreeWeaponsWithADefault() {
        let expected: [HeroClass: [String]] = [
            .warrior: ["Battle Axe", "Excalibur", "Flame Axe"],
            .mage: ["Oak Staff", "Magic Staff", "Crystal Staff"],
            .archer: ["Short Bow", "Elven Bow", "Golden Bow"],
            .rogue: ["Dagger", "Twin Knives", "Shadow Blade"]
        ]
        let defaults: [HeroClass: String] = [.warrior: "Battle Axe", .mage: "Oak Staff", .archer: "Short Bow", .rogue: "Dagger"]
        for heroClass in HeroClass.allCases {
            let weapons = EquipmentItem.weapons(for: heroClass)
            XCTAssertGreaterThanOrEqual(weapons.count, 3, "\(heroClass)")
            XCTAssertTrue(Set(expected[heroClass]!).isSubset(of: Set(weapons.map(\.name))), "\(heroClass)")
            XCTAssertEqual(weapons.filter(\.isClassDefault).map(\.name), [defaults[heroClass]!])
            XCTAssertEqual(EquipmentItem.defaultWeapon(for: heroClass).price, 0)
            for weapon in weapons where !weapon.isClassDefault {
                XCTAssertTrue((60...600).contains(weapon.price), "\(weapon.name) price \(weapon.price)")
            }
            // Bez zbrane z obchodu drzi hrdina vychozi zbran.
            XCTAssertEqual(AvatarSprite.equippedItem(in: .mainHand, appearance: AvatarAppearance(), heroClass: heroClass)?.name, defaults[heroClass])
        }
        XCTAssertTrue(EquipmentItem.catalog.filter { $0.slot == .mainHand }.allSatisfy { $0.heroClass != nil }, "Every weapon belongs to a class")
    }

    func testWeaponsShelfShowsOwnClassFirst() {
        for heroClass in HeroClass.allCases {
            let rows = ShopView.shelfRows(.weapons, heroClass: heroClass)
            XCTAssertEqual(rows.count, HeroClass.allCases.count)
            XCTAssertTrue(rows[0].allSatisfy { $0.heroClass == heroClass }, "\(heroClass)")
            XCTAssertEqual(Set(rows.flatMap { $0 }.map(\.id)), Set(EquipmentItem.catalog.filter { $0.slot == .mainHand }.map(\.id)))
        }
        XCTAssertEqual(ShopView.shelfRows(.gadgets, heroClass: .mage).flatMap { $0 }.map(\.slot), [.neck, .offHand, .back])
    }

    func testClassAccessoryIsAlwaysWorn() {
        let accessories: [HeroClass: String] = [.warrior: "class-pauldron", .mage: "class-cape", .archer: "class-quiver", .rogue: "class-scarf"]
        for heroClass in HeroClass.allCases {
            for combo in combinations(heroClass) {
                let ids = AvatarSprite.layers(for: look(combo), heroClass: heroClass).map(\.id)
                XCTAssertTrue(ids.contains(accessories[heroClass]!), "\(heroClass): accessory missing")
            }
        }
    }

    // MARK: - M2, M4, M5: obchod a zmena tridy

    private func makeModel(coins: Int, heroClass: HeroClass = .warrior) -> ProfileViewModel {
        var profile = UserProfile.fresh(deviceID: "test")
        profile.coins = coins
        profile.heroClass = heroClass
        profile.hasCreatedHero = true
        let suite = "fq.test.slots.\(UUID().uuidString)"
        return ProfileViewModel(profile: profile, sync: LocalProfileSyncService(suiteName: suite))
    }

    func testEquipReplacesOnlyTheSameSlotAndUnequipRestoresDefaults() {
        let model = makeModel(coins: 2_000)
        let calculator = EquipmentItem.item(withID: "pocket-calculator")!
        let axe = EquipmentItem.item(withID: "flame-axe")!
        let phones = EquipmentItem.item(withID: "focus-headphones")!
        model.buy(calculator)
        model.buy(axe)
        model.buy(phones)
        XCTAssertTrue(model.isEquipped(calculator))
        XCTAssertTrue(model.isEquipped(axe), "Calculator in the off hand and an axe in the main hand together")
        XCTAssertTrue(model.isEquipped(phones))
        model.unequip(axe)
        XCTAssertEqual(model.equippedItem(in: .mainHand)?.id, "battle-axe", "Main hand goes back to the class weapon")
        XCTAssertTrue(model.isEquipped(calculator))
        model.unequip(calculator)
        XCTAssertNil(model.equippedItem(in: .offHand))
        XCTAssertTrue(model.isEquipped(phones))
        // Vychozi zbran nejde sundat.
        model.unequip(EquipmentItem.defaultWeapon(for: .warrior))
        XCTAssertEqual(model.equippedItem(in: .mainHand)?.id, "battle-axe")
    }

    func testOtherClassWeaponsCannotBeBoughtOrEquipped() {
        let model = makeModel(coins: 2_000)
        let staff = EquipmentItem.item(withID: "crystal-staff")!
        XCTAssertFalse(model.canUse(staff))
        model.buy(staff)
        XCTAssertFalse(model.owns(staff))
        XCTAssertEqual(model.profile.coins, 2_000)
        model.equip(EquipmentItem.defaultWeapon(for: .mage))
        XCTAssertEqual(model.equippedItem(in: .mainHand)?.id, "battle-axe")
    }

    func testPanelCaptionNamesSlotAndReplacement() {
        let calculator = EquipmentItem.item(withID: "pocket-calculator")!
        let axe = EquipmentItem.item(withID: "flame-axe")!
        XCTAssertEqual(ShopView.slotCaption(calculator, replacing: nil), "Off hand")
        XCTAssertEqual(ShopView.slotCaption(axe, replacing: EquipmentItem.defaultWeapon(for: .warrior)), "Main hand · replaces Battle Axe")
        let model = makeModel(coins: 0)
        XCTAssertEqual(model.replacedItem(by: axe)?.name, "Battle Axe")
        XCTAssertNil(model.replacedItem(by: calculator))
        XCTAssertNil(model.replacedItem(by: EquipmentItem.defaultWeapon(for: .warrior)), "Already equipped")
    }

    /// Trida jde po onboardingu zmenit jen za Class Potion (500 minci, nejvys 1); zruseni ho nespotrebuje.
    func testClassChangesOnlyWithAPotion() {
        let model = makeModel(coins: 1_400)
        let excalibur = EquipmentItem.item(withID: "excalibur")!
        model.buy(excalibur)
        XCTAssertEqual(model.profile.coins, 1_000)

        XCTAssertFalse(model.changeClass(to: .mage, usingPotion: true), "No potion, no class change")
        XCTAssertEqual(model.profile.heroClass, .warrior)

        model.buyClassPotion()
        XCTAssertEqual(model.profile.classPotions, 1)
        XCTAssertEqual(model.profile.coins, 500)
        model.buyClassPotion()
        XCTAssertEqual(model.profile.classPotions, 1, "Max 1 held")
        XCTAssertEqual(model.profile.coins, 500)

        // Zruseni listu = zadne volani changeClass; vyber stejne tridy nic nespotrebuje.
        XCTAssertFalse(model.changeClass(to: .warrior, usingPotion: true))
        XCTAssertEqual(model.profile.classPotions, 1)

        XCTAssertTrue(model.changeClass(to: .mage, usingPotion: true))
        XCTAssertEqual(model.profile.heroClass, .mage)
        XCTAssertEqual(model.profile.classPotions, 0, "The potion is used up")
        XCTAssertEqual(model.equippedItem(in: .mainHand)?.id, "oak-staff", "Main hand = default weapon of the new class")
        XCTAssertTrue(model.owns(excalibur), "Old class weapons stay owned")
        XCTAssertFalse(model.canUse(excalibur))

        XCTAssertFalse(model.changeClass(to: .warrior, usingPotion: true), "Back again needs another potion")
        model.buyClassPotion()
        XCTAssertTrue(model.changeClass(to: .warrior, usingPotion: true))
        model.equip(excalibur)
        XCTAssertTrue(model.isEquipped(excalibur), "Old weapons can be equipped again")
        XCTAssertEqual(model.profile.coins, 0)
    }

    func testClassPotionSurvivesSaving() throws {
        var profile = UserProfile.fresh(deviceID: "test")
        profile.classPotions = 1
        let decoded = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded.classPotions, 1)
        XCTAssertEqual(UserProfile.classPotionPrice, 500)
        XCTAssertEqual(UserProfile.maxClassPotions, 1)
    }

    func testClassPotionSpriteIsARegularGrid() {
        for phase in 0..<2 {
            XCTAssertEqual(Set(ClassPotionSprite.rows(phase: phase).map(\.count)), [9])
        }
    }
}

/// RGBA pixely snimku (sRGB), radek 0 nahore.
private struct Bitmap {
    let width: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                    bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        bytes = data
    }

    func color(x: Int, y: Int) -> (red: Double, green: Double, blue: Double) {
        let index = (y * width + x) * 4
        return (Double(bytes[index]) / 255, Double(bytes[index + 1]) / 255, Double(bytes[index + 2]) / 255)
    }
}
