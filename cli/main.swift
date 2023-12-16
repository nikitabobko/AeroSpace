import Socket
import Foundation

let args: [String] = Array(CommandLine.arguments.dropFirst())

for arg in args {
    if arg.contains(" ") {
        prettyError("Spaces in arguments are not permitted. '\(arg)' argument contains spaces.")
    }
}

let usage =
    """
    usage: \(CommandLine.arguments.first ?? "aerospace") [-h|--help] [-v|--version] <command> [<args>...]

    For the list of all available commands see:
    - https://github.com/nikitabobko/AeroSpace/blob/main/docs/commands.md
    - https://github.com/nikitabobko/AeroSpace/blob/main/docs/cli-commands.md
    """
if args.isEmpty || args.first == "--help" || args.first == "-h" {
    print(usage)
} else {
    let socket = try! Socket.create(family: .unix, type: .stream, proto: .unix)
    defer {
        socket.close()
    }
    let socketFile = "/tmp/\(appId).sock"
    (try? socket.connect(to: socketFile)) ??
        prettyErrorT("Can't connect to AeroSpace server. Is AeroSpace.app running?")

    func run(_ command: String) -> String {
        try! socket.write(from: command)
        _ = try! Socket.wait(for: [socket], timeout: 0, waitForever: true)
        return try! socket.readString() ?? prettyErrorT("fatal error: received nil from socket")
    }

    let serverVersionAndHash = run("version")
    if serverVersionAndHash != cliClientVersionAndHash {
        prettyError(
            """
            AeroSpace client/server version mismatch

            - aerospace CLI client version: \(cliClientVersionAndHash)
            - AeroSpace.app server version: \(serverVersionAndHash)

            Possible fixes:
            - Restart AeroSpace.app (restart is required after each update)
            - Reinstall and restart AeroSpace (corrupted installation)
            """
        )
    }

    let received = run(args.joined(separator: " "))
    let exitCode: Int32 = received.first.map { String($0) }.flatMap { Int32($0) } ?? 1
    let output = String(received.dropFirst())

    print(output, terminator: "")
    exit(exitCode)
}
