struct MoveWorkspaceToDisplayCommand: Command {
    let displayTarget: DisplayTarget

    enum DisplayTarget: String {
        case next, prev
    }

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        Workspace.focused
        sortedMonitors
    }
}
