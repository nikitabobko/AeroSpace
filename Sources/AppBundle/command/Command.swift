import AppKit
import Common

protocol Command: AeroAny, Equatable, Sendable {
    associatedtype T: CmdArgs

    var args: T { get }
    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> T.ExitCodeType

    /// We should reset closedWindowsCache when the command can potentially change the tree
    var shouldResetClosedWindowsCache: Bool { get }
}

extension Command {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.args.equals(rhs.args)
    }

    nonisolated func equals(_ other: any Command) -> Bool {
        (other as? Self).flatMap { self == $0 } ?? false
    }
}

extension Command {
    var info: CmdStaticInfo { T.info }
}

extension Command {
    @MainActor
    @discardableResult
    func run(_ env: CmdEnv, _ stdin: consuming CmdStdin) async throws -> CmdResult {
        return try await [self].runCmdSeq(env, stdin)
    }

    var isExec: Bool { self is ExecAndForgetCommand }
}

// There are 4 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
// 4. Tray icon buttons
extension [Command] {
    @MainActor
    func runCmdSeq(_ env: CmdEnv, _ io: sending CmdIo) async throws -> Int32ExitCode {
        var exitCode = Int32ExitCode(rawValue: EXIT_CODE_ZERO)
        for command in self {
            exitCode = Int32ExitCode(rawValue: (try await command.run(env, io)).rawValue)
            if command.shouldResetClosedWindowsCache { resetClosedWindowsCache() }
            refreshModel()
        }
        return exitCode
    }

    @MainActor
    func runCmdSeq(_ env: CmdEnv, _ stdin: consuming CmdStdin) async throws -> CmdResult {
        let io: CmdIo = CmdIo(stdin: stdin)
        let exitCode = try await runCmdSeq(env, io)
        return CmdResult(stdout: io.stdout, stderr: io.stderr, exitCode: exitCode)
    }
}
