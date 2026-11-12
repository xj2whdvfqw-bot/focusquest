import Foundation

enum AmbientTrack: String, Codable, CaseIterable, Sendable, Identifiable {
    case midnightRain, vinylLibrary, campfireCrackle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .midnightRain: "Midnight Rain"
        case .vinylLibrary: "Vinyl Library"
        case .campfireCrackle: "Campfire Crackle"
        }
    }
}

struct AppPreferences: Codable, Sendable {
    var isHapticsEnabled = true
    var isMusicEnabled = true
    var isSFXEnabled = true
    var ambientVolume = 0.55
    var selectedTrack: AmbientTrack = .midnightRain
}