import Common

struct MacosNativeFullscreenCommand: Command {
    let args: MacosNativeFullscreenCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stderr.append("No window in focus")
            return false
        }
        let axWindow = window.asMacWindow().axWindow
        let success = axWindow.set(Ax.isFullscreenAttr, !window.isMacosFullscreen)
        if !success { state.stderr.append("Failed") }
        return success
    }
}
