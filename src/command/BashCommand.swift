struct BashCommand: Command {
    let bashCommand: String

    func run() async {
        precondition(Thread.current.isMainThread)
        await withCheckedContinuation { (continuation: CheckedContinuation<(), Never>) in
            let process = Process()
            process.executableURL = URL(filePath: "/bin/bash")
            process.arguments = ["-c", bashCommand]
            process.terminationHandler = { _ in
                continuation.resume()
            }
            try! process.run()
        }
    }
}
