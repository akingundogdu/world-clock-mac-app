import SwiftUI
import ServiceManagement

@main
struct world_clock_appApp: App {
    // The main window is created by AppDelegate (see MainWindowController),
    // so it is always shown at launch, including login-item launches.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        try? SMAppService.mainApp.register()
    }

    var body: some Scene {
        // SwiftUI needs at least one scene. The app has no settings, so the
        // Settings menu item is removed.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
        }
    }
}
