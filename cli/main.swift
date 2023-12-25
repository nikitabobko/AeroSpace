import Socket
import Foundation
import Common

initCli()

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
    let argsAsString = args.joined(separator: " ")

    switch parseCmdArgs(argsAsString) {
    case .cmd:
        break // Nothing to do
    case .help(let help):
        print(help)
        exit(0)
    case .failure(let e):
        print(e)
        exit(1)
    }

    let socket = tryCatch { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrThrow()
    defer {
        socket.close()
    }
    let socketFile = "/tmp/\(appId).sock"
    if let e: AeroError = tryCatch(body: { try socket.connect(to: socketFile) }).errorOrNil {
        prettyError("Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.msg)")
    }

    func run(_ command: String) -> (Int32, String) {
        tryCatch { try socket.write(from: command) }.getOrThrow()
        tryCatch { try Socket.wait(for: [socket], timeout: 0, waitForever: true) }.getOrThrow()
        let received: String = tryCatch { try socket.readString() }.getOrThrow()
            ?? prettyErrorT("fatal error: received nil from socket")
        let exitCode: Int32 = received.first.map { String($0) }.flatMap { Int32($0) } ?? 1
        let output = String(received.dropFirst())
        return (exitCode, output)
    }

    let (_, serverVersionAndHash) = run("version")
    if serverVersionAndHash.trim() != cliClientVersionAndHash.trim() {
        prettyError(
            """
            AeroSpace client/server version mismatch

            - aerospace CLI client version: \(cliClientVersionAndHash.trim())
            - AeroSpace.app server version: \(serverVersionAndHash.trim())

            Possible fixes:
            - Restart AeroSpace.app (restart is required after each update)
            - Reinstall and restart AeroSpace (corrupted installation)
            """
        )
    }

    let (exitCode, output) = run(argsAsString)

    print(output, terminator: "")
    exit(exitCode)
}
