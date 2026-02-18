import SwiftUI
import ServiceManagement

@main
struct world_clock_appApp: App {
    init() {
        try? SMAppService.mainApp.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 380)
        }
        .defaultSize(width: 900, height: 580)
    }
}
