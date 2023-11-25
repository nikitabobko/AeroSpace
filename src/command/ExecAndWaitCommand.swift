struct ExecAndWaitCommand: Command {
    let bashCommand: String

    func _run(_ subject: inout CommandSubject, _ index: Int, _ commands: [any Command]) {
        check(Thread.current.isMainThread)
        let process = Process()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = ["-c", bashCommand]
        process.terminationHandler = { _ in
            check(Thread.current.isMainThread)
            refreshSession {
                var focused = CommandSubject.focused
                Array(commands[(index + 1)...]).run(&focused) // todo preserve subject in "exec sessions"
            }
        }
        // It doesn't throw if exit code is non-zero
        try! process.run()
    }
}
