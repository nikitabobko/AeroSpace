import Socket
import Common

func startServer() {
    let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }
        .getOrThrow("Can't create socket ")
    let socketFile = "/tmp/\(Bundle.appId).sock"
    Result { try socket.listen(on: socketFile) }.getOrThrow("Can't listen to socket \(socketFile) ")
    DispatchQueue.global().async {
        while true {
            guard let connection = try? socket.acceptClientConnection() else { continue }
            Task { await newConnection(connection) }
        }
    }
}

func sendCommandToReleaseServer(command: String) {
    check(isDebug)
    let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrThrow()
    defer {
        socket.close()
    }
    let socketFile = "/tmp/bobko.aerospace.sock"
    if (try? socket.connect(to: socketFile)) == nil { // Can't connect, AeroSpace.app is not running
        return
    }

    _ = try? socket.write(from: Result { try JSONEncoder().encode(ClientRequest(command: command, stdin: "")) }.getOrThrow())
    _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
    _ = try? socket.readString()
}

private func newConnection(_ socket: Socket) async { // todo add exit codes
    func answerToClient(_ ans: ServerAnswer) {
        _ = try? socket.write(from: Result { try JSONEncoder().encode(ans) }.getOrThrow())
    }
    defer {
        debug("Close connection")
        socket.close()
    }
    while true {
        _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
        var rawRequest = Data()
        if (try? socket.read(into: &rawRequest)) ?? 0 == 0 {
            answerToClient(ServerAnswer(exitCode: 1, stderr: "Empty request"))
            return
        }
        let _request = tryCatch(body: { try JSONDecoder().decode(ClientRequest.self, from: rawRequest) })
        guard let request: ClientRequest = _request.getOrNil() else {
            answerToClient(ServerAnswer(
                exitCode: 1,
                stderr: """
                        Can't parse request '\(String(describing: String(data: rawRequest, encoding: .utf8)))'.
                        Error: \(String(describing: _request.errorOrNil))
                        """
            ))
            continue
        }
        let (command, help, err) = parseCommand(request.command).unwrap()
        guard let isEnabled = await Task(operation: { @MainActor in TrayMenuModel.shared.isEnabled }).result.getOrNil() else {
            answerToClient(ServerAnswer(exitCode: 1, stderr: "Unknown failure during isEnabled server state access"))
            continue
        }
        if !isEnabled && !isAllowedToRunWhenDisabled(command) {
            answerToClient(ServerAnswer(
                exitCode: 1,
                stderr: "\(Bundle.appName) server is disabled and doesn't accept commands. " +
                    "You can use 'aerospace enable on' to enable the server"
            ))
            continue
        }
        if let help {
            answerToClient(ServerAnswer(exitCode: 0, stdout: help))
            continue
        }
        if let err {
            answerToClient(ServerAnswer(exitCode: 1, stderr: err))
            continue
        }
        if command?.isExec == true {
            answerToClient(ServerAnswer(exitCode: 1, stderr: "exec commands are prohibited in CLI"))
            continue
        }
        if let command {
            let answer = await Task { @MainActor in
                refreshSession(forceFocus: true) {
                    let state: CommandMutableState = .focused // todo restore subject from "exec session"
                    let success = command.run(state, stdin: request.stdin)
                    return ServerAnswer(
                        exitCode: success ? 0 : 1,
                        stdout: state.stdout.joined(separator: "\n"),
                        stderr: state.stderr.joined(separator: "\n")
                    )
                }
            }.result.getOrNil() ?? ServerAnswer(exitCode: 1, stderr: "Fail to await main thread")
            answerToClient(answer)
            continue
        }
        error("Unreachable")
    }
}

func isAllowedToRunWhenDisabled(_ command: (any Command)?) -> Bool {
    if let enable = command as? EnableCommand, enable.args.targetState.val != .off {
        return true
    }
    if command is ServerVersionInternalCommandCommand {
        return true
    }
    return false
}
