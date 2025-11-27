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
            eprint(usage)
            exit(1)
        }
        if args.first == "--help" || args.first == "-h" {
            print(usage)
            exit(0)
        }

        if args.first == "--version" || args.first == "-v" {
            let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)
            let serverVersion: String?
            if await connection.startBlocking() == nil {
                let ans = await run(connection, [], stdin: "", windowId: nil, workspace: nil)
                serverVersion = ans.serverVersionAndHash
            } else {
                serverVersion = nil
            }
            print(
                """
                aerospace CLI client version: \(cliClientVersionAndHash)
                AeroSpace.app server version: \(serverVersion ?? "Unknown. The server is not running")
                """,
            )
            exit(0)
        }

        var parsedArgs: (any CmdArgs)! = nil
        switch parseCmdArgs(args) {
            case .cmd(let _parsedArgs):
                parsedArgs = _parsedArgs
            case .help(let help):
                print(help)
                exit(0)
            case .failure(let e):
                exit(stderrMsg: e)
        }

        let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)

        if let e = await connection.startBlocking() {
            exit(stderrMsg: "Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.localizedDescription)")
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
                    stderrMsg: """
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
                    exit(stderrMsg: "stdin number of lines limit is exceeded")
                }
            }
        }

        let windowId = ProcessInfo.processInfo.environment[AEROSPACE_WINDOW_ID].flatMap(UInt32.init)
        let workspace = ProcessInfo.processInfo.environment[AEROSPACE_WORKSPACE]
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

func run(_ connection: NWConnection, _ args: StrArrSlice, stdin: String, windowId: UInt32?, workspace: String?) async -> ServerAnswer {
    let req = ClientRequest(args: args.toArray(), stdin: stdin, windowId: windowId, workspace: workspace)
    let requestData = Result { try JSONEncoder().encode(req) }.getOrDie()
    if let e = await connection.write(requestData) {
        exit(stderrMsg: "Failed to write to server socket: \(e)")
    }

    switch await connection.read() {
        case .success(let answer):
            return (try? JSONDecoder().decode(ServerAnswer.self, from: answer)) ?? exitT(stderrMsg: "Failed to parse server response")
        case .failure(let error):
            exit(stderrMsg: "Failed to read from server socket: \(error)")
    }
}
