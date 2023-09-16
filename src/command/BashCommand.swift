struct BashCommand: Command {
    let bashCommand: String

    func run() {
        let process = try! Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
        process.waitUntilExit()
    }
}
