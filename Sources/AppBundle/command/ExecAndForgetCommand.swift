import AppKit
import Common

struct ExecAndForgetCommand: Command {
    let args: ExecAndForgetCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        // todo shall exec-and-forget fork exec session?
        check(Thread.current.isMainThread)
        // It doesn't throw if exit code is non-zero
        let process = Process()
        process.environment = config.execConfig.envVariables
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = ["-c", args.bashScript]
        Result { try process.run() }.getOrThrow()
        return true
    }
}
