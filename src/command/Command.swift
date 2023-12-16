protocol Command: AeroAny { // todo add exit code and messages
    func _run(_ subject: inout CommandSubject)
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

// There are 4 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
// 4. Tray icon buttons
extension [Command] {
    func run(_ subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        for (index, command) in withIndex {
            if TrayMenuModel.shared.isEnabled || command is EnableCommand {
                if let command = command as? ExecAndWaitCommand { // todo think of something more elegant
                    command._runWithContinuation(&subject, index, self)
                    break
                } else {
                    command._run(&subject)
                }
                refreshModel()
            }
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
