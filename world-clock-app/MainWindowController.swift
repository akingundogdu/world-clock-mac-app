import AppKit
import SwiftUI

/// Creates and shows the main clock window from AppKit.
///
/// SwiftUI's `WindowGroup` sometimes left the app running with no window at
/// launch (seen on login-item launches), and nothing in SwiftUI can reliably
/// reopen it. Owning the window here makes "the window is on screen" a direct,
/// deterministic call.
final class MainWindowController: NSObject, NSWindowDelegate {
    private static let autosaveName = "MainWindow"
    /// Below this size the date, clocks, action tiles and a fully expanded
    /// calendar panel no longer fit without overlapping (measured).
    static let minimumContentSize = NSSize(width: 640, height: 690)
    private static let defaultSize = NSSize(width: 1100, height: 720)

    private let reminderStore: ReminderStore
    private var window: NSWindow?
    private var isEnteringFullScreen = false

    init(reminderStore: ReminderStore) {
        self.reminderStore = reminderStore
    }

    var isWindowVisible: Bool { window?.isVisible ?? false }

    /// Shows the window and puts it in macOS full screen on the display it was
    /// last on (or the main display if that one is gone).
    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        moveOnScreenIfNeeded(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        enterFullScreen(window)
    }

    private func enterFullScreen(_ window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen), !isEnteringFullScreen else { return }
        isEnteringFullScreen = true
        // Let the window finish ordering in before the full screen transition.
        DispatchQueue.main.async { window.toggleFullScreen(nil) }
    }

    private func makeWindow() -> NSWindow {
        let rootView = ContentView()
            .environmentObject(reminderStore)
            .frame(minWidth: Self.minimumContentSize.width, minHeight: Self.minimumContentSize.height)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "World Clock"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.contentMinSize = Self.minimumContentSize
        window.delegate = self
        // Closing hides the window; the clocks keep their state until the app quits.
        window.isReleasedWhenClosed = false
        window.setContentSize(Self.defaultSize)
        window.center()
        // Restores the last position and size, if one was saved.
        window.setFrameAutosaveName(Self.autosaveName)
        return window
    }

    /// A saved frame can point at a display that is no longer connected
    /// (or not ready yet at login). Recenter the window if it is off screen.
    private func moveOnScreenIfNeeded(_ window: NSWindow) {
        let isOnScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(window.frame) }
        guard !isOnScreen else { return }
        window.setContentSize(Self.defaultSize)
        window.center()
    }

    // MARK: - NSWindowDelegate

    func windowDidEnterFullScreen(_ notification: Notification) {
        isEnteringFullScreen = false
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        isEnteringFullScreen = false
    }
}
