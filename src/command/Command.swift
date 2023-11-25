protocol Command: AeroAny { // todo add exit code and messages
    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command])
}

protocol QueryCommand {
    func run() -> String
}

extension Command {
    func run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        [self].run(&subject)
    }

    func runOnFocusedSubject() {
        var focused = CommandSubject.focused
        run(&focused)
    }

    var isExec: Bool { self is ExecAndWaitCommand || self is ExecAndForgetCommand }
}

// There are 3 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
extension [Command] {
    func run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        // todo commands that come after enable must be run as well
        // todo what about disabled server for on-window-detected commands?
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        for (index, command) in commands.withIndex {
            command._run(&subject, index, self)
            refreshModel(startup: false)
        }
    }
}

enum CommandSubject {
    case emptyWorkspace(String)
    case window(Window)

    static var focused: CommandSubject {
        if let window = focusedWindow {
            return .window(window)
        } else {
            return .emptyWorkspace(focusedWorkspaceName)
        }
    }
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
