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
        return .from(bool: Result { try process.run() }.isSuccess)
    }
}
