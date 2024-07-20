import AppKit
import Common

enum EffectiveLeaf {
    case window(Window)
    case emptyWorkspace(Workspace)
}
extension LiveFocus {
    var asLeaf: EffectiveLeaf {
        if let windowOrNil { .window(windowOrNil) } else { .emptyWorkspace(workspace) }
    }
}

extension Window {
    var visualWorkspace: Workspace? { workspace ?? nodeMonitor?.activeWorkspace }
}

/// This object should be only passed around but never memorized
/// Alternative name: ResolvedFocus
struct LiveFocus: AeroAny, Equatable {
    let windowOrNil: Window?
    var workspace: Workspace

    var frozen: FrozenFocus {
        return FrozenFocus(
            windowId: windowOrNil?.windowId,
            workspaceName: workspace.name,
            monitorId: workspace.workspaceMonitor.monitorId ?? 0
        )
    }
}

/// "old", "captured", "frozen in time" Focus
/// It's safe to keep a hard reference to this object.
/// Unlike in LiveFocus, information inside FrozenFocus isn't guaranteed to be self-consistent.
/// window - workspace - monitor relation could change since the object is created
struct FrozenFocus: AeroAny, Equatable {
    let windowId: UInt32?
    let workspaceName: String
    // monitorId is not part of the focus. We keep it here only for 'on-monitor-changed' to work
    let monitorId: Int // 0-based

    var live: LiveFocus { // Important: don't access focus.monitorId here. monitorId is not part of the focus. Always prefer workspace
        let windowId = windowId
        let window: Window? = if let windowId {
            isUnitTest
                ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }.first(where: { $0.windowId == windowId })
                : MacWindow.allWindowsMap[windowId]
        } else {
            nil
        }
        if let window, let ws = window.visualWorkspace {
            return LiveFocus(windowOrNil: window, workspace: ws)
        }
        let workspace = Workspace.get(byName: workspaceName)
        return LiveFocus(windowOrNil: workspace.mostRecentWindow, workspace: workspace)
    }
}

var _focus: FrozenFocus =  {
    // It's fine to call *Inaccurate during startup
    let monitor = focusedMonitorInaccurate ?? mainMonitor
    return FrozenFocus(windowId: nil, workspaceName: monitor.activeWorkspace.name, monitorId: monitor.monitorId ?? 0)
}()
var focus: LiveFocus { _focus.live }

private func setFocus(to newFocus: LiveFocus) -> Bool {
    if _focus == newFocus.frozen { return true }
    let oldFocus = focus
    // Normalize mruWindow when focus away from a workspace
    if oldFocus.workspace != newFocus.workspace {
        oldFocus.windowOrNil?.markAsMostRecentChild()
    }

    _focus = newFocus.frozen
    let status = newFocus.workspace.workspaceMonitor.setActiveWorkspace(newFocus.workspace)

    newFocus.windowOrNil?.markAsMostRecentChild()
    return status
}
extension Window {
    func focusWindow() -> Bool {
        if let ws = self.visualWorkspace {
            return setFocus(to: LiveFocus(windowOrNil: self, workspace: ws))
        } else {
            // todo We should also exit-native-hidden/unminimize[/exit-native-fullscreen?] window if we want to fix ID-B6E178F2
            //      and retry to focus the window. Otherwise, it's not possible to focus minimized/hidden windows
            return false
        }
    }
}
extension Workspace {
    func focusWorkspace() -> Bool {
        if let w = mostRecentWindow {
            return w.focusWindow()
        } else {
            check(anyLeafWindowRecursive == nil)
            return setFocus(to: LiveFocus(windowOrNil: nil, workspace: self))
        }
    }
}

private var _lastKnownFocus: FrozenFocus = _focus

// Used by workspace-back-and-forth
var _prevFocusedWorkspaceName: String? = nil
var prevFocusedWorkspace: Workspace? { _prevFocusedWorkspaceName.map { Workspace.get(byName: $0) } }

// Used by focus-back-and-forth
var _prevFocus: FrozenFocus? = nil
var prevFocus: LiveFocus? { _prevFocus?.live }

func checkOnFocusChangedCallbacks() {
    let focus = focus.frozen
    if focus.workspaceName != _lastKnownFocus.workspaceName {
        onWorkspaceChanged(_lastKnownFocus.workspaceName, focus.workspaceName)
        _prevFocusedWorkspaceName = _lastKnownFocus.workspaceName
    }
    if focus.monitorId != _lastKnownFocus.monitorId {
        // todo onMonitorChanged
    }
    if focus != _lastKnownFocus {
        // todo onFocusChanged
        _prevFocus = _lastKnownFocus
    }
    _lastKnownFocus = focus
}

private func onWorkspaceChanged(_ oldWorkspace: String, _ newWorkspace: String) {
    if let exec = config.execOnWorkspaceChange.first {
        let process = Process()
        process.executableURL = URL(filePath: exec)
        process.arguments = Array(config.execOnWorkspaceChange.dropFirst())
        var environment = config.execConfig.envVariables
        environment["AEROSPACE_FOCUSED_WORKSPACE"] = newWorkspace
        environment["AEROSPACE_PREV_WORKSPACE"] = oldWorkspace
        process.environment = environment
        Result { try process.run() }.getOrThrow() // todo It's not perfect to fail here
    }
}
