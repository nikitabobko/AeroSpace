import Common

extension CmdArgs {
    @MainActor
    var workspace: Workspace? {
        if let workspaceName { Workspace.get(byName: workspaceName.raw) } else { nil }
    }

    @MainActor
    func resolveTargetOrReportError(_ env: CmdEnv, _ io: CmdIo) -> LiveFocus? {
        // Flags
        if let windowId {
            if let wi = Window.get(byId: windowId) {
                return wi.toLiveFocusOrReportError(io)
            } else {
                io.err("Invalid <window-id> \(windowId) passed to --window-id")
                return nil
            }
        }
        if let workspace {
            return workspace.toLiveFocus()
        }
        // Env
        if let windowId = env.windowId {
            if let wi = Window.get(byId: windowId) {
                return wi.toLiveFocusOrReportError(io)
            } else {
                io.err("Invalid <window-id> \(windowId) specified in \(AEROSPACE_WINDOW_ID) env variable")
                return nil
            }
        }
        if let wsName = env.workspaceName {
            return Workspace.get(byName: wsName).toLiveFocus()
        }
        // Real Focus
        return globalFocus
    }
}

extension Window {
    @MainActor
    func toLiveFocusOrReportError(_ io: CmdIo) -> LiveFocus? {
        if let result = toLiveFocusOrNil() {
            return result
        }
        // Minimized windows belong to no workspace and no monitor. As a command target they count as being on the
        // focused workspace, so that they can be moved out of the minimized state (e.g. move-node-to-workspace)
        if case .macosMinimizedWindowsContainer = windowParentCases {
            return LiveFocus(windowOrNil: self, workspace: globalFocus.workspace)
        }
        io.err("Window \(windowId) doesn't belong to any monitor. And thus can't even define a focused workspace")
        return nil
    }
}
