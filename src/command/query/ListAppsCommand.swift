import Common

struct ListAppsCommand: Command {
    let info: CmdStaticInfo = ListAppsCmdArgs.info

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        state.stdout += apps
            .map { app in
                let pid = String(app.pid)
                let appId = app.id ?? "NULL"
                let name = app.name ?? "NULL"
                return [pid, appId, name]
            }
            .toPaddingTable()
        return true
    }
}
