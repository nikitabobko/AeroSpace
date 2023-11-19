struct MoveWorkspaceToMonitorCommand: Command {
    let monitorTarget: MonitorTarget

    enum MonitorTarget: String {
        case next, prev
    }

    func runWithoutLayout(state: inout FocusState) {
        check(Thread.current.isMainThread)
        let focusedWorkspace = state.workspace
        let prevMonitor = focusedWorkspace.monitor
        let sortedMonitors = sortedMonitors
        guard let index = sortedMonitors.firstIndex(where: { $0.rect.topLeftCorner == prevMonitor.rect.topLeftCorner }) else { return }
        let targetMonitor = sortedMonitors.get(wrappingIndex: monitorTarget == .next ? index + 1 : index - 1)

        if targetMonitor.setActiveWorkspace(focusedWorkspace) {
            let stubWorkspace = getStubWorkspace(for: prevMonitor)
            check(prevMonitor.setActiveWorkspace(stubWorkspace),
                "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)")
        } // todo else return exit code 1
    }
}
