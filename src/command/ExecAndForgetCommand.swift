struct ExecAndForgetCommand: Command {
    let bashCommand: String

    func run() async {
        precondition(Thread.current.isMainThread)
        try! Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
    }
}
