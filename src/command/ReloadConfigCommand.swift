import Common

struct ReloadConfigCommand: Command {
    let args = ReloadConfigCmdArgs()

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        reloadConfig()
        return true
    }
}
