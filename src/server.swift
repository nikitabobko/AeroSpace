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

private func newConnection(_ socket: Socket) async {
    defer {
        debug("Close connection")
        socket.close()
    }
    while true {
        _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
        guard let string = (try? socket.readString()) else { return }
        let (action, error1) = parseSingleCommand(string).getOrNils()
        let (query, error2) = parseQueryCommand(string).getOrNils()
        if let error1, let error2 {
            _ = try? socket.write(from: error1 + "\n" + error2)
            continue
        }
        if action is ExecAndForgetCommand || action is ExecAndWaitCommand {
            _ = try? socket.write(from: "exec commands are prohibited from CLI")
            continue
        }
        if let action {
            await action.run()
            _ = try? socket.write(from: "PASS")
            continue
        }
        if let query {
            let result = await query.run()
            _ = try? socket.write(from: result)
            continue
        }
        error("Unreachable")
    }
}
