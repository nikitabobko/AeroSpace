import Common

var appForTests: AbstractApp? = nil

private var focusedApp: AbstractApp? {
    if isUnitTest {
        return appForTests
    } else {
        check(appForTests == nil)
        return NSWorkspace.shared.frontmostApplication?.macApp
    }
}

func getNativeFocusedWindow(startup: Bool) -> Window? {
    focusedApp?.getFocusedWindow(startup: startup)
}

var focusedWindow: Window? {
    //check(focusSourceOfTruth == .ownModel)
    return Workspace.focused.mostRecentWindow ?? Workspace.focused.anyLeafWindowRecursive
    //focusSourceOfTruth == .ownModel
    //    ? (Workspace.focused.mostRecentWindow ?? Workspace.focused.anyLeafWindowRecursive)
    //    : nativeFocusedWindow
}

// It's fine to call this inaccurate during startup
private var _focusedWorkspaceName: String = focusedMonitorInaccurate?.activeWorkspace.name
    ?? mainMonitor.activeWorkspace.name
var focusedWorkspaceName: String { // todo change to focused monitor
    get { _focusedWorkspaceName }
    set {
        let oldValue = _focusedWorkspaceName
        _focusedWorkspaceName = newValue
        if oldValue != newValue {
            // Firing Notification for e.g Sketchybar Integration
            DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("bobko.aerospace.focusedWorkspaceChanged"), object: nil)

            previousFocusedWorkspaceName = oldValue
        }
    }
}
var previousFocusedWorkspaceName: String? = nil
