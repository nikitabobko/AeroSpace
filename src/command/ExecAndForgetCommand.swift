struct ExecAndForgetCommand: Command {
    let bashCommand: String

    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        // It doesn't throw if exit code is non-zero
        try! Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
    }
}
