import Common

struct FullscreenCommand: Command {
    let info: CmdStaticInfo = FullscreenCmdArgs.info

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = state.subject.windowOrNil else {
            state.stdout.append(noWindowIsFocused)
            return false
        }
        window.isFullscreen = !window.isFullscreen

        // Focus on its own workspace
        window.markAsMostRecentChild()
        return true
    }
}

let noWindowIsFocused = "No window is focused"
