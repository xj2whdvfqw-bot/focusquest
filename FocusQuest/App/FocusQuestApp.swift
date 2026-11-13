import SwiftUI
import UserNotifications

@main
struct FocusQuestApp: App {
    @State private var container = AppDIContainer()

    init() {
        _ = RuntimeSecurityService().integrityReport()
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
        }
    }
}