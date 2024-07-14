import AppKit
import Common

protocol Command: AeroAny, Equatable {
    associatedtype T where T: CmdArgs
    var args: T { get }
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool
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

extension Command {
    @discardableResult
    func run(_ env: CmdEnv, _ stdin: CmdStdin) -> CmdResult {
        check(Thread.current.isMainThread)
        return [self].runCmdSeq(env, stdin)
    }

    var isExec: Bool { self is ExecAndForgetCommand }
}

// There are 4 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
// 4. Tray icon buttons
extension [Command] {
    func runCmdSeq(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        var isSucc = true
        for command in self {
            if TrayMenuModel.shared.isEnabled || isAllowedToRunWhenDisabled(command) {
                isSucc = command.run(env, io) && isSucc
                refreshModel()
            }
        }
        return isSucc
    }

    func runCmdSeq(_ env: CmdEnv, _ stdin: CmdStdin) -> CmdResult {
        let io: CmdIo = CmdIo(stdin: stdin)
        let isSucc = runCmdSeq(env, io)
        return CmdResult(stdout: io.stdout, stderr: io.stderr, exitCode: isSucc ? 0 : 1)
    }
}
