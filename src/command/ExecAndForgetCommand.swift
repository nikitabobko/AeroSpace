struct ExecAndForgetCommand: Command {
    let bashCommand: String

    func runWithoutRefresh() {
        precondition(Thread.current.isMainThread)
        try! Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
    }
}
