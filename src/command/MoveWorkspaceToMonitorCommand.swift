struct MoveWorkspaceToMonitorCommand: Command {
    let args: MoveWorkspaceToMonitorCmdArgs

    func _run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        let focusedWorkspace = subject.workspace
        let prevMonitor = focusedWorkspace.monitor
        let sortedMonitors = sortedMonitors
        guard let index = sortedMonitors.firstIndex(where: { $0.rect.topLeftCorner == prevMonitor.rect.topLeftCorner }) else { return }
        guard let targetMonitor = sortedMonitors.get(wrappingIndex: args.target == .next ? index + 1 : index - 1) else { return }

        if targetMonitor.setActiveWorkspace(focusedWorkspace) {
            let stubWorkspace = getStubWorkspace(for: prevMonitor)
            check(prevMonitor.setActiveWorkspace(stubWorkspace),
                "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)")
        } // todo else return exit code 1
    }
}
