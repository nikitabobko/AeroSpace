import Common

struct ReloadConfigCommand: Command {
    let info: CmdStaticInfo = ReloadConfigCmdArgs.info

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        reloadConfig()
        return true
    }
}
