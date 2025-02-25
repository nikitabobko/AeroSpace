import AppKit
import Common

struct SummonWorkspaceCommand: Command {
    let args: SummonWorkspaceCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        let workspace = Workspace.get(byName: args.target.val.raw)
        let focusedMonitor = focus.workspace.workspaceMonitor

        if focusedMonitor.activeWorkspace == workspace {
            io.err("Workspace '\(workspace.name)' is already visible on the focused monitor. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }

        if !workspace.isVisible {
            // then we just need to summon the workspace to the focused monitor
            if focusedMonitor.setActiveWorkspace(workspace) {
                return workspace.focusWorkspace()
            } else {
                return io.err("Can't move workspace '\(workspace.name)' to monitor '\(focusedMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it")
            }
        } else {
            let otherMonitor = workspace.workspaceMonitor
            let currentWorkspace = focusedMonitor.activeWorkspace

            switch args.whenVisible {
                case .swap:
                    if otherMonitor.setActiveWorkspace(currentWorkspace) && focusedMonitor.setActiveWorkspace(workspace) {
                        return workspace.focusWorkspace()
                    } else {
                        return io.err("Can't swap workspaces due to monitor force assignment restrictions")
                    }
                case .focus:
                    return workspace.focusWorkspace()
            }
        }
    }
}
