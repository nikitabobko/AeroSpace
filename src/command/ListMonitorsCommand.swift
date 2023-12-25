import Common

struct ListMonitorsCommand: Command {
    let info: CmdStaticInfo = ListMonitorsCmdArgs.info
    let args: ListMonitorsCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout String) -> Bool {
        check(Thread.current.isMainThread)
        var result: [(Int, Monitor)] = sortedMonitors.withIndex
        if args.getOptionWithDefault(\.focused) {
            result = result.filter { (_, monitor) in
                monitor.activeWorkspace.name == focusedWorkspaceName
            }
        }
        if args.getOptionWithDefault(\.mouse) {
            result = result.filter { (_, monitor) in
                monitor.activeWorkspace.name == mouseLocation.monitorApproximation.activeWorkspace.name
            }
        }
        stdout += result
            .map { (index, monitor) in
                [String(index + 1), monitor.name]
            }
            .toPaddingTable()
            + "\n"
        return true
    }
}
