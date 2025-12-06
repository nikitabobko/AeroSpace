import AppKit
import Common
import Network

func startUnixSocketServer() {
    try? FileManager.default.removeItem(atPath: socketPath)
    let params = NWParameters.tcp
    params.requiredLocalEndpoint = .unix(path: socketPath)
    let listener = Result { try NWListener(using: params) }.getOrDie()
    listener.newConnectionHandler = { connection in
        Task {
            defer { connection.cancel() }
            connection.start(queue: .global())
            await newConnection(connection)
        }
    }
    listener.start(queue: .global())
}

func toggleReleaseServerIfDebug(_ state: EnableCmdArgs.State) async {
    if serverArgs.isReadOnly { return }
    if !isDebug { return }
    let socketFile = "/tmp/\(stableAeroSpaceAppId)-\(unixUserName).sock"
    let connection = NWConnection(to: NWEndpoint.unix(path: socketFile), using: .tcp)
    defer { connection.cancel() }
    if await connection.startBlocking() != nil { // Can't connect, AeroSpace.app is not running
        return
    }

    let req = ClientRequest(args: ["enable", state.rawValue], stdin: "", windowId: nil, workspace: nil)
    _ = await connection.write(req)
    _ = await connection.read()
}

private let serverVersionAndHash = "\(aeroSpaceAppVersion) \(gitHash)"

private func newConnection(_ connection: NWConnection) async { // todo add exit codes
    func answerToClient(exitCode: Int32, stdout: String = "", stderr: String = "") async {
        let ans = ServerAnswer(exitCode: exitCode, stdout: stdout, stderr: stderr, serverVersionAndHash: serverVersionAndHash)
        await answerToClient(ans)
    }
    func answerToClient(_ ans: ServerAnswer) async {
        _ = await connection.write(ans)
    }
    while true {
        let (rawRequest, error) = await connection.read().getOrNils()
        if let error {
            await answerToClient(exitCode: 1, stderr: "Error: \(error)")
            return
        }
        guard let rawRequest else { die() }
        let _request = ClientRequest.decodeJson(rawRequest)
        guard let request: ClientRequest = _request.getOrNil() else {
            await answerToClient(
                exitCode: 1,
                stderr: """
                    Can't parse request '\(String(describing: String(data: rawRequest, encoding: .utf8)).singleQuoted)'.
                    Error: \(_request.failureOrNil.prettyDescription)
                    """,
            )
            continue
        }
        let (command, help, err) = parseCommand(request.args).unwrap()
        guard let token: RunSessionGuard = await .isServerEnabled(orIsEnableCommand: command) else {
            await answerToClient(
                exitCode: 1,
                stderr: "\(aeroSpaceAppName) server is disabled and doesn't accept commands. " +
                    "You can use 'aerospace enable on' to enable the server",
            )
            continue
        }
        if let help {
            await answerToClient(exitCode: 0, stdout: help)
            continue
        }
        if let err {
            await answerToClient(exitCode: 1, stderr: err)
            continue
        }
        if command?.isExec == true {
            await answerToClient(exitCode: 1, stderr: "exec-and-forget is prohibited in CLI")
            continue
        }
        if let command {
            let _answer: Result<ServerAnswer, Error> = await Result {
                try await runLightSession(.socketServer, token) { () throws in
                    let env = CmdEnv.init(
                        windowId: request.windowId.flatMap { $0 },
                        workspaceName: request.workspace.flatMap { $0 },
                    )
                    let cmdResult = try await command.run(env, CmdStdin(request.stdin))
                    return ServerAnswer(
                        exitCode: cmdResult.exitCode,
                        stdout: cmdResult.stdout.joined(separator: "\n"),
                        stderr: cmdResult.stderr.joined(separator: "\n"),
                        serverVersionAndHash: serverVersionAndHash,
                    )
                }
            }
            var answer = _answer.getOrNil() ??
                ServerAnswer(
                    exitCode: 1,
                    stderr: "Fail to await main thread. \(_answer.failureOrNil?.localizedDescription ?? "")",
                    serverVersionAndHash: serverVersionAndHash,
                )
            if request.windowId == nil || request.workspace == nil {
                answer.stderr += "\n\nAeroSpace client has sent incomplete JSON request. 'windowId' or/and 'workspace' fields are missing. Please forward your AEROSPACE_WINDOW_ID and AEROSPACE_WORKSPACE environment variables to these JSON fields. If the appropriate environment variables are empty, pass explict 'null' in the JSON."
            }
            await answerToClient(answer)
            continue
        }
        die("Unreachable")
    }
}
