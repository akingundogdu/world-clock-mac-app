import AppKit
import SwiftUI
import Combine

/// Owns the menu bar bell icon. A click opens the reminder list in a popover;
/// a due reminder slides a panel down from under the icon.
final class ReminderMenuBarController: NSObject {
    private let store: ReminderStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private lazy var alertPanel = makeAlertPanel()
    private lazy var alertHostingView = NSHostingView(rootView: makeAlertStack([]))
    private var cancellables = Set<AnyCancellable>()

    init(store: ReminderStore, onShowMainWindow: @escaping () -> Void) {
        self.store = store
        super.init()

        if let button = statusItem.button {
            button.image = Self.icon(hasAlerts: false)
            button.target = self
            button.action = #selector(togglePopover)
        }

        let listView = ReminderListView(store: store, onShowMainWindow: { [weak self] in
            self?.popover.performClose(nil)
            onShowMainWindow()
        })
        let hosting = NSHostingController(rootView: listView)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        store.onAlertRaised = { _ in Self.playAlertSound() }

        // @Published emits before the value is stored, so read the emitted value.
        store.$activeAlerts
            .receive(on: RunLoop.main)
            .sink { [weak self] alerts in
                MainActor.assumeIsolated { self?.render(alerts) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Alert panel

    private func render(_ alerts: [ReminderAlert]) {
        statusItem.button?.image = Self.icon(hasAlerts: !alerts.isEmpty)

        guard !alerts.isEmpty else {
            alertPanel.orderOut(nil)
            return
        }

        if popover.isShown { popover.performClose(nil) }

        let wasVisible = alertPanel.isVisible
        alertHostingView.rootView = makeAlertStack(alerts)
        alertHostingView.layoutSubtreeIfNeeded()
        let finalFrame = panelFrame(for: alertHostingView.fittingSize)

        if wasVisible {
            alertPanel.setFrame(finalFrame, display: true, animate: true)
            return
        }

        // Slide down from just under the menu bar.
        alertPanel.setFrame(finalFrame.offsetBy(dx: 0, dy: 12), display: false)
        alertPanel.alphaValue = 0
        alertPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            alertPanel.animator().setFrame(finalFrame, display: true)
            alertPanel.animator().alphaValue = 1
        }
    }

    private func makeAlertStack(_ alerts: [ReminderAlert]) -> ReminderAlertStack {
        ReminderAlertStack(
            alerts: alerts,
            onDone: { [weak self] id in self?.store.dismiss(alertID: id) },
            onSnooze: { [weak self] id, minutes in self?.store.snooze(alertID: id, minutes: minutes) }
        )
    }

    private func makeAlertPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = alertHostingView
        return panel
    }

    private func panelFrame(for size: NSSize) -> NSRect {
        let screens = NSScreen.screens.map { ReminderPanelLayout.Display(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let fallback = (NSScreen.main ?? NSScreen.screens[0])
        return ReminderPanelLayout.frame(
            size: size,
            iconFrame: statusItem.button?.window?.frame,
            displays: screens,
            fallback: ReminderPanelLayout.Display(frame: fallback.frame, visibleFrame: fallback.visibleFrame)
        )
    }

    // MARK: - Helpers

    private static func icon(hasAlerts: Bool) -> NSImage? {
        let image = NSImage(
            systemSymbolName: hasAlerts ? "bell.badge.fill" : "bell",
            accessibilityDescription: "Reminders"
        )
        image?.isTemplate = true
        return image
    }

    private static func playAlertSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
