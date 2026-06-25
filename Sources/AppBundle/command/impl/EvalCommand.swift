import Common

struct EvalCommand: Command {
    let args: EvalCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> Int32ExitCode {
        switch parseCommand(args.shellExpr.val, allowExecAndForget: false, allowEval: false) {
            case .failure(let cmdParsingFailure):
                io.err(cmdParsingFailure.msg)
                return Int32ExitCode(rawValue: cmdParsingFailure.exitCode)
            case .help:
                io.err("--help is not supported inside eval command")
                return .init(rawValue: EXIT_CODE_TWO)
            case .cmd(let cmd):
                return await cmd.run(env, io)
        }
    }
}
