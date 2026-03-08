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
    if await connection.startBlocking().error != nil { // Can't connect, AeroSpace.app is not running
        return
    }

    let req = ClientRequest(args: ["enable", state.rawValue], stdin: "", windowId: nil, workspace: nil)
    _ = await connection.writeAtomic(req)
    _ = await connection.readNonAtomic()
}

private let serverVersionAndHash = "\(aeroSpaceAppVersion) \(gitHash)"

private func newConnection(_ connection: NWConnection) async { // todo add exit codes
    func answerToClient(exitCode: Int32, stdout: String = "", stderr: String = "") async {
        let ans = ServerAnswer(exitCode: exitCode, stdout: stdout, stderr: stderr, serverVersionAndHash: serverVersionAndHash)
        await answerToClient(ans)
    }
    func answerToClient(_ ans: ServerAnswer) async {
        _ = await connection.writeAtomic(ans)
    }
    while true {
        let rawRequest: Data
        switch await connection.readNonAtomic() {
            case .success(let _rawRequest): rawRequest = _rawRequest
            case .failure(let error):
                await answerToClient(exitCode: 1, stderr: "Error: \(error)")
                return
        }
        let request: ClientRequest
        switch ClientRequest.decodeJson(rawRequest) {
            case .success(let _request): request = _request
            case .failure(let error):
                await answerToClient(
                    exitCode: 1,
                    stderr: """
                        Can't parse request '\(String(describing: String(data: rawRequest, encoding: .utf8)).singleQuoted)'.
                        Error: \(error)
                        """,
                )
                continue
        }
        // Handle subscribe before parseCommand (subscribe doesn't have a Command impl)
        if request.args.first == "subscribe" {
            switch parseSubscribeCmdArgs(request.args.slice(1...).orDie()) {
                case .cmd(let subscribeArgs): await handleSubscribeAndWaitTillError(connection, subscribeArgs)
                case .help(let help): await answerToClient(exitCode: 0, stdout: help)
                case .failure(let err): await answerToClient(exitCode: 1, stderr: err)
            }
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
                try await runLightSession(.socketServer(command.args), token) { () throws in
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
