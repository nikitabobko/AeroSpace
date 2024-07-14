import AppKit
import Common

struct FlattenWorkspaceTreeCommand: Command {
    let args = FlattenWorkspaceTreeCmdArgs(rawArgs: [])

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        guard let focus = args.resolveFocusOrReportError(env, io) else { return false }
        let workspace = focus.workspace
        let windows = workspace.rootTilingContainer.allLeafWindowsRecursive
        for window in windows {
            window.bind(to: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
        return true
    }
}
