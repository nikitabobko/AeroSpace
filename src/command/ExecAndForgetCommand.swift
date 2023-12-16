struct ExecAndForgetCommand: Command {
    let args: ExecAndForgetCmdArgs

    func _run(_ subject: inout CommandSubject, _ stdout: inout String) -> Bool {
        // todo shall exec-and-forget fork exec session?
        check(Thread.current.isMainThread)
        // It doesn't throw if exit code is non-zero
        try! Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", args.bashScript])
        return true
    }
}
