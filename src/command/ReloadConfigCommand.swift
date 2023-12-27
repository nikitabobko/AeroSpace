import Common

struct ReloadConfigCommand: Command {
    let info: CmdStaticInfo = ReloadConfigCmdArgs.info

    func _run(_ subject: inout CommandSubject, stdin: String, stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        reloadConfig()
        return true
    }
}
