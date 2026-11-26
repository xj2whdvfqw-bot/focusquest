import XCTest
import SwiftUI
import UIKit
@testable import FocusQuest

/// P1/I: obchod jako kupecky stanek. Pixelove sprity maji pravidelne mrizky, kazda vec z obchodu ma
/// sprite na polici, stena s obrazy ma vsechna pozadi a krok tutorialu o Shopu miri na cedule.
/// Stanek se vykresli ve skutecnem okne na iPhone SE i Pro Max.
@MainActor
final class ShopStallTests: XCTestCase {
    func testEveryShopItemHasAShelfSprite() {
        for item in EquipmentItem.catalog {
            let crop = ItemSprite.crop(item.layers)
            XCTAssertFalse(crop.layers.isEmpty, "\(item.name) has no pixels")
            XCTAssertGreaterThan(crop.width, 0)
            XCTAssertGreaterThan(crop.height, 0)
            for layer in crop.layers {
                XCTAssertEqual(layer.rows.count, crop.height, "\(layer.id)")
                XCTAssertTrue(layer.rows.allSatisfy { $0.count == crop.width }, "\(layer.id)")
            }
            XCTAssertTrue(crop.layers.contains { $0.rows.first?.contains("#") == true }, "\(item.name): top row is cropped tight")
        }
    }

    func testPixelSpritesAreRegularGrids() {
        for phase in 0..<4 {
            let rows = HourglassSprite.rows(phase: phase)
            XCTAssertEqual(Set(rows.map(\.count)), [11], "hourglass phase \(phase)")
            XCTAssertEqual(rows.count, 13)
        }
        // Pisek nahore ubyva a dole pribyva.
        func sand(_ rows: [String], _ range: ClosedRange<Int>) -> Int { range.reduce(0) { $0 + rows[$1].filter { $0 == "s" || $0 == "S" }.count } }
        XCTAssertGreaterThan(sand(HourglassSprite.rows(phase: 0), 2...5), sand(HourglassSprite.rows(phase: 3), 2...5))
        XCTAssertLessThan(sand(HourglassSprite.rows(phase: 0), 7...10), sand(HourglassSprite.rows(phase: 3), 7...10))
        for phase in 0..<3 {
            XCTAssertEqual(Set(IceCrystalSprite.rows(phase: phase).map(\.count)), [11], "crystal phase \(phase)")
        }
        for icon in [StallIcon.sword, StallIcon.picture, StallIcon.potion, StallIcon.coin, StallIcon.star] {
            XCTAssertEqual(Set(icon.map(\.count)).count, 1, "Icon rows differ in width: \(icon)")
        }
    }

    func testWallHasEveryBackgroundOnce() {
        XCTAssertEqual(ShopView.wall.count, ShopBackground.allCases.count + 1)
        XCTAssertNil(ShopView.wall.first!, "World scenes hang first")
        XCTAssertEqual(Set(ShopView.wall.compactMap { $0 }), Set(ShopBackground.allCases))
        for background in ShopView.wall {
            XCTAssertEqual(ShopView.background(forID: ShopView.backgroundID(background)), background)
        }
    }

    func testShopTutorialStepPointsAtTheSigns() {
        XCTAssertEqual(CoachStep.shop.target, .shopStall)
        XCTAssertEqual(CoachStep.shop.screen, .shop)
        XCTAssertFalse(CoachTarget.shopStall.isInTabBar)
        XCTAssertEqual(CoachTarget.shopStall.cornerRadius, 20)
    }

    /// R1/L1–L2: hrdina je vzdy cely a stejne velky (postava ~110 bodu, misto na poskok, podstavec) a na iPhonu SE
    /// zbyde pod pultem dost mista na polici (stanek 16 bodu pod hornim radkem, cedule 12 bodu nad listou).
    func testFixedStallLeavesRoomForShelvesOnSmallPhone() {
        XCTAssertEqual(StallLayout.heroSize, 112, accuracy: 8)
        XCTAssertGreaterThanOrEqual(StallLayout.heroHeadroom, 16, "Room for the try-on hop")
        XCTAssertEqual(StallLayout.heroWindowHeight,
                       StallLayout.heroHeadroom + StallLayout.heroSize + CGFloat(StallPedestal.heightInPixels - 1) * StallMetrics.pixel)
        XCTAssertEqual(StallLayout.topGap, 16)
        XCTAssertEqual(StallLayout.signsBottomGap, 12)

        let signs = UIHostingController(rootView: HStack(alignment: .top, spacing: FQSpace.sm) {
            ForEach(ShopView.ShopSection.allCases) { section in
                HangingSign(title: section.title, icon: section, active: section == .gear, swing: 0)
            }
        })
        let signsHeight = signs.sizeThatFits(in: CGSize(width: 343, height: .infinity)).height
        XCTAssertGreaterThan(signsHeight, 40)
        // iPhone SE: displej 667, stavovy radek 20, horni radek 8 + 44, lista zalozek se svou rezervou.
        let tabBar = FQTabBarMetrics.bottom + FQTabBarMetrics.height
        let chrome = 20 + 52 + StallLayout.topGap
            + CGFloat(StallAwning.heightInPixels) * StallMetrics.pixel
            + StallLayout.heroWindowHeight + 4 * StallMetrics.pixel + 5 * StallMetrics.pixel
            + signsHeight + StallLayout.signsBottomGap + tabBar
        XCTAssertGreaterThanOrEqual(667 - chrome, 110, "Too little room for shelves under the counter on iPhone SE")
    }

    /// I6: stanek s hrdinou, ceduli a policemi se vykresli ve skutecnem okne na SE i Pro Max (bez padu,
    /// nic neni nulove velikosti) i s nejvetsim pismem. (Reduce Motion v prostredi nastavit nejde, je jen pro cteni.)
    func testStallRendersOnSmallAndLargePhones() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for size in [CGSize(width: 375, height: 667), CGSize(width: 440, height: 956)] {
            for big in [false, true] {
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                let content = VStack(spacing: 0) {
                    StallAwning()
                    HStack(spacing: 0) {
                        StallPost()
                        ZStack(alignment: .bottom) {
                            StallScene(background: .farm)
                            VStack(spacing: -StallMetrics.pixel) {
                                HeroAvatarView(appearance: AvatarAppearance(), heroClass: .archer, size: StallLayout.heroSize)
                                StallPedestal()
                            }
                        }
                        StallPost()
                    }
                    .frame(height: StallLayout.heroWindowHeight)
                    WoodPlank(thickness: 5, nails: true)
                    HStack {
                        ForEach(ShopView.ShopSection.allCases) { section in
                            HangingSign(title: section.title, icon: section, active: section == .gear, swing: 0)
                        }
                    }
                    HStack(alignment: .bottom) {
                        ForEach(EquipmentItem.catalog.filter { $0.slot == .head }) { ItemSprite(item: $0) }
                        HourglassSprite()
                        IceCrystalSprite()
                    }
                    WoodPlank()
                    HStack { PriceTag(label: .price(150)); PriceTag(label: .owned); PriceTag(label: .free) }
                }
                .environment(\.dynamicTypeSize, big ? .accessibility3 : .large)
                let host = UIHostingController(rootView: content)
                window.rootViewController = host
                window.isHidden = false
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                let fitting = host.sizeThatFits(in: CGSize(width: size.width, height: .infinity))
                XCTAssertGreaterThan(fitting.height, 200, "\(size) big: \(big)")
                XCTAssertLessThanOrEqual(fitting.width, size.width + 0.5, "Stall wider than the phone: \(size) big: \(big)")
                window.isHidden = true
            }
        }
    }
}
