import AppKit
import Common

struct CloseCommand: Command {
    let args: CloseCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            return state.failCmd(msg: "Empty workspace")
        }
        if window.macAppUnsafe.axApp.get(Ax.windowsAttr)?.count == 1 && args.quitIfLastWindow {
            if window.macAppUnsafe.nsApp.terminate() {
                successfullyClosedWindow(state, window)
                return true
            } else {
                return state.failCmd(msg: "Failed to quit '\(window.app.name ?? "Unknown app")'")
            }
        } else {
            if window.close() {
                successfullyClosedWindow(state, window)
                return true
            } else {
                return state.failCmd(msg: "Can't close '\(window.app.name ?? "Unknown app")' window. Probably the window doesn't have a close button")
            }
        }
    }
}

private func successfullyClosedWindow(_ state: CommandMutableState, _ window: Window) {
    window.asMacWindow().garbageCollect()
    state.subject = .focused
}
