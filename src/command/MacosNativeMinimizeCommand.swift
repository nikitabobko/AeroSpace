import Common

struct MacosNativeMinimizeCommand: Command {
    let args: MacosNativeMinimizeCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append("No window in focus")
            return false
        }
        let axWindow = window.asMacWindow().axWindow
        let success = axWindow.set(Ax.minimizedAttr, !window.isMacosMinimized)
        if !success { state.stderr.append("Failed") }
        return success
    }
}
