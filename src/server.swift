import Socket
import Common

func startServer() {
    let socket = tryCatch { try Socket.create(family: .unix, type: .stream, proto: .unix) }
        .getOrThrow("Can't create socket ")
    let socketFile = "/tmp/\(Bundle.appId).sock"
    tryCatch { try socket.listen(on: socketFile) }.getOrThrow("Can't listen to socket \(socketFile) ")
    DispatchQueue.global().async {
        while true {
            guard let connection = try? socket.acceptClientConnection() else { continue }
            Task { await newConnection(connection) }
        }
    }
}

func sendCommandToReleaseServer(command: String) {
    check(isDebug)
    let socket = tryCatch { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrThrow()
    defer {
        socket.close()
    }
    let socketFile = "/tmp/bobko.aerospace.sock"
    if (try? socket.connect(to: socketFile)) == nil { // Can't connect, AeroSpace.app is not running
        return
    }

    _ = try? socket.write(from: command)
    _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
    _ = try? socket.readString()
}

private func newConnection(_ socket: Socket) async { // todo add exit codes
    func answerToClient(_ ans: ServerAnswer) {
        _ = try? socket.write(from: tryCatch { try JSONEncoder().encode(ans) }.getOrThrow())
    }
    defer {
        debug("Close connection")
        socket.close()
    }
    while true {
        _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
        guard let request: String = (try? socket.readString()) else { return }
        let separator: Swift.String.Index = request.firstIndex(of: "\n") ?? request.endIndex
        let rawCommand = String(request[..<separator])
        let stdin = String(request[request.indexOrPastTheEnd(after: separator)...])
        let (command, help, err) = parseCommand(rawCommand).unwrap()
        guard let isEnabled = await Task(operation: { @MainActor in TrayMenuModel.shared.isEnabled }).result.getOrNil() else {
            answerToClient(ServerAnswer(
                exitCode: 1,
                stdout: "",
                stderr: "Unknown failure during isEnabled server state access"
            ))
            continue
        }
        if !isEnabled && !isAllowedToRunWhenDisabled(command) {
            answerToClient(ServerAnswer(
                exitCode: 1,
                stdout: "",
                stderr: "\(Bundle.appName) server is disabled and doesn't accept commands. " +
                    "You can use 'aerospace enable on' to enable the server"
            ))
            continue
        }
        if let help {
            answerToClient(ServerAnswer(
                exitCode: 0,
                stdout: help,
                stderr: ""
            ))
            continue
        }
        if let err {
            answerToClient(ServerAnswer(
                exitCode: 1,
                stdout: "",
                stderr: err
            ))
            continue
        }
        if command?.isExec == true {
            answerToClient(ServerAnswer(
                exitCode: 1,
                stdout: "",
                stderr: "exec commands are prohibited in CLI"
            ))
            continue
        }
        if let command {
            let answer = await Task { @MainActor in
                refreshSession(forceFocus: true) {
                    let state: CommandMutableState = .focused // todo restore subject from "exec session"
                    let success = command.run(state, stdin: stdin)
                    return ServerAnswer(
                        exitCode: success ? 0 : 1,
                        stdout: state.stdout.joined(separator: "\n"),
                        stderr: state.stderr.joined(separator: "\n")
                    )
                }
            }.result.getOrNil() ?? ServerAnswer(
                exitCode: 1,
                stdout: "",
                stderr: "Fail to await main thread"
            )
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
