struct MoveWorkspaceToDisplayCommand: Command {
    let displayTarget: DisplayTarget

    enum DisplayTarget: String {
        case next, prev
    }

    func runWithoutLayout() {
        check(Thread.current.isMainThread)
        let focusedWorkspace = Workspace.focused
        let prevMonitor = focusedWorkspace.monitor
        let sortedMonitors = sortedMonitors
        guard let index = sortedMonitors.firstIndex(where: { $0.rect.topLeftCorner == prevMonitor.rect.topLeftCorner }) else { return }
        let targetMonitor = sortedMonitors.get(wrappingIndex: displayTarget == .next ? index + 1 : index - 1)

        if targetMonitor.setActiveWorkspace(focusedWorkspace) {
            let stubWorkspace = getStubWorkspace(for: prevMonitor)
            check(prevMonitor.setActiveWorkspace(stubWorkspace),
                "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)")
        } // todo else return exit code 1
    }
}
