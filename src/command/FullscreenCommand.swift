import Common

struct FullscreenCommand: Command {
    let info: CmdStaticInfo = FullscreenCmdArgs.info

    func _run(_ subject: inout CommandSubject, stdin: String, stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        guard let window = subject.windowOrNil else {
            stdout.append(noWindowIsFocused)
            return false
        }
        window.isFullscreen = !window.isFullscreen

        // Focus on its own workspace
        window.markAsMostRecentChild()
        return true
    }
}

let noWindowIsFocused = "No window is focused"
