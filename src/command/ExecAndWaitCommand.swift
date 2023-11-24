struct ExecAndWaitCommand: Command {
    let bashCommand: String

    func runWithoutLayout(subject: inout CommandSubject) {
        check(Thread.current.isMainThread)
        // todo drop async await and run new session instead
        error("TODO")
        //await withCheckedContinuation { (continuation: CheckedContinuation<(), Never>) in
            let process = Process()
            process.executableURL = URL(filePath: "/bin/bash")
            process.arguments = ["-c", bashCommand]
            process.terminationHandler = { _ in
                //continuation.resume()
            }
            // It doesn't throw if exit code is non-zero
            try! process.run()
        //}
    }
}
