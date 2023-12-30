import Common

struct ListAppsCommand: Command {
    let args = ListAppsCmdArgs()

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        state.stdout += apps
            .map { app in
                let pid = String(app.pid)
                let appId = app.id ?? "NULL-APP-ID"
                let name = app.name ?? "NULL-NAME"
                return [pid, appId, name]
            }
            .toPaddingTable()
        return true
    }
}
