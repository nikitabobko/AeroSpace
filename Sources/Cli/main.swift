import Common
import Darwin
import Foundation
import Socket

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

let usage =
    """
    USAGE: \(CommandLine.arguments.first ?? "aerospace") [-h|--help] [-v|--version] <subcommand> [<args>...]

    SUBCOMMANDS:
    \(subcommandDescriptions.sortedBy { $0[0] }.toPaddingTable(columnSeparator: "   ").joined(separator: "\n"))
    """
if args.isEmpty {
    printStderr(usage)
    exit(1)
}
if args.first == "--help" || args.first == "-h" {
    print(usage)
    exit(0)
}

let isVersion: Bool = args.first == "--version" || args.first == "-v"

if !isVersion {
    switch parseCmdArgs(args) {
        case .cmd:
            break
        case .help(let help):
            print(help)
            exit(0)
        case .failure(let e):
            cliError(e)
    }
}

let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrThrow()
defer {
    socket.close()
}
@MainActor func run(_ args: [String], stdin: String) -> ServerAnswer {
    let request = Result { try JSONEncoder().encode(ClientRequest(args: args, stdin: stdin)) }.getOrThrow()
    Result { try socket.write(from: request) }.getOrThrow()
    Result { try Socket.wait(for: [socket], timeout: 0, waitForever: true) }.getOrThrow()

    var answer = Data()
    Result { try socket.read(into: &answer) }.getOrThrow()
    return Result { try JSONDecoder().decode(ServerAnswer.self, from: answer) }.getOrThrow()
}
let socketFile = "/tmp/\(aeroSpaceAppId)-\(unixUserName).sock"

if let e: Error = Result(catching: { try socket.connect(to: socketFile) }).errorOrNil {
    if isVersion {
        printVersionAndExit(serverVersion: nil)
    } else {
        cliError("Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.localizedDescription)")
    }
}

var stdin = ""
if hasStdin() {
    var index = 0
    while let line = readLine(strippingNewline: false) {
        stdin += line
        index += 1
        if index > 1000 {
            cliError("stdin number of lines limit is exceeded")
        }
    }
}

let ans = isVersion ? run(["server-version-internal-command"], stdin: stdin) : run(args, stdin: stdin)
if ans.exitCode == 0 && isVersion {
    printVersionAndExit(serverVersion: ans.serverVersionAndHash)
}

if !ans.stdout.isEmpty { print(ans.stdout) }
if !ans.stderr.isEmpty { printStderr(ans.stderr) }
if ans.exitCode != 0 && ans.serverVersionAndHash != cliClientVersionAndHash {
    printStderr(
        """
        Warning: AeroSpace client/server versions don't match
            - aerospace CLI client version: \(cliClientVersionAndHash)
            - AeroSpace.app server version: \(ans.serverVersionAndHash)
            Possible fixes:
            - Restart AeroSpace.app (server restart is required after each update)
            - Reinstall and restart AeroSpace (corrupted installation)
        """
    )
}
exit(ans.exitCode)
