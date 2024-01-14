import Common

protocol Command: AeroAny {
    associatedtype T where T: CmdArgs
    var args: T { get }
    func _run(_ state: CommandMutableState, stdin: String) -> Bool
}

extension Command {
    var info: CmdStaticInfo { T.info }
}

class CommandMutableState {
    var subject: CommandSubject
    var stdout: [String] = []
    var stderr: [String] = []

    public init(_ subject: CommandSubject) {
        self.subject = subject
    }

    static var focused: CommandMutableState { CommandMutableState(.focused) }
}

extension Command {
    @discardableResult
    func run(_ state: CommandMutableState, stdin: String = "") -> Bool {
        check(Thread.current.isMainThread)
        return [self]._run(state, stdin: stdin)
    }

    var isExec: Bool { self is ExecAndForgetCommand }
}

// There are 4 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
// 4. Tray icon buttons
extension [Command] {
    func run(_ state: CommandMutableState) -> Bool {
        _run(state, stdin: "")
    }

    // fileprivate because don't want to expose an interface where a bunch of commands have shared stdin
    fileprivate func _run(_ state: CommandMutableState, stdin: String = "") -> Bool {
        check(Thread.current.isMainThread)
        check(self.count == 1 || stdin == "")
        var result = true
        for command in self {
            if TrayMenuModel.shared.isEnabled || isAllowedToRunWhenDisabled(command) {
                result = command._run(state, stdin: stdin) && result
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
