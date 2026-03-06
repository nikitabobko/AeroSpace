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
            connection.start(queue: .global())
            let shouldCancel = await newConnection(connection)
            if shouldCancel {
                connection.cancel()
            }
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

private func newConnection(_ connection: NWConnection) async -> Bool { // Returns true if connection should be cancelled
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
            return true
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
        // Handle subscribe before parseCommand (subscribe doesn't have a Command impl)
        if request.args.first == "subscribe" {
            switch parseSubscribeCmdArgs(request.args.slice(1...).orDie()) {
                case .cmd(let subscribeArgs):
                    await handleSubscribe(connection, subscribeArgs)
                    return false // Connection stays open, managed by subscription system
                case .help(let help):
                    await answerToClient(exitCode: 0, stdout: help)
                    continue
                case .failure(let err):
                    await answerToClient(exitCode: 1, stderr: err)
                    continue
            }
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

private func handleSubscribe(_ connection: NWConnection, _ args: SubscribeCmdArgs) async {
    let initialEvents = await MainActor.run { () -> [ServerEvent] in
        addSubscriber(connection, events: args.events)
        let f = focus
        var events: [ServerEvent] = []
        for eventType in args.events {
            switch eventType {
                case .focusChanged:
                    events.append(.focusChanged(
                        windowId: f.windowOrNil?.windowId,
                        workspace: f.workspace.name,
                        monitorId: f.workspace.workspaceMonitor.monitorId.map { $0 + 1 } ?? 0,
                    ))
                case .focusedMonitorChanged:
                    events.append(.focusedMonitorChanged(
                        workspace: f.workspace.name,
                        monitorId: f.workspace.workspaceMonitor.monitorId.map { $0 + 1 } ?? 0,
                    ))
                case .workspaceChanged:
                    events.append(.workspaceChanged(
                        workspace: f.workspace.name,
                        prevWorkspace: f.workspace.name,
                    ))
                case .modeChanged:
                    events.append(.modeChanged(mode: activeMode))
                case .windowDetected, .bindingTriggered:
                    break
            }
        }
        return events
    }
    for event in initialEvents {
        _ = await connection.write(event)
    }

    // Keep connection alive - wait for client to disconnect
    // The connection will be cleaned up when write fails in broadcastEvent
    while true {
        let result = await connection.read()
        if case .failure = result {
            await MainActor.run {
                removeSubscriber(connection)
            }
            connection.cancel()
            return
        }
        // Client sent unexpected data, ignore it
    }
}
