import CoreGraphics

/// Where the reminder alert panel goes: right under the menu bar, centered
/// below the bell icon, and always fully on one display.
enum ReminderPanelLayout {
    struct Display: Equatable {
        let frame: CGRect
        let visibleFrame: CGRect
    }

    static let gap: CGFloat = 4
    static let margin: CGFloat = 8

    /// - Parameters:
    ///   - iconFrame: The status item window's frame. With several displays it
    ///     can be reported tens of points away from the menu bar it is drawn in,
    ///     so only its horizontal position is trusted.
    static func frame(size: CGSize, iconFrame: CGRect?, displays: [Display], fallback: Display) -> CGRect {
        let display = iconFrame.flatMap { menuBarDisplay(for: $0, in: displays) } ?? fallback
        let visible = display.visibleFrame
        let preferredX = iconFrame.map { $0.midX - size.width / 2 } ?? (visible.maxX - size.width - margin)
        let x = min(max(preferredX, visible.minX + margin), visible.maxX - size.width - margin)
        return CGRect(x: x, y: visible.maxY - size.height - gap, width: size.width, height: size.height)
    }

    /// The display under the icon horizontally whose top edge is closest to it.
    static func menuBarDisplay(for iconFrame: CGRect, in displays: [Display]) -> Display? {
        displays
            .filter { $0.frame.minX <= iconFrame.midX && iconFrame.midX <= $0.frame.maxX }
            .min { abs($0.frame.maxY - iconFrame.midY) < abs($1.frame.maxY - iconFrame.midY) }
    }
}
