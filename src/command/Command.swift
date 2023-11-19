protocol Command: AeroAny { // todo add exit code and messages
    @MainActor
    func runWithoutLayout(state: inout FocusState) async
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
}

extension [Command] {
    @MainActor
    func run() async {
        check(Thread.current.isMainThread)
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        refresh(layout: false)
        var state: FocusState
        if let window = focusedWindowOrEffectivelyFocused {
            state = .windowIsFocused(window)
        } else {
            state = .emptyWorkspaceIsFocused(focusedWorkspaceName)
        }
        for (index, command) in commands.withIndex {
            await command.runWithoutLayout(state: &state)
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
