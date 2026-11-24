import XCTest
import UIKit
@testable import FocusQuest

/// K1/D5: obrazky ke sdileni se opravdu vyrenderuji (ImageRenderer), maji spravnou velikost
/// a v bezpecnem okraji (7,5 % sirky) neni zadny obsah. PNG jsou prilozene k vysledku testu.
@MainActor
final class ShareCardRenderTests: XCTestCase {
    private func snapshot(name: String?, minutes: Int, streak: Int, bosses: Int) -> ShareSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = DateComponents(calendar: calendar, year: 2026, month: 11, day: 20, hour: 12).date!
        let first = DateComponents(calendar: calendar, year: 2026, month: 11, day: 11).date!
        let history = (0..<9).map { offset in
            SessionSummary(id: UUID(), bossName: "A", verifiedMinutes: 15 + offset * 10, xpEarned: 0,
                           completedAt: calendar.date(byAdding: .day, value: -offset, to: now)!, flawless: true, subject: .math)
        }
        let grid = HabitGrid.make(history: history, firstDay: first, now: now, calendar: calendar).recentWeeks(5)
        return ShareSnapshot(name: name, hero: AvatarAppearance(), heroClass: .warrior, streak: streak, longestStreak: max(streak, 12),
                             weekMinutes: minutes, weekBosses: bosses, grid: grid)
    }

    func testShareGridHasFullFiveWeeks() {
        let grid = snapshot(name: nil, minutes: 0, streak: 0, bosses: 0).grid
        XCTAssertEqual(grid.weeks.count, 5)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
    }

    func testCardsRenderAtStorySizeAndWideSize() throws {
        let data = snapshot(name: "Adam", minutes: 245, streak: 9, bosses: 7)
        for format in ShareFormat.allCases {
            for template in ShareTemplate.allCases {
                let image = try XCTUnwrap(StatsShareRenderer.render(data, template: template, showsName: true, format: format))
                let cg = try XCTUnwrap(image.cgImage)
                let expected = format == .story ? (1080, 1920) : (1920, 1080)
                XCTAssertEqual(cg.width, expected.0, "\(format) \(template)")
                XCTAssertEqual(cg.height, expected.1, "\(format) \(template)")
                attach(image, name: "share-\(format.rawValue)-\(template.rawValue)")
            }
        }
    }

    /// Obsah (bez pozadi) se nedotkne bezpecneho okraje ani s dlouhym jmenem a velkymi cisly.
    func testContentStaysInsideSafeMargin() throws {
        let cases = [
            snapshot(name: "Adam", minutes: 245, streak: 9, bosses: 7),
            snapshot(name: "Maximilian Novakovic", minutes: 12_345, streak: 365, bosses: 120),
            snapshot(name: nil, minutes: 0, streak: 0, bosses: 0),
        ]
        for data in cases {
            for format in ShareFormat.allCases {
                for template in ShareTemplate.allCases {
                    let image = try XCTUnwrap(StatsShareRenderer.renderContentOnly(data, template: template, showsName: true, format: format))
                    let label = "\(format) \(template) \(data.name ?? "no name")"
                    let pixels = try alphaMap(image)
                    // 2 body tolerance na vyhlazeni hran.
                    let band = Int((format.margin - 2) * StatsShareRenderer.scale)
                    XCTAssertEqual(pixels.opaqueCount(inBorder: band), 0, "\(label): content touches the safe margin")
                    XCTAssertGreaterThan(pixels.opaqueCount(inBorder: 0), 1000, "\(label): nothing was rendered")
                    attach(image, name: "content-\(format.rawValue)-\(template.rawValue)")
                }
            }
        }
    }

    // MARK: - Pomocne

    private struct AlphaMap {
        let width: Int
        let height: Int
        let alpha: [UInt8]

        /// Pocet viditelnych pixelu v pasu sirky `band` u kraje; `band` 0 = cely obrazek.
        func opaqueCount(inBorder band: Int) -> Int {
            var count = 0
            for y in 0..<height {
                for x in 0..<width {
                    let inBand = band == 0 || x < band || y < band || x >= width - band || y >= height - band
                    if inBand && alpha[y * width + x] > 24 { count += 1 }
                }
            }
            return count
        }
    }

    private func alphaMap(_ image: UIImage) throws -> AlphaMap {
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
        let alpha = (0..<(width * height)).map { buffer[$0 * 4 + 3] }
        return AlphaMap(width: width, height: height, alpha: alpha)
    }

    private func attach(_ image: UIImage, name: String) {
        guard let png = image.pngData() else { return }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name + ".png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
