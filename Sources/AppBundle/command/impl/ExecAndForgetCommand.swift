import AppKit
import Common

struct ExecAndForgetCommand: Command {
    let args: ExecAndForgetCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        // todo shall exec-and-forget fork exec session?
        check(Thread.current.isMainThread)
        // It doesn't throw if exit code is non-zero
        let process = Process()
        process.environment = config.execConfig.envVariables
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = ["-c", args.bashScript]
        return Result { try process.run() }.isSuccess
    }
}
