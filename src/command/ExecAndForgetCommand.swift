import Common

struct ExecAndForgetCommand: Command {
    let info: CmdStaticInfo = ExecAndForgetCmdArgs.info
    let args: ExecAndForgetCmdArgs

    func _run(_ subject: inout CommandSubject, stdin: String, stdout: inout [String]) -> Bool {
        // todo shall exec-and-forget fork exec session?
        check(Thread.current.isMainThread)
        // It doesn't throw if exit code is non-zero
        tryCatch { try Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", args.bashScript]) }
            .getOrThrow()
        return true
    }
}
