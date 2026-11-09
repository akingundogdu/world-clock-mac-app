import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let reminderStore = ReminderStore()
    private lazy var mainWindow = MainWindowController(reminderStore: reminderStore)
    private var menuBarController: ReminderMenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = ReminderMenuBarController(store: reminderStore) { [weak self] in
            self?.mainWindow.show()
        }
        reminderStore.startTicking()
        mainWindow.show()
    }

    /// Clicking the Dock icon or launching the app again brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !mainWindow.isWindowVisible { mainWindow.show() }
        return true
    }
}
