import SwiftUI

/// Appka, kterou si hrac v onboardingu "zablokuje". Zatim jen maketa vyberu:
/// skutecne blokovani prijde s FamilyControls, az bude placeny Apple Developer ucet.
struct BlockableApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let symbol: String
    /// Barvy znacky (0xRRGGBB) pro sklenenou pilulku; vic barev = prechod.
    let brandHex: [UInt32]
}

/// Drzi vyber rozptylujicich appek z onboardingu.
///
/// Odchod z appky behem bitvy se uz netresta: hodiny bitvy bezi dal i na pozadi
/// a jediny trest je vedomy ustup ("Retreat Anyway") v bitve.
///
/// Pozdeji: sem pribude FamilyControls / ManagedSettings (vyzaduje placeny ucet a entitlement).
/// Zbytek appky mluvi jen s timhle manazerem, takze se nic jineho menit nebude.
@MainActor
final class AppBlockerManager: ObservableObject {
    private static let selectionKey = "focusquest.blocked-apps"

    // ID instagramu, TikToku a YouTube zustavaji stejna, aby drivejsi vyber platil dal.
    static let catalog: [BlockableApp] = [
        BlockableApp(id: "social-photos", name: "Instagram", symbol: "camera.fill", brandHex: [0xFEDA75, 0xD62976, 0x962FBF, 0x4F5BD5]),
        BlockableApp(id: "facebook", name: "Facebook", symbol: "person.2.fill", brandHex: [0x1877F2]),
        BlockableApp(id: "linkedin", name: "LinkedIn", symbol: "briefcase.fill", brandHex: [0x0A66C2]),
        BlockableApp(id: "short-video", name: "TikTok", symbol: "music.note", brandHex: [0x25F4EE, 0xFE2C55]),
        BlockableApp(id: "video", name: "YouTube", symbol: "play.rectangle.fill", brandHex: [0xFF0000])
    ]

    @Published private(set) var selectedAppIDs: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Appky, ktere uz v nabidce nejsou, se z drivejsiho vyberu tise vypusti.
        let known = Set(Self.catalog.map(\.id))
        selectedAppIDs = Set(defaults.stringArray(forKey: Self.selectionKey) ?? []).intersection(known)
    }

    var selectedApps: [BlockableApp] { Self.catalog.filter { selectedAppIDs.contains($0.id) } }

    func isSelected(_ app: BlockableApp) -> Bool { selectedAppIDs.contains(app.id) }

    func toggle(_ app: BlockableApp) {
        if selectedAppIDs.contains(app.id) { selectedAppIDs.remove(app.id) } else { selectedAppIDs.insert(app.id) }
        defaults.set(selectedAppIDs.sorted(), forKey: Self.selectionKey)
    }

    /// Reset progress: vyber appek se smaze.
    func reset() {
        selectedAppIDs = []
        defaults.removeObject(forKey: Self.selectionKey)
    }
}
