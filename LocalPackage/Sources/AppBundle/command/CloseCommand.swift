import Common

struct CloseCommand: Command {
    let args: CloseCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append("Empty workspace")
            return false
        }
        if window.macAppUnsafe.axApp.get(Ax.windowsAttr)?.count == 1 && args.quitIfLastWindow {
            if window.macAppUnsafe.nsApp.terminate() {
                successfullyClosedWindow(state, window)
                return true
            } else {
                state.stderr.append("Failed to quit '\(window.app.name ?? "Unknown app")'")
                return false
            }
        } else {
            if window.close() {
                successfullyClosedWindow(state, window)
                return true
            } else {
                state.stderr.append("Can't close '\(window.app.name ?? "Unknown app")' window. Probably the window doesn't have a close button")
                return false
            }
        }
    }
}

private func successfullyClosedWindow(_ state: CommandMutableState, _ window: Window) {
    window.asMacWindow().garbageCollect()
    if let focusedWindow {
        state.subject = .window(focusedWindow)
    } else {
        state.subject = .emptyWorkspace(focusedWorkspaceName)
    }
}
