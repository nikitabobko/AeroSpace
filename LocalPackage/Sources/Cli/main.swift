import Socket
import Foundation
import Common
import Darwin

initCli()

func printVersionAndExit(serverVersion: String?) -> Never {
    print(
        """
        aerospace CLI client version: \(cliClientVersionAndHash)
        AeroSpace.app server version: \(serverVersion ?? "Unknown. The server is not running")
        """
    )
    exit(0)
}

let args: [String] = Array(CommandLine.arguments.dropFirst())

for arg in args {
    if arg.contains(" ") || arg.contains("\n") {
        prettyError("Spaces and newlines in arguments are not permitted. '\(arg)' argument contains either of them.")
    }
}

let usage =
    """
    usage: \(CommandLine.arguments.first ?? "aerospace") [-h|--help] [-v|--version] <subcommand> [<args>...]

    Subcommands:
    \(subcommandDescriptions.sortedBy { $0[0] }.toPaddingTable(columnSeparator: "   ").joined(separator: "\n"))
    """
if args.isEmpty || args.first == "--help" || args.first == "-h" {
    print(usage)
    exit(args.isEmpty ? 1 : 0)
}

let argsAsString = args.joined(separator: " ")

let isVersion: Bool
switch parseCmdArgs(argsAsString) {
case .cmd(let cmdArgs):
    isVersion = cmdArgs is VersionCmdArgs
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
    if isVersion {
        printVersionAndExit(serverVersion: nil)
    } else {
        prettyError("Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.msg)")
    }
}

func run(_ command: String, stdin: String) -> (Int32, String) {
    tryCatch { try socket.write(from: command + "\n" + stdin) }.getOrThrow()
    tryCatch { try Socket.wait(for: [socket], timeout: 0, waitForever: true) }.getOrThrow()
    let received: String = tryCatch { try socket.readString() }.getOrThrow()
        ?? prettyErrorT("fatal error: received nil from socket")
    let exitCode: Int32 = received.first.map { String($0) }.flatMap { Int32($0) } ?? 1
    let output = String(received.dropFirst())
    return (exitCode, output)
}

let (internalExitCode, serverVersionAndHash) = run("version", stdin: "")
if internalExitCode != 0 {
    prettyError(
        """
        Client-server miscommunication error: \(serverVersionAndHash)

        Possible cause: client/server version mismatch

        Possible fixes:
        - Restart AeroSpace.app (restart is required after each update)
        - Reinstall and restart AeroSpace (corrupted installation)
        """
    )
}
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

if isVersion {
    printVersionAndExit(serverVersion: serverVersionAndHash)
}

var stdin = ""
if hasStdin() {
    var index = 0
    while let line = readLine(strippingNewline: false) {
        stdin += line
        index += 1
        if index > 1000 {
            prettyError("stdin number of lines limit is exceeded")
        }
    }
}

let (exitCode, output) = run(argsAsString, stdin: stdin)

if !output.isEmpty {
    print(output)
}
exit(exitCode)
