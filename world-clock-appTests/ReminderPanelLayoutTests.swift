import CoreGraphics
import Foundation
import Testing
@testable import world_clock_app

@MainActor
struct ReminderPanelLayoutTests {
    // Four displays from a real arrangement: a wide main display, two
    // displays above it, and a laptop display on its left.
    private let main = ReminderPanelLayout.Display(
        frame: CGRect(x: 0, y: 0, width: 3840, height: 1080),
        visibleFrame: CGRect(x: 0, y: 0, width: 3840, height: 1050)
    )
    private let aboveRight = ReminderPanelLayout.Display(
        frame: CGRect(x: 1920, y: 1080, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1920, y: 1080, width: 1920, height: 1050)
    )
    private let aboveLeft = ReminderPanelLayout.Display(
        frame: CGRect(x: 0, y: 1080, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 1080, width: 1920, height: 1050)
    )
    private let laptop = ReminderPanelLayout.Display(
        frame: CGRect(x: -1728, y: -37, width: 1728, height: 1117),
        visibleFrame: CGRect(x: -1728, y: -37, width: 1728, height: 1084)
    )
    private var displays: [ReminderPanelLayout.Display] { [main, aboveRight, aboveLeft, laptop] }
    private let size = CGSize(width: 320, height: 125)

    @Test func usesTheMainMenuBarWhenTheIconFrameIsReportedOffset() {
        // Measured: the icon is drawn in the main display's menu bar, but its
        // window frame is reported 74 pt higher, inside the display above.
        let icon = CGRect(x: 2993, y: 1124, width: 38, height: 30)

        let frame = ReminderPanelLayout.frame(size: size, iconFrame: icon, displays: displays, fallback: main)

        #expect(frame.maxY == main.visibleFrame.maxY - ReminderPanelLayout.gap)
        #expect(frame.midX == icon.midX)
        #expect(main.visibleFrame.contains(frame))
    }

    @Test func staysInsideTheDisplayNearItsRightEdge() {
        let icon = CGRect(x: 3820, y: 1050, width: 20, height: 30)

        let frame = ReminderPanelLayout.frame(size: size, iconFrame: icon, displays: displays, fallback: main)

        #expect(frame.maxX == main.visibleFrame.maxX - ReminderPanelLayout.margin)
        #expect(main.visibleFrame.contains(frame))
    }

    @Test func picksTheLaptopDisplayForAnIconInItsMenuBar() {
        let icon = CGRect(x: -300, y: 1050, width: 38, height: 30)

        let frame = ReminderPanelLayout.frame(size: size, iconFrame: icon, displays: displays, fallback: main)

        #expect(laptop.visibleFrame.contains(frame))
        #expect(frame.maxY == laptop.visibleFrame.maxY - ReminderPanelLayout.gap)
    }

    @Test func fallsBackToTheTopRightCornerWithoutAnIcon() {
        let frame = ReminderPanelLayout.frame(size: size, iconFrame: nil, displays: displays, fallback: main)

        #expect(frame.maxX == main.visibleFrame.maxX - ReminderPanelLayout.margin)
        #expect(frame.maxY == main.visibleFrame.maxY - ReminderPanelLayout.gap)
    }
}
