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

/// This object should be only passed around but never memorized
/// Alternative name: ResolvedFocus
struct LiveFocus: AeroAny, Equatable {
    let windowOrNil: Window?
    var workspace: Workspace

    @MainActor var frozen: FrozenFocus {
        return FrozenFocus(
            windowId: windowOrNil?.windowId,
            workspaceName: workspace.name,
            monitorId: workspace.workspaceMonitor.monitorId ?? 0,
        )
    }
}

/// "old", "captured", "frozen in time" Focus
/// It's safe to keep a hard reference to this object.
/// Unlike in LiveFocus, information inside FrozenFocus isn't guaranteed to be self-consistent.
/// window - workspace - monitor relation could change since the object is created
struct FrozenFocus: AeroAny, Equatable, Sendable {
    let windowId: UInt32?
    let workspaceName: String
    // monitorId is not part of the focus. We keep it here only for 'on-monitor-changed' to work
    let monitorId: Int // 0-based

    @MainActor var live: LiveFocus { // Important: don't access focus.monitorId here. monitorId is not part of the focus. Always prefer workspace
        let window: Window? = windowId.flatMap { Window.get(byId: $0) }
        let workspace = Workspace.get(byName: workspaceName)

        let wsFocus = workspace.toLiveFocus()
        let wdFocus = window?.toLiveFocusOrNil() ?? wsFocus

        return wsFocus.workspace != wdFocus.workspace
            ? wsFocus // If window and workspace become separated prefer workspace
            : wdFocus
    }
}

@MainActor private var _focus: FrozenFocus = {
    let monitor = mainMonitor
    return FrozenFocus(windowId: nil, workspaceName: monitor.activeWorkspace.name, monitorId: monitor.monitorId ?? 0)
}()

/// Global focus.
/// Commands must be cautious about accessing this property directly. There are legitimate cases.
/// But, in general, commands must firstly check --window-id, --workspace, AEROSPACE_WINDOW_ID env and
/// AEROSPACE_WORKSPACE env before accessing the global focus.
@MainActor var focus: LiveFocus { _focus.live }

@MainActor func setFocus(to newFocus: LiveFocus) -> Bool {
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
    @MainActor func focusWindow() -> Bool {
        if let focus = toLiveFocusOrNil() {
            return setFocus(to: focus)
        } else {
            // todo We should also exit-native-hidden/unminimize[/exit-native-fullscreen?] window if we want to fix ID-B6E178F2
            //      and retry to focus the window. Otherwise, it's not possible to focus minimized/hidden windows
            return false
        }
    }

    @MainActor func toLiveFocusOrNil() -> LiveFocus? { visualWorkspace.map { LiveFocus(windowOrNil: self, workspace: $0) } }
}
extension Workspace {
    @MainActor func focusWorkspace() -> Bool { setFocus(to: toLiveFocus()) }

    func toLiveFocus() -> LiveFocus {
        // todo unfortunately mostRecentWindowRecursive may recursively reach empty rootTilingContainer
        //      while floating or macos unconventional windows might be presented
        if let wd = mostRecentWindowRecursive ?? anyLeafWindowRecursive {
            LiveFocus(windowOrNil: wd, workspace: self)
        } else {
            LiveFocus(windowOrNil: nil, workspace: self) // emptyWorkspace
        }
    }
}

@MainActor private var _lastKnownFocus: FrozenFocus = _focus

// Used by workspace-back-and-forth
@MainActor var _prevFocusedWorkspaceName: String? = nil {
    didSet {
        prevFocusedWorkspaceDate = .now
    }
}
@MainActor var prevFocusedWorkspaceDate: Date = .distantPast
@MainActor var prevFocusedWorkspace: Workspace? { _prevFocusedWorkspaceName.map { Workspace.get(byName: $0) } }

// Used by focus-back-and-forth
@MainActor var _prevFocus: FrozenFocus? = nil
@MainActor var prevFocus: LiveFocus? { _prevFocus?.live.takeIf { $0 != focus } }

// Focus history stack (for focus back/forward)
@MainActor private var _focusHistory: [FrozenFocus] = []
@MainActor private var _focusHistoryPosition: Int = -1
@MainActor private var _pendingHistoryNavigation: FrozenFocus? = nil  // Skip recording if focus matches this
private let maxFocusHistorySize = 100

@MainActor func resetFocusHistoryForTests() {
    _focusHistory = []
    _focusHistoryPosition = -1
    _pendingHistoryNavigation = nil
}

@MainActor private var onFocusChangedRecursionGuard = false
// Should be called in refreshSession
@MainActor func checkOnFocusChangedCallbacks() {
    if refreshSessionEvent?.isStartup == true {
        return
    }
    let focus = focus
    let frozenFocus = focus.frozen
    var hasFocusChanged = false
    var hasFocusedWorkspaceChanged = false
    var hasFocusedMonitorChanged = false
    if frozenFocus != _lastKnownFocus {
        _prevFocus = _lastKnownFocus
        hasFocusChanged = true

        // Record to focus history (only if not navigating via back/forward)
        // Compare windowId and workspaceName to handle cases where monitorId might differ
        if let pending = _pendingHistoryNavigation,
           pending.windowId == frozenFocus.windowId && pending.workspaceName == frozenFocus.workspaceName
        {
            _pendingHistoryNavigation = nil  // Clear the pending navigation
        } else {
            recordFocusHistory(frozenFocus)
        }
    }
    if frozenFocus.workspaceName != _lastKnownFocus.workspaceName {
        _prevFocusedWorkspaceName = _lastKnownFocus.workspaceName
        hasFocusedWorkspaceChanged = true
    }
    if frozenFocus.monitorId != _lastKnownFocus.monitorId {
        hasFocusedMonitorChanged = true
    }
    _lastKnownFocus = frozenFocus

    if onFocusChangedRecursionGuard { return }
    onFocusChangedRecursionGuard = true
    defer { onFocusChangedRecursionGuard = false }
    if hasFocusChanged {
        onFocusChanged(focus)
    }
    if let _prevFocusedWorkspaceName, hasFocusedWorkspaceChanged {
        onWorkspaceChanged(_prevFocusedWorkspaceName, frozenFocus.workspaceName)
    }
    if hasFocusedMonitorChanged {
        onFocusedMonitorChanged(focus)
    }
}

@MainActor private func onFocusedMonitorChanged(_ focus: LiveFocus) {
    if config.onFocusedMonitorChanged.isEmpty { return }
    guard let token: RunSessionGuard = .isServerEnabled else { return }
    // todo potential optimization: don't run runSession if we are already in runSession
    Task {
        try await runLightSession(.onFocusedMonitorChanged, token) {
            _ = try await config.onFocusedMonitorChanged.runCmdSeq(.defaultEnv.withFocus(focus), .emptyStdin)
        }
    }
}
@MainActor private func onFocusChanged(_ focus: LiveFocus) {
    if config.onFocusChanged.isEmpty { return }
    guard let token: RunSessionGuard = .isServerEnabled else { return }
    // todo potential optimization: don't run runSession if we are already in runSession
    Task {
        try await runLightSession(.onFocusChanged, token) {
            _ = try await config.onFocusChanged.runCmdSeq(.defaultEnv.withFocus(focus), .emptyStdin)
        }
    }
}

@MainActor private func onWorkspaceChanged(_ oldWorkspace: String, _ newWorkspace: String) {
    if let exec = config.execOnWorkspaceChange.first {
        let process = Process()
        process.executableURL = URL(filePath: exec)
        process.arguments = Array(config.execOnWorkspaceChange.dropFirst())
        var environment = config.execConfig.envVariables
        environment["AEROSPACE_FOCUSED_WORKSPACE"] = newWorkspace
        environment["AEROSPACE_PREV_WORKSPACE"] = oldWorkspace
        environment[AEROSPACE_WORKSPACE] = newWorkspace
        process.environment = environment
        _ = Result { try process.run() }
    }
}

// MARK: - Focus History (for focus back/forward)

/// Record a new focus to the history stack. Truncates forward history if not at end.
@MainActor private func recordFocusHistory(_ newFocus: FrozenFocus) {
    // Don't add consecutive duplicates
    if _focusHistory.last == newFocus {
        return
    }

    // If we're not at the end, truncate forward history
    if _focusHistoryPosition >= 0 && _focusHistoryPosition < _focusHistory.count - 1 {
        _focusHistory = Array(_focusHistory.prefix(_focusHistoryPosition + 1))
    }

    _focusHistory.append(newFocus)

    // Trim if too large
    if _focusHistory.count > maxFocusHistorySize {
        _focusHistory.removeFirst()
    }

    _focusHistoryPosition = _focusHistory.count - 1
}

/// Navigate back in focus history. Returns the element to focus, or nil if at beginning.
/// Automatically skips closed windows.
@MainActor func focusHistoryBack() -> LiveFocus? {
    while _focusHistoryPosition > 0 {
        _focusHistoryPosition -= 1
        let frozen = _focusHistory[_focusHistoryPosition]
        // Skip if window was closed
        if let windowId = frozen.windowId, Window.get(byId: windowId) == nil {
            continue
        }
        let live = frozen.live
        // Skip if it's the same as current focus
        if live != focus {
            _pendingHistoryNavigation = frozen
            return live
        }
    }
    return nil
}

/// Navigate forward in focus history. Returns the element to focus, or nil if at end.
/// Automatically skips closed windows.
@MainActor func focusHistoryForward() -> LiveFocus? {
    while _focusHistoryPosition < _focusHistory.count - 1 {
        _focusHistoryPosition += 1
        let frozen = _focusHistory[_focusHistoryPosition]
        // Skip if window was closed
        if let windowId = frozen.windowId, Window.get(byId: windowId) == nil {
            continue
        }
        let live = frozen.live
        // Skip if it's the same as current focus
        if live != focus {
            _pendingHistoryNavigation = frozen
            return live
        }
    }
    return nil
}
