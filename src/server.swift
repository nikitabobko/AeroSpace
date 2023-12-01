import Socket

func startServer() {
    let socket = (try? Socket.create(family: .unix, type: .stream, proto: .unix)) ?? errorT("Can't create socket")
    let socketFile = "/tmp/\(Bundle.appId).sock"
    (try? socket.listen(on: socketFile, maxBacklogSize: 1)) ?? errorT("Can't listen to socket \(socketFile)")
    DispatchQueue.global().async {
        while true {
            guard let connection = try? socket.acceptClientConnection() else { continue }
            Task { await newConnection(connection) }
        }
    }
}

func sendCommandToReleaseServer(command: String) {
    check(isDebug)
    let socket = try! Socket.create(family: .unix, type: .stream, proto: .unix)
    defer {
        socket.close()
    }
    let socketFile = "/tmp/bobko.aerospace.sock"
    if (try? socket.connect(to: socketFile)) == nil { // Can't connect, AeroSpace.app is not running
        return
    }

    _ = try? socket.write(from: command)
    _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
}

private func newConnection(_ socket: Socket) async { // todo add exit codes
    defer {
        debug("Close connection")
        socket.close()
    }
    while true {
        _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
        guard let string = (try? socket.readString()) else { return }
        let (action, error1) = parseCommand(string).getOrNils()
        let (query, error2) = parseQueryCommand(string).getOrNils()
        guard let isEnabled = await Task(operation: { @MainActor in TrayMenuModel.shared.isEnabled }).result.getOrNil() else {
            _ = try? socket.write(from: "Unknown failure during isEnabled server state access")
            continue
        }
        if !isEnabled && !isAllowedToRunWhenDisabled(query, action) {
            _ = try? socket.write(from: "\(Bundle.appName) server is disabled and doesn't accept commands. " +
                "You can use 'aerospace enable on' to enable the server")
            continue
        }
        if let error1, let error2 {
            _ = try? socket.write(from: error1 + "\n" + error2)
            continue
        }
        if action?.isExec == true {
            _ = try? socket.write(from: "exec commands are prohibited in CLI")
            continue
        }
        if let action {
            _ = await Task { @MainActor in
                refreshSession {
                    var focused = CommandSubject.focused // todo restore subject from "exec session"
                    action.run(&focused)
                }
            }.result
            _ = try? socket.write(from: "PASS")
            continue
        }
        if let query {
            await Task { @MainActor in
                refreshSession {
                    let result = query.run()
                    _ = try? socket.write(from: result)
                }
            }.result
            continue
        }
        error("Unreachable")
    }
}

private func isAllowedToRunWhenDisabled(_ query: QueryCommand?, _ action: Command?) -> Bool {
    if let enable = action as? EnableCommand, enable.targetState != .off {
        return true
    }
    if query is VersionCommand {
        return true
    }
    return false
}
