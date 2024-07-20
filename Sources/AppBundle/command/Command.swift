import AppKit
import Common

protocol Command: AeroAny, Equatable {
    associatedtype T where T: CmdArgs
    var args: T { get }
    func _run(_ state: CommandMutableState, stdin: String) -> Bool
}

extension Command {
    static func == (lhs: any Command, rhs: any Command) -> Bool {
        return lhs.args.equals(rhs.args)
    }

    func equals(_ other: any Command) -> Bool {
        (other as? Self).flatMap { self == $0 } ?? false
    }
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
    static var doesntMatter: CommandMutableState = focused
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

    // fileprivate because don't want to expose an interface where a more than one commands have shared stdin
    fileprivate func _run(_ state: CommandMutableState, stdin: String = "") -> Bool {
        check(Thread.current.isMainThread)
        check(self.count == 1 || stdin.isEmpty)
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
    static var focused: CommandSubject { focus.asLeaf.asCommandSubject }
}

extension EffectiveLeaf {
    var asCommandSubject: CommandSubject {
        switch focus.asLeaf {
            case .window(let w): .window(w)
            case .emptyWorkspace(let w): .emptyWorkspace(w.name)
        }
    }
}

extension CommandSubject {
    var windowOrNil: Window? {
        return switch self {
            case .window(let window): window
            case .emptyWorkspace: nil
        }
    }

    var workspace: Workspace {
        return switch self {
            case .window(let window): window.visualWorkspace ?? focus.workspace
            case .emptyWorkspace(let workspaceName): Workspace.get(byName: workspaceName)
        }
    }
}

extension CommandMutableState {
    func failCmd(msg: String) -> Bool {
        stderr.append(msg)
        return false
    }

    func succCmd(msg: String) -> Bool {
        stdout.append(msg)
        return true
    }
}
