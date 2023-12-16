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
    _ = try? socket.readString()
}

private func newConnection(_ socket: Socket) async { // todo add exit codes
    defer {
        debug("Close connection")
        socket.close()
    }
    while true {
        _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
        guard let string = (try? socket.readString()) else { return }
        let command: Command?
        let err: String?
        let help: String?
        switch parseCommand(string) {
        case .cmd(let _command):
            command = _command
            help = nil
            err = nil
        case .help(let _help):
            command = nil
            help = _help
            err = nil
        case .failure(let _error):
            command = nil
            help = nil
            err = _error
        }
        guard let isEnabled = await Task(operation: { @MainActor in TrayMenuModel.shared.isEnabled }).result.getOrNil() else {
            _ = try? socket.write(from: "1Unknown failure during isEnabled server state access")
            continue
        }
        if !isEnabled && !isAllowedToRunWhenDisabled(command) {
            _ = try? socket.write(from: "1\(Bundle.appName) server is disabled and doesn't accept commands. " +
                "You can use 'aerospace enable on' to enable the server")
            continue
        }
        if let help {
            _ = try? socket.write(from: "0" + help + "\n")
            continue
        }
        if let err {
            _ = try? socket.write(from: "1" + err + "\n")
            continue
        }
        if command?.isExec == true {
            _ = try? socket.write(from: "1exec commands are prohibited in CLI")
            continue
        }
        if let command {
            let (success, stdout) = await Task { @MainActor in
                refreshSession {
                    var focused = CommandSubject.focused // todo restore subject from "exec session"
                    var stdout = ""
                    let success = command.run(&focused, &stdout)
                    return (success, stdout)
                }
            }.result.getOrNil() ?? (false, "Fail to await main thread")
            let msg = (success ? "0" : "1") + stdout
            _ = try? socket.write(from: msg)
            continue
        }
        error("Unreachable")
    }
}

private func isAllowedToRunWhenDisabled(_ command: Command?) -> Bool {
    if let enable = command as? EnableCommand, enable.args.targetState != .off {
        return true
    }
    if command is VersionCommand {
        return true
    }
    return false
}
