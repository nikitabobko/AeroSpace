import Common

struct VersionCommand: Command {
    let info: CmdStaticInfo = VersionCmdArgs.info

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        state.stdout.append("\(Bundle.appVersion) \(gitHash)")
        return true
    }
}
