import Socket
import Foundation

let args: [String] = Array(CommandLine.arguments.dropFirst())

for arg in args {
    if arg.contains(" ") {
        error("Spaces in arguments are not permitted. '\(arg)' argument contains spaces.")
    }
}

let usage =
    """
    USAGE: \(CommandLine.arguments.first ?? "aerospace") COMMAND

    See https://github.com/nikitabobko/AeroSpace/blob/main/docs/commands.md for the list of all available commands
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
        errorT("Can't connect to AeroSpace server. Is AeroSpace.app running?")

    func run(_ command: String) -> String {
        try! socket.write(from: command)
        _ = try! Socket.wait(for: [socket], timeout: 0, waitForever: true)
        return try! socket.readString() ?? errorT("fatal error: received nil from socket")
    }

    let serverVersionAndHash = run("version")
    if serverVersionAndHash != cliClientVersionAndHash {
        error(
            """
            Corrupted AeroSpace installation

            - CLI client version: \(cliClientVersionAndHash)
            - AeroSpace.app server version: \(serverVersionAndHash)

            The versions don't match. Please reinstall AeroSpace
            """
        )
    }

    let output = run(args.joined(separator: " "))
    if output != "PASS" {
        print(output)
    }
}
