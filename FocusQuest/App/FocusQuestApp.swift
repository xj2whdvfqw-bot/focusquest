import SwiftUI

@main
struct FocusQuestApp: App {
    @State private var container = AppDIContainer()

    init() {
        _ = RuntimeSecurityService().integrityReport()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
        }
    }
}