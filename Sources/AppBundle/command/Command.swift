import AppKit
import Common

/// A unit of executable behaviour in AeroSpace.
///
/// Each user-facing command (e.g. `focus`, `move`, `workspace`) conforms to
/// this protocol. Commands are parsed from config keybindings, CLI requests,
/// `on-window-detected` callbacks, and tray icon buttons.
///
/// To add a new command:
/// 1. Create a `CmdArgs` struct that describes its parsed arguments.
/// 2. Conform your command type to `Command` and implement `run(_:_:)`.
/// 3. Register it in `cmdManifest.swift`.
protocol Command: AeroAny, Equatable, Sendable {
    associatedtype T where T: CmdArgs
    /// The parsed arguments supplied to this command invocation.
    var args: T { get }
    /// Executes the command and returns `true` on success.
    ///
    /// - Parameters:
    ///   - env: The ambient environment (focused window, workspace, etc.)
    ///   - io: I/O streams for stdout/stderr output.
    /// - Returns: `true` if the command completed successfully.
    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool

    /// Whether running this command should invalidate the closed-windows cache.
    ///
    /// Set to `true` for any command that may modify the window tree
    /// (e.g. moving windows, changing layouts). The cache is cleared
    /// automatically after the command completes when this is `true`.
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
    func runCmdSeq(_ env: CmdEnv, _ io: sending CmdIo) async throws -> Bool {
        var isSucc = true
        for command in self {
            isSucc = try await command.run(env, io) && isSucc
            if command.shouldResetClosedWindowsCache { resetClosedWindowsCache() }
            refreshModel()
        }
        return isSucc
    }

    @MainActor
    func runCmdSeq(_ env: CmdEnv, _ stdin: consuming CmdStdin) async throws -> CmdResult {
        let io: CmdIo = CmdIo(stdin: stdin)
        let isSucc = try await runCmdSeq(env, io)
        return CmdResult(stdout: io.stdout, stderr: io.stderr, exitCode: isSucc ? 0 : 1)
    }
}
