import AppKit
import Common

struct SummonWorkspaceCommand: Command {
    let args: SummonWorkspaceCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: args.target.val.raw)
        let onMonitor = monitors.first { $0.activeWorkspace == workspace }
        if onMonitor != nil {
            io.err("Workspace '\(workspace.name)' is already visible on a monitor, returning")
            return !args.failIfNoop
        }

        let monitor = focus.workspace.forceAssignedMonitor ?? focus.workspace.workspaceMonitor
        if monitor.activeWorkspace == workspace {
            io.err("Workspace '\(workspace.name)' is already visible on the focused monitor. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }

        if isValidAssignment(workspace: workspace, monitor: monitor) {
            _ = monitor.setActiveWorkspace(workspace)
            return monitor.activeWorkspace.focusWorkspace()
        } else {
            return workspace.forceAssignedMonitor?.setActiveWorkspace(workspace) != nil
        }
    }
}
