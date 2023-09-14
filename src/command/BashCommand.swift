struct BashCommand: Command {
    let bashCommand: String

    func run() {
        do {
            try Process.run(URL(filePath: "/bin/bash"), arguments: ["-c", bashCommand])
        } catch {
        }
    }
}
