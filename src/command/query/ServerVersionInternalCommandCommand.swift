import Common

struct ServerVersionInternalCommandCommand: Command {
    let info: CmdStaticInfo = ServerVersionInternalCommandCmdArgs.info

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        state.stdout.append("\(Bundle.appVersion) \(gitHash)")
        return true
    }
}
