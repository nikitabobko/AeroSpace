import AppKit
import Common

struct ExecAndForgetCommand: Command {
    let args: ExecAndForgetCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        // todo shall exec-and-forget fork exec session?
        // It doesn't throw if exit code is non-zero
        let process = Process()
        process.environment = config.execConfig.envVariables + env.asMap
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = ["-c", args.bashScript]
        switch Result(catching: { try process.run() }) {
            case .success: return .succ
            case .failure(let e):
                // Don't die on transient spawn failures. Report the failure to the user instead
                // https://github.com/nikitabobko/AeroSpace/issues/1153
                let msg = """
                    Failed to run 'exec-and-forget' command:
                        \(args.bashScript)

                    Error: \(e.localizedDescription)
                    """
                _ = io.err(msg)
                reportCallbackError(msg)
                return .fail
        }
    }
}
