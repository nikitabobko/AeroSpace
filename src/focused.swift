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
            onWorkspaceChanged(oldValue, newValue)
            previousFocusedWorkspaceName = oldValue
        }
    }
}
var previousFocusedWorkspaceName: String? = nil

private func onWorkspaceChanged(_ oldWorkspace: String, _ newWorkspace: String) {
    if let exec = config.execOnWorkspaceChange.first {
        let process = Process()
        process.executableURL = URL(filePath: exec)
        process.arguments = Array(config.execOnWorkspaceChange.dropFirst())
        var environment = ProcessInfo.processInfo.environment
        environment["AEROSPACE_FOCUSED_WORKSPACE"] = newWorkspace
        environment["AEROSPACE_PREV_WORKSPACE"] = oldWorkspace
        process.environment = environment
        Result { try process.run() }.getOrThrow() // todo It's not perfect to fail here
    }
}
