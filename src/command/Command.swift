protocol Command: AeroAny { // todo add exit code and messages
    func runWithoutLayout(subject: inout CommandSubject)
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
    func run(_ initState: CommandSubject? = nil) async {
        check(Thread.current.isMainThread)
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        refresh(layout: false)
        var subject: CommandSubject
        if let initState {
            subject = initState
        } else if let window = focusedWindow {
            subject = .window(window)
        } else {
            subject = .emptyWorkspace(focusedWorkspaceName)
        }
        for (index, command) in commands.withIndex {
            if let exec = command as? ExecAndWaitCommand {
                await exec.runAsyncWithoutLayout()
            } else {
                command.runWithoutLayout(subject: &subject)
            }
            if index != commands.indices.last {
                refresh(layout: false)
            }
        }
        refresh()
    }

    func _runSync(_ initState: CommandSubject? = nil) { // todo deduplicate
        check(Thread.current.isMainThread)
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        refresh(layout: false)
        var subject: CommandSubject
        if let initState {
            subject = initState
        } else if let window = focusedWindow {
            subject = .window(window)
        } else {
            subject = .emptyWorkspace(focusedWorkspaceName)
        }
        for (index, command) in commands.withIndex {
            command.runWithoutLayout(subject: &subject)
            if index != commands.indices.last {
                refresh(layout: false)
            }
        }
        refresh()
    }
}

enum CommandSubject {
    case emptyWorkspace(String)
    case window(Window)
}

extension CommandSubject {
    var windowOrNil: Window? {
        switch self {
        case .window(let window):
            return window
        case .emptyWorkspace:
            return nil
        }
    }

    var workspace: Workspace {
        switch self {
        case .window(let window):
            return window.workspace
        case .emptyWorkspace(let workspaceName):
            return Workspace.get(byName: workspaceName)
        }
    }
}
