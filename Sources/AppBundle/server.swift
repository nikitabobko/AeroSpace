import AppKit
import Common
@preconcurrency import Socket

func startUnixSocketServer() {
    DispatchQueue.global().async {
        let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }
            .getOrDie("Can't create socket ")
        let socketFile = "/tmp/\(aeroSpaceAppId)-\(unixUserName).sock"
        Result { try socket.listen(on: socketFile) }.getOrDie("Can't listen to socket \(socketFile) ")
        while true {
            guard let connection = try? socket.acceptClientConnection() else { continue }
            handleConnectionAsync(connection)
        }
    }
}

// Circumvent error https://github.com/swiftlang/swift/issues/80234:
//     Value of non-Sendable type '@isolated(any) @async @callee_guaranteed @substituted <τ_0_0> () -> @out τ_0_0 for <()>' accessed after being transferred; later accesses could race
private func handleConnectionAsync(_ connection: sending Socket) {
    Task { await newConnection(connection) }
}

func toggleReleaseServerIfDebug(_ state: EnableCmdArgs.State) {
    if serverArgs.isReadOnly { return }
    if !isDebug { return }
    let socket = Result { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrDie()
    defer {
        socket.close()
    }
    let socketFile = "/tmp/bobko.aerospace-\(unixUserName).sock"
    if (try? socket.connect(to: socketFile)) == nil { // Can't connect, AeroSpace.app is not running
        return
    }

    _ = try? socket.write(from: Result { try JSONEncoder().encode(ClientRequest(args: ["enable", state.rawValue], stdin: "")) }.getOrDie())
    _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
    _ = try? socket.readString()
}

private let serverVersionAndHash = "\(aeroSpaceAppVersion) \(gitHash)"

private func newConnection(_ socket: Socket) async { // todo add exit codes
    func answerToClient(exitCode: Int32, stdout: String = "", stderr: String = "") {
        let ans = ServerAnswer(exitCode: exitCode, stdout: stdout, stderr: stderr, serverVersionAndHash: serverVersionAndHash)
        answerToClient(ans)
    }
    func answerToClient(_ ans: ServerAnswer) {
        _ = try? socket.write(from: Result { try JSONEncoder().encode(ans) }.getOrDie())
    }
    defer {
        socket.close()
    }
    while true {
        _ = try? Socket.wait(for: [socket], timeout: 0, waitForever: true)
        var rawRequest = Data()
        if (try? socket.read(into: &rawRequest)) ?? 0 == 0 {
            answerToClient(exitCode: 1, stderr: "Empty request")
            return
        }
        let _request = ClientRequest.decodeJson(rawRequest)
        guard let request: ClientRequest = _request.getOrNil() else {
            answerToClient(
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
            answerToClient(
                exitCode: 1,
                stderr: "\(aeroSpaceAppName) server is disabled and doesn't accept commands. " +
                    "You can use 'aerospace enable on' to enable the server",
            )
            continue
        }
        if let help {
            answerToClient(exitCode: 0, stdout: help)
            continue
        }
        if let err {
            answerToClient(exitCode: 1, stderr: err)
            continue
        }
        if command?.isExec == true {
            answerToClient(exitCode: 1, stderr: "exec-and-forget is prohibited in CLI")
            continue
        }
        if let command {
            let _answer: Result<ServerAnswer, Error> = await Task { @MainActor in
                try await runSession(.socketServer, token) { () throws in
                    let cmdResult = try await command.run(.defaultEnv, CmdStdin(request.stdin)) // todo pass AEROSPACE_ env vars from CLI instead of defaultEnv
                    return ServerAnswer(
                        exitCode: cmdResult.exitCode,
                        stdout: cmdResult.stdout.joined(separator: "\n"),
                        stderr: cmdResult.stderr.joined(separator: "\n"),
                        serverVersionAndHash: serverVersionAndHash,
                    )
                }
            }.result
            let answer = _answer.getOrNil() ??
                ServerAnswer(
                    exitCode: 1,
                    stderr: "Fail to await main thread. \(_answer.failureOrNil?.localizedDescription ?? "")",
                    serverVersionAndHash: serverVersionAndHash,
                )
            answerToClient(answer)
            continue
        }
        die("Unreachable")
    }
}
