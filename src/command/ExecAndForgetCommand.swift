struct ExecAndForgetCommand: Command {
    let bashCommand: String

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        // todo does it throw if exit code is non-zero?
        try! Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
    }
}
