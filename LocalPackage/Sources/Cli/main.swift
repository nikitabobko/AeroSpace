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
    if arg.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
        prettyError("Whitespace chars in arguments are not permitted. '\(arg)' argument contains whitespace chars.")
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

let isVersion: Bool = args.first == "--version" || args.first == "-v"

let argsAsString = args.joined(separator: " ")

if !isVersion {
    switch parseCmdArgs(argsAsString) {
    case .cmd(let cmdArgs):
        break
    case .help(let help):
        print(help)
        exit(0)
    case .failure(let e):
        print(e)
        exit(1)
    }
}

let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrThrow()
defer {
    socket.close()
}
let socketFile = "/tmp/\(appId).sock"

if let e: Error = Result(catching: { try socket.connect(to: socketFile) }).errorOrNil {
    if isVersion {
        printVersionAndExit(serverVersion: nil)
    } else {
        prettyError("Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.localizedDescription)")
    }
}

func run(_ command: String, stdin: String) -> ServerAnswer {
    let request = Result { try JSONEncoder().encode(ClientRequest(command: command, stdin: stdin)) }.getOrThrow()
    Result { try socket.write(from: request) }.getOrThrow()
    Result { try Socket.wait(for: [socket], timeout: 0, waitForever: true) }.getOrThrow()

    var answer = Data()
    Result { try socket.read(into: &answer) }.getOrThrow()
    return Result { try JSONDecoder().decode(ServerAnswer.self, from: answer) }.getOrThrow()
}

let serverVersionAns = run("server-version-internal-command", stdin: "")
if serverVersionAns.exitCode != 0 {
    prettyError(
        """
        Client-server miscommunication error.

        Server stdout: \(serverVersionAns.stdout)
        Server stderr: \(serverVersionAns.stderr)

        Possible cause: client/server version mismatch

        Possible fixes:
        - Restart AeroSpace.app (restart is required after each update)
        - Reinstall and restart AeroSpace (corrupted installation)
        """
    )
}
if serverVersionAns.stdout != cliClientVersionAndHash {
    prettyError(
        """
        AeroSpace client/server version mismatch

        - aerospace CLI client version: \(cliClientVersionAndHash)
        - AeroSpace.app server version: \(serverVersionAns.stdout)

        Possible fixes:
        - Restart AeroSpace.app (restart is required after each update)
        - Reinstall and restart AeroSpace (corrupted installation)
        """
    )
}

if isVersion {
    printVersionAndExit(serverVersion: serverVersionAns.stdout)
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

let ans = run(argsAsString, stdin: stdin)

if !ans.stdout.isEmpty { print(ans.stdout) }
if !ans.stderr.isEmpty { printStderr(ans.stderr) }
exit(ans.exitCode)
