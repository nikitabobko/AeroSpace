protocol Command: AeroAny { // todo add exit code and messages
    func runWithoutLayout(state: inout FocusState)
}

protocol QueryCommand {
    @MainActor
    func run() -> String
}

extension Command {
    @MainActor
    func run() async {
        check(Thread.current.isMainThread)
        await [self].run()
    }

    var isExec: Bool { self is ExecAndWaitCommand || self is ExecAndForgetCommand }
}

extension [Command] {
    @MainActor
    func run(_ initState: FocusState? = nil) async {
        check(Thread.current.isMainThread)
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        refresh(layout: false)
        var state: FocusState
        if let initState {
            state = initState
        } else if let window = focusedWindowOrEffectivelyFocused, focusedWorkspaceSourceOfTruth == .macOs {
            state = .windowIsFocused(window)
        } else {
            state = .emptyWorkspaceIsFocused(focusedWorkspaceName)
        }
        for (index, command) in commands.withIndex {
            if let exec = command as? ExecAndWaitCommand {
                await exec.runAsyncWithoutLayout()
            } else {
                command.runWithoutLayout(state: &state)
            }
            if index != commands.indices.last {
                refresh(layout: false)
            }
        }
        state.window?.focus()
        refresh()
    }

    func _runSync(_ initState: FocusState? = nil) { // todo deduplicate
        check(Thread.current.isMainThread)
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        refresh(layout: false)
        var state: FocusState
        if let initState {
            state = initState
        } else if let window = focusedWindowOrEffectivelyFocused, focusedWorkspaceSourceOfTruth == .macOs {
            state = .windowIsFocused(window)
        } else {
            state = .emptyWorkspaceIsFocused(focusedWorkspaceName)
        }
        for (index, command) in commands.withIndex {
            command.runWithoutLayout(state: &state)
            if index != commands.indices.last {
                refresh(layout: false)
            }
        }
        state.window?.focus()
        refresh()
    }
}

enum FocusState {
    case emptyWorkspaceIsFocused(String)
    case windowIsFocused(Window)
}

extension FocusState {
    var window: Window? {
        switch self {
        case .windowIsFocused(let window):
            return window
        case .emptyWorkspaceIsFocused:
            return nil
        }
    }

    var workspace: Workspace {
        switch self {
        case .windowIsFocused(let window):
            return window.workspace
        case .emptyWorkspaceIsFocused(let workspaceName):
            return Workspace.get(byName: workspaceName)
        }
    }
}
