import Common
import Darwin
import Foundation
import Socket

let usage =
    """
    USAGE: \(CommandLine.arguments.first ?? "aerospace") [-h|--help] [-v|--version] <subcommand> [<args>...]

    SUBCOMMANDS:
    \(subcommandDescriptions.sortedBy { $0[0] }.toPaddingTable(columnSeparator: "   ").joined(separator: "\n"))
    """

@main
struct Main {
    static func main() {
        let args: [String] = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            printStderr(usage)
            exit(1)
        }
        if args.first == "--help" || args.first == "-h" {
            print(usage)
            exit(0)
        }

        let isVersion: Bool = args.first == "--version" || args.first == "-v"
        var parsedArgs: (any CmdArgs)! = nil
        if !isVersion {
            switch parseCmdArgs(args) {
                case .cmd(let _parsedArgs):
                    parsedArgs = _parsedArgs
                case .help(let help):
                    print(help)
                    exit(0)
                case .failure(let e):
                    cliError(e)
            }
        }

        let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrDie()
        defer {
            socket.close()
        }

        let socketFile = "/tmp/\(aeroSpaceAppId)-\(unixUserName).sock"

        if let e: Error = Result(catching: { try socket.connect(to: socketFile) }).failureOrNil {
            if isVersion {
                printVersionAndExit(serverVersion: nil)
            } else {
                cliError("Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.localizedDescription)")
            }
        }

        var stdin = ""
        if (parsedArgs is WorkspaceCmdArgs || parsedArgs is MoveNodeToWorkspaceCmdArgs) && hasStdin() {
            if parsedArgs is WorkspaceCmdArgs && (parsedArgs as! WorkspaceCmdArgs).explicitStdinFlag == nil ||
                parsedArgs is MoveNodeToWorkspaceCmdArgs && (parsedArgs as! MoveNodeToWorkspaceCmdArgs).explicitStdinFlag == nil
            {
                cliError(
                    """
                    ERROR: Implicit stdin is detected (stdin is not TTY). Implicit stdin was forbidden in AeroSpace v0.20.0.
                    1. Please supply '--stdin' flag to make stdin explicit and preserve old AeroSpace behavior
                    2. You can also use '--no-stdin' flag to behave as if no stdin was supplied
                    Breaking change issue: https://github.com/nikitabobko/AeroSpace/issues/1683
                    """,
                )
            }
            var index = 0
            while let line = readLine(strippingNewline: false) {
                stdin += line
                index += 1
                if index > 1000 {
                    cliError("stdin number of lines limit is exceeded")
                }
            }
        }

        let ans = isVersion ? run(socket, [], stdin: stdin) : run(socket, args, stdin: stdin)
        if isVersion {
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
                """,
            )
        }
        exit(ans.exitCode)
    }
}

func printVersionAndExit(serverVersion: String?) -> Never {
    print(
        """
        aerospace CLI client version: \(cliClientVersionAndHash)
        AeroSpace.app server version: \(serverVersion ?? "Unknown. The server is not running")
        """,
    )
    exit(0)
}

func run(_ socket: Socket, _ args: [String], stdin: String) -> ServerAnswer {
    let request = Result { try JSONEncoder().encode(ClientRequest(args: args, stdin: stdin)) }.getOrDie()
    Result { try socket.write(from: request) }.getOrDie()
    Result { try Socket.wait(for: [socket], timeout: 0, waitForever: true) }.getOrDie()

    var answer = Data()
    Result { try socket.read(into: &answer) }.getOrDie()
    return Result { try JSONDecoder().decode(ServerAnswer.self, from: answer) }.getOrDie()
}
