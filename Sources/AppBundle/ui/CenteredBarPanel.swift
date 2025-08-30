import AppKit

/// Custom NSPanel subclass that bypasses the default menu bar constraint
/// This allows the panel to be positioned within the menu bar area
@MainActor
class CenteredBarPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // Return frameRect unchanged to bypass the system's menu bar constraint
        // This allows our panel to overlap with the menu bar area
        return frameRect
    }
}