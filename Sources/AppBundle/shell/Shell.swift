import Common

indirect enum Shell<T> {
    case empty
    case cmd(T)

    // Listed in precedence order
    case pipe([Shell<T>])
    case and([Shell<T>])
    case or([Shell<T>])
    case seq([Shell<T>])

    static func newCompound(_ elems: [Self], _ constructor: ([Self]) -> Self) -> Self {
        switch elems.count {
            case 0: .empty
            case 1: elems.first.orDie()
            default: constructor(elems)
        }
    }

    func flatMap<R>(_ mapper: (T) -> ParsedCmd<R>) -> ParsedCmd<Shell<R>> {
        switch self {
            case .empty: return .cmd(.empty)
            case .cmd(let it): return mapper(it).map(Shell<R>.cmd)
            case .and(let it): return it.mapAllOrFailure { $0.flatMap(mapper) }.map(Shell<R>.and)
            case .or(let it): return it.mapAllOrFailure { $0.flatMap(mapper) }.map(Shell<R>.or)
            case .pipe(let it): return it.mapAllOrFailure { $0.flatMap(mapper) }.map(Shell<R>.pipe)
            case .seq(let it): return it.mapAllOrFailure { $0.flatMap(mapper) }.map(Shell<R>.seq)
        }
    }

    func flatten() -> [T] {
        switch self {
            case .empty: return []
            case .cmd(let it): return [it]
            case .and(let it): return it.flatMap { $0.flatten() }
            case .or(let it): return it.flatMap { $0.flatten() }
            case .pipe(let it): return it.flatMap { $0.flatten() }
            case .seq(let it): return it.flatMap { $0.flatten() }
        }
    }

    func buildDescription(_ stringifier: (T) -> String) -> String {
        let parentPrecedence = precedence
        func render(_ child: Shell<T>) -> String {
            let desc = child.buildDescription(stringifier)
            return child.precedence < parentPrecedence ? "(\(desc))" : desc
        }
        return switch self {
            case .empty: ""
            case .cmd(let cmd): stringifier(cmd)
            case .pipe(let it): it.map(render).joined(separator: " | ")
            case .and(let it): it.map(render).joined(separator: " && ")
            case .or(let it): it.map(render).joined(separator: " || ")
            case .seq(let it): it.map(render).joined(separator: "; ")
        }
    }

    private var precedence: Int {
        switch self {
            case .empty, .cmd: Int.max
            case .pipe: 4
            case .and: 3
            case .or: 2
            case .seq: 1
        }
    }
}

extension Shell: Equatable where T: Equatable {}
extension Shell: Sendable where T: Sendable {}

extension Shell where T == any Command {
    func strictEquals(_ other: Self) -> Bool {
        return switch (self, other) {
            case (.empty, .empty): true
            case (.cmd(let a), .cmd(let b)): a.equals(b)
            case (.and(let a), .and(let b)): zipIfCountsAreEqual(a, b)?.allSatisfy { a, b in a.strictEquals(b) } == true
            case (.or(let a), .or(let b)): zipIfCountsAreEqual(a, b)?.allSatisfy { a, b in a.strictEquals(b) } == true
            case (.pipe(let a), .pipe(let b)): zipIfCountsAreEqual(a, b)?.allSatisfy { a, b in a.strictEquals(b) } == true
            case (.seq(let a), .seq(let b)): zipIfCountsAreEqual(a, b)?.allSatisfy { a, b in a.strictEquals(b) } == true

            case (.empty, _): false
            case (.cmd, _): false
            case (.and, _): false
            case (.or, _): false
            case (.pipe, _): false
            case (.seq, _): false
        }
    }
}

// There are 4 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. on-window-detected callback
// 4. Tray icon buttons
extension Shell where T == any Command {
    @MainActor func run(_ env: CmdEnv, _ io: CmdIo) async -> Int32ExitCode {
        switch self {
            case .cmd(let command):
                let exitCode = Int32ExitCode(rawValue: await command.run(env, io).rawValue)
                if command.shouldResetClosedWindowsCache { resetClosedWindowsCache() }
                await refreshModel_nonCancellable()
                return exitCode
            case .and(let commands): return await runShellAnd(commands, env, io)
            case .empty: return Int32ExitCode(rawValue: EXIT_CODE_ZERO)
            case .or(let commands): return await runShellOr(commands, env, io)
            case .pipe(let commands): return await runShellPipe(commands, env, io)
            case .seq(let commands): return await runShellSeq(commands, env, io)
        }
    }

    @discardableResult @MainActor func run(_ env: CmdEnv, _ stdin: consuming CmdStdin) async -> CmdResult {
        let io: CmdIo = CmdIoImpl(stdin: stdin)
        let exitCode = await run(env, io)
        return CmdResult(stdout: io.stdout, stderr: io.stderr, exitCode: exitCode)
    }
}

@MainActor private func runShellOr(_ commands: [Shell<any Command>], _ env: CmdEnv, _ io: CmdIo) async -> Int32ExitCode {
    var exitCode = Int32ExitCode(rawValue: EXIT_CODE_TWO)
    for command in commands {
        exitCode = await command.run(env, io)
        if exitCode.rawValue == 0 { break }
    }
    return exitCode
}

@MainActor private func runShellAnd(_ commands: [Shell<any Command>], _ env: CmdEnv, _ io: CmdIo) async -> Int32ExitCode {
    var exitCode = Int32ExitCode(rawValue: EXIT_CODE_ZERO)
    for command in commands {
        exitCode = await command.run(env, io)
        if exitCode.rawValue != 0 { break }
    }
    return exitCode
}

@MainActor private func runShellSeq(_ commands: [Shell<any Command>], _ env: CmdEnv, _ io: CmdIo) async -> Int32ExitCode {
    var exitCode = Int32ExitCode(rawValue: EXIT_CODE_ZERO)
    for command in commands {
        exitCode = await command.run(env, io)
    }
    return exitCode
}

/// runs commands sequentially, buffering the entire stdout between them and joining with \n before re-feeding as stdin.
/// For long-running or streaming commands this would matter, but AeroSpace's commands are short and synchronous, so this is fine
///
/// The semantics is similar to 'set -o pipefail'
@MainActor private func runShellPipe(_ commands: [Shell<any Command>], _ env: CmdEnv, _ originalIo: CmdIo) async -> Int32ExitCode {
    var rightmostNonZeroExitCode = Int32ExitCode(rawValue: EXIT_CODE_ZERO)
    var io: CmdIo = CmdIoForwardingStdin(stdin: originalIo)
    var lastStdout = [String]()
    for command in commands {
        let exitCode = await command.run(env, io)
        originalIo.stderr += io.stderr
        lastStdout = io.stdout
        io = CmdIoImpl(stdin: .init(lastStdout.joined(separator: "\n")))
        if exitCode.rawValue != 0 {
            rightmostNonZeroExitCode = exitCode
        }
    }
    originalIo.out(lastStdout)
    return rightmostNonZeroExitCode
}
