import Foundation

extension NSWorkspace {
    static var finderApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }
    }

    private static var _activeApp: NSRunningApplication? = nil

    static var activeApp: NSRunningApplication? {
        /// Force assign currently active app in scope of this session
        set { _activeApp = newValue }
        get { _activeApp ?? NSWorkspace.shared.frontmostApplication }
    }
}
