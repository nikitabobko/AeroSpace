struct ExecAndWaitCommand: Command {
    let bashCommand: String

    func runWithoutLayout(state: inout FocusState) {
        error("Use runAsyncWithoutLayout for exec-and-wait")
    }

    func runAsyncWithoutLayout() async {
        check(Thread.current.isMainThread)
        await withCheckedContinuation { (continuation: CheckedContinuation<(), Never>) in
            let process = Process()
            process.executableURL = URL(filePath: "/bin/bash")
            process.arguments = ["-c", bashCommand]
            process.terminationHandler = { _ in
                continuation.resume()
            }
            // It doesn't throw if exit code is non-zero
            try! process.run()
        }
    }
}
