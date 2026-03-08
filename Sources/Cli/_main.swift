import Common
import Darwin
import Foundation
import Network

let usage =
    """
    USAGE: \(CommandLine.arguments.first ?? "aerospace") [-h|--help] [-v|--version] <subcommand> [<args>...]

    SUBCOMMANDS:
    \(subcommandDescriptions.sortedBy { $0[0] }.toPaddingTable(columnSeparator: "   ").joined(separator: "\n"))
    """

@main
struct Main {
    static func main() async {
        let args = CommandLine.arguments.slice(1...) ?? []

        if args.isEmpty {
            exit(1, err: usage)
        }
        if args.first == "--help" || args.first == "-h" {
            exit(0, out: usage)
        }

        if args.first == "--version" || args.first == "-v" {
            let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)
            let serverVersionAndHash: String?
            if await connection.startBlocking().error == nil {
                let ans = await run(connection, [], stdin: "", windowId: nil, workspace: nil)
                serverVersionAndHash = ans.serverVersionAndHash
            } else {
                serverVersionAndHash = nil
            }
            print(
                """
                aerospace CLI client version: \(cliClientVersionAndHash)
                AeroSpace.app server version: \(serverVersionAndHash ?? "Unknown. The server is not running")
                """,
            )
            if serverVersionAndHash != nil && cliClientVersionAndHash != serverVersionAndHash {
                eprint(
                    """
                    Warning: AeroSpace client/server versions don't match. Possible fixes:
                      - Restart AeroSpace.app (server restart is required after each update)
                      - Reinstall and restart AeroSpace (corrupted installation)
                    """,
                )
            }
            exit(0)
        }

        let parsedArgs: any CmdArgs
        switch parseCmdArgs(args) {
            case .cmd(let _parsedArgs):
                parsedArgs = _parsedArgs
            case .help(let help):
                exit(0, out: help)
            case .failure(let e):
                exit(1, err: e)
        }

        let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)

        if let e = await connection.startBlocking().error {
            exit(1, err: "Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.localizedDescription)")
        }

        var stdin = ""
        if (parsedArgs is WorkspaceCmdArgs && (parsedArgs as! WorkspaceCmdArgs).target.val.isRelatve
            || parsedArgs is MoveNodeToWorkspaceCmdArgs && (parsedArgs as! MoveNodeToWorkspaceCmdArgs).target.val.isRelatve)
            && hasStdin()
        {
            if parsedArgs is WorkspaceCmdArgs && (parsedArgs as! WorkspaceCmdArgs).explicitStdinFlag == nil ||
                parsedArgs is MoveNodeToWorkspaceCmdArgs && (parsedArgs as! MoveNodeToWorkspaceCmdArgs).explicitStdinFlag == nil
            {
                exit(
                    1,
                    err: """
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
                    exit(1, err: "stdin number of lines limit is exceeded")
                }
            }
        }

        let windowId = ProcessInfo.processInfo.environment[AEROSPACE_WINDOW_ID].flatMap(UInt32.init)
        let workspace = ProcessInfo.processInfo.environment[AEROSPACE_WORKSPACE]

        // Handle subscribe command specially
        if parsedArgs is SubscribeCmdArgs {
            await runSubscribe(connection, args, windowId: windowId, workspace: workspace)
            exit(0) // Should not reach here
        }

        let ans = await run(connection, args, stdin: stdin, windowId: windowId, workspace: workspace)

        if !ans.stdout.isEmpty { print(ans.stdout) }
        if !ans.stderr.isEmpty { eprint(ans.stderr) }
        if ans.exitCode != 0 && ans.serverVersionAndHash != cliClientVersionAndHash {
            eprint(
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

func runSubscribe(_ connection: NWConnection, _ args: StrArrSlice, windowId: UInt32?, workspace: String?) async {
    if let e = await connection.writeAtomic(ClientRequest(args: args.toArray(), stdin: "", windowId: windowId, workspace: workspace)).error {
        exit(1, err: "Failed to write to server socket: \(e)")
    }

    while true {
        switch await connection.readNonAtomic() {
            case .success(let data):
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                } else {
                    exit(1, err: "Can't convert bytes to utf8 String")
                }
            case .failure(let e):
                exit(1, err: "runSubscribe error: \(e)")
        }
    }
}

func run(_ connection: NWConnection, _ args: StrArrSlice, stdin: String, windowId: UInt32?, workspace: String?) async -> ServerAnswer {
    if let e = await connection.writeAtomic(ClientRequest(args: args.toArray(), stdin: stdin, windowId: windowId, workspace: workspace)).error {
        exit(1, err: "Failed to write to server socket: \(e)")
    }

    switch await connection.readNonAtomic() {
        case .success(let answer):
            return (try? JSONDecoder().decode(ServerAnswer.self, from: answer)) ?? exitT(1, err: "Failed to parse server response: \(String(data: answer, encoding: .utf8).prettyDescription)")
        case .failure(let error):
            exit(1, err: "Failed to read from server socket: \(error)")
    }
}
