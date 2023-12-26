import Common

struct MoveWorkspaceToMonitorCommand: Command {
    let info: CmdStaticInfo = MoveWorkspaceToMonitorCmdArgs.info
    let args: MoveWorkspaceToMonitorCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        let focusedWorkspace = subject.workspace
        let prevMonitor = focusedWorkspace.monitor
        let sortedMonitors = sortedMonitors
        guard let index = sortedMonitors.firstIndex(where: { $0.rect.topLeftCorner == prevMonitor.rect.topLeftCorner }) else { return false }
        guard let targetMonitor = sortedMonitors.get(wrappingIndex: args.target.val == .next ? index + 1 : index - 1) else { return false }

        if targetMonitor.setActiveWorkspace(focusedWorkspace) {
            let stubWorkspace = getStubWorkspace(for: prevMonitor)
            check(prevMonitor.setActiveWorkspace(stubWorkspace),
                "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)")
            return true
        } else {
            stdout.append("Can't move workspace '\(focusedWorkspace.name)' to monitor '\(targetMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it")
            return false
        }
    }
}
