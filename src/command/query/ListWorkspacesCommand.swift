import Common

struct ListWorkspacesCommand: Command {
    let info: CmdStaticInfo = ListWorkspacesCmdArgs.info
    let args: ListWorkspacesCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var result: [Workspace] = Workspace.all
        if let visible = args.visible {
            result = result.filter { $0.isVisible == visible }
        }
        if let focused = args.focused {
            result = result.filter { ($0 == Workspace.focused) == focused }
        }
        if !args.onMonitors.isEmpty {
            let sortedMonitors = sortedMonitors
            var requested: Set<CGPoint> = []
            for id in args.onMonitors {
                if let monitor = sortedMonitors.getOrNil(atIndex: id) {
                    requested.insert(monitor.rect.topLeftCorner)
                } else {
                    state.stdout.append("Invalid monitor ID: \(id)")
                    return false
                }
            }
            result = result.filter { requested.contains($0.monitor.rect.topLeftCorner) }
        }
        state.stdout += result.map(\.name)
        return true
    }
}
