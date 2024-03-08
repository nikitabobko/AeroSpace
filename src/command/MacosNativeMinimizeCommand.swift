import Common

/// See: MacosNativeFullscreenCommand. Problem ID-B6E178F2
struct MacosNativeMinimizeCommand: Command {
    let args: MacosNativeMinimizeCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append("No window in focus")
            return false
        }
        let axWindow = window.asMacWindow().axWindow
        let newState: Bool = !window.isMacosMinimized
        if axWindow.set(Ax.minimizedAttr, newState) {
            let workspace = window.unbindFromParent().parent.workspace ?? Workspace.focused
            if newState {
                window.bind(to: macosInvisibleWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                if let mru = workspace.mostRecentWindow {
                    state.subject = .window(mru)
                } else {
                    state.subject = .emptyWorkspace(workspace.name)
                }
            } else {
                switch window.layoutReason {
                case .macos(let prevParentKind):
                    macOsExitMacOsNativeOrInvisibleState(window: window, prevParentKind: prevParentKind, workspace: workspace)
                default: // wtf case. Theoretically should never happen
                    window.relayoutWindow(on: workspace)
                }
                state.subject = .window(window)
            }
            return true
        } else {
            state.stderr.append("Failed")
            return false
        }
    }
}
