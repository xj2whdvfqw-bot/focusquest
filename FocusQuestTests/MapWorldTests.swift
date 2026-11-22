import XCTest
@testable import FocusQuest

/// Mapa Path (F1): pergamenovy okraj, organicka hranice svetu, mraky a easter eggy.
final class MapWorldTests: XCTestCase {
    func testParchmentEdgeIsTransparentOutsideAndTornAtCorners() {
        XCTAssertLessThan(MapLayout.parchmentDepth(cellX: 0, cellY: 0), 0, "Corner is torn off")
        XCTAssertLessThan(MapLayout.parchmentDepth(cellX: 0, cellY: MapLayout.rows / 2), 0, "Outer edge is outside the map")
        XCTAssertGreaterThan(MapLayout.parchmentDepth(cellX: MapLayout.columns / 2, cellY: MapLayout.rows / 2), 100)
        // Okraj je zubaty: hloubka prvniho pixelu mapy se podel okraje meni.
        let jags = Set((0..<200).map { y in (0..<20).first { MapLayout.parchmentDepth(cellX: $0, cellY: 100 + y) >= 0 } ?? -1 })
        XCTAssertGreaterThan(jags.count, 1)
    }

    func testWorldBoundaryIsNotAStraightLine() {
        // Na stejne vysce u hranice Farm/Forest lezi pixely v ruznych svetech (zadny rovny sev pres celou sirku).
        let boundaryY = MapLayout.band(of: .farm).minY
        let row = Int(boundaryY / MapLayout.cell)
        let worlds = Set(stride(from: 10, to: MapLayout.columns - 10, by: 3).map { MapLayout.worldIndex(cellX: $0, cellY: row) })
        XCTAssertEqual(worlds, [0, 1])
    }

    func testCloudsAreOpaqueAndCoverTheirWorld() {
        let clouds = MapTerrain.clouds(for: .reef)
        let band = MapLayout.band(of: .reef)
        // Stred sveta je pod mraky uplne nepruhledny.
        let x = clouds.width / 2
        let y = Int((band.midY - clouds.frame.minY) / 8)
        XCTAssertEqual(clouds.pixels[(y * clouds.width + x) * 4 + 3], 255)
        XCTAssertGreaterThan(clouds.frame.maxY, band.maxY, "Puffs reach below the world border")
    }

    func testEasterEggsLieInTheirWorlds() {
        for egg in MapEasterEgg.allCases {
            let point = egg.center
            XCTAssertTrue(CGRect(origin: .zero, size: MapLayout.size).contains(point), "\(egg) is on the map")
            let band = MapLayout.band(of: egg.world)
            XCTAssertTrue(band.insetBy(dx: 0, dy: -MapLayout.boundaryReach).contains(point), "\(egg) is in \(egg.world)")
            XCTAssertGreaterThan(MapLayout.parchmentDepth(cellX: Int(point.x / MapLayout.cell), cellY: Int(point.y / MapLayout.cell)), 4)
        }
        XCTAssertEqual(MapEasterEgg.allCases.map(\.coins), [150, 200, 100])
        XCTAssertEqual(MapEasterEgg.allCases.map(\.tapsNeeded), [3, 4, 3])
    }

    func testFoundEasterEggsSurviveARoundTrip() throws {
        var profile = UserProfile.fresh(deviceID: "t")
        profile.foundEasterEggs = [MapEasterEgg.pond.rawValue]
        let decoded = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded.foundEasterEggs, ["pond"])
    }
}
