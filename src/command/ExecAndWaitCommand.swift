struct ExecAndWaitCommand: Command {
    let args: ExecAndWaitCmdArgs

    func _run(_ subject: inout CommandSubject) {
        error("Please don't call _run, use run")
    }

    func _runWithContinuation(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        let process = Process()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = ["-c", args.bashScript]
        process.terminationHandler = { _ in
            check(Thread.current.isMainThread)
            refreshSession {
                var focused = CommandSubject.focused
                // todo preserve subject in "exec sessions" (when/if "exec sessions" appears)
                Array(commands[(index + 1)...]).run(&focused)
            }
        }
        // It doesn't throw if exit code is non-zero
        try! process.run()
    }
}
