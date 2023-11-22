var appForTests: AeroApp? = nil

private var focusedApp: AeroApp? {
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
var focusedWorkspaceName: String {
    get { _focusedWorkspaceName }
    set {
        if newValue != _focusedWorkspaceName {
            previousFocusedWorkspaceName = _focusedWorkspaceName
        }
        _focusedWorkspaceName = newValue
    }
}
var previousFocusedWorkspaceName: String? = nil
