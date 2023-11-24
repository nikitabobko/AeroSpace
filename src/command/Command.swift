protocol Command: AeroAny { // todo add exit code and messages
    func runWithoutLayout(subject: inout CommandSubject)
}

protocol QueryCommand {
    func run() -> String
}

extension Command {
    func run() {
        check(Thread.current.isMainThread)
        [self].run()
    }

    var isExec: Bool { self is ExecAndWaitCommand || self is ExecAndForgetCommand }
}

// There are 3 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
extension [Command] {
    func run(_ initSubject: CommandSubject? = nil) { // todo make parameter mandatory
        check(Thread.current.isMainThread)
        // todo commands that come after enable must be run as well
        // todo what about disabled server for on-window-detected commands?
        let commands = TrayMenuModel.shared.isEnabled ? self : (singleOrNil() as? EnableCommand).asList()
        var subject: CommandSubject
        if let initSubject {
            subject = initSubject
        } else if let window = focusedWindow {
            subject = .window(window)
        } else {
            subject = .emptyWorkspace(focusedWorkspaceName)
        }
        for command in commands {
            command.runWithoutLayout(subject: &subject)
            refreshModel(startup: false)
        }
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
