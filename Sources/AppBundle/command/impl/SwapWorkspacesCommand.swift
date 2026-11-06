import Common

struct SwapWorkspacesCommand: Command {
    let args: SwapWorkspacesCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let a = Workspace.get(byName: args.workspaceA.val.raw)
        let b = Workspace.get(byName: args.workspaceB.val.raw)
        if a == b { return .fail(io.err("Can't swap workspace \(a.name.singleQuoted) with itself")) }
        let focusedWorkspace = globalFocus.workspace

        // Everything a workspace holds is a direct child of it: the root tiling container, the floating windows container,
        // and the containers of macOS fullscreen windows and windows of hidden apps. Exchange them all, so the layouts travel too
        let aMostRecent = a.mostRecentChild
        let bMostRecent = b.mostRecentChild
        let aChildren = a.children.map { ($0, $0.unbindFromParent()) }
        let bChildren = b.children.map { ($0, $0.unbindFromParent()) }
        for (child, binding) in aChildren {
            child.bind(to: b, adaptiveWeight: binding.adaptiveWeight, index: INDEX_BIND_LAST)
        }
        for (child, binding) in bChildren {
            child.bind(to: a, adaptiveWeight: binding.adaptiveWeight, index: INDEX_BIND_LAST)
        }
        // bind marks every bound child as the most recent one. Restore the real order, so the focus lands where it used to
        aMostRecent?.markAsMostRecentChild()
        bMostRecent?.markAsMostRecentChild()

        // The user stays on the workspace they were on, and sees its new contents
        return .from(bool: focusedWorkspace.focusWorkspace())
    }
}
