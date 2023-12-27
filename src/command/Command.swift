import Common

protocol Command: AeroAny {
    var info: CmdStaticInfo { get }
    func _run(_ subject: inout CommandSubject, stdin: String, stdout: inout [String]) -> Bool
}

extension Command {
    func run(_ subject: inout CommandSubject, stdin: String = "", stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        return [self]._run(&subject, stdin: stdin, stdout: &stdout)
    }

    func runOnFocusedSubject() {
        check(Thread.current.isMainThread)
        var focused = CommandSubject.focused
        var devNull: [String] = []
        _ = run(&focused, stdout: &devNull)
    }

    var isExec: Bool { self is ExecAndForgetCommand }
}

// There are 4 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
// 4. Tray icon buttons
extension [Command] {
    func run(_ subject: inout CommandSubject) -> Bool {
        var devNull: [String] = []
        return _run(&subject, stdin: "", stdout: &devNull)
    }

    fileprivate func _run(_ subject: inout CommandSubject, stdin: String = "", stdout: inout [String]) -> Bool {
        check(Thread.current.isMainThread)
        check(self.count == 1 || stdin == "")
        var result = true
        for command in self {
            if TrayMenuModel.shared.isEnabled || command is EnableCommand {
                result = command._run(&subject, stdin: stdin, stdout: &stdout) && result
                refreshModel()
            }
        }
        return result
    }
}

enum CommandSubject: Equatable {
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
