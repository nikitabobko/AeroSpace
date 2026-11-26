@testable import AppBundle
import Foundation
import Network
import Testing

@MainActor private func socketTestConnect(_ path: String) async throws -> NWConnection {
    let connection = NWConnection(to: .unix(path: path), using: .tcp)
    connection.start(queue: .main)
    for _ in 0 ..< 100 {
        if case .ready = connection.state { return connection }
        if case .failed(let error) = connection.state { connection.cancel(); throw error }
        try await Task.sleep(for: .milliseconds(20))
    }
    connection.cancel()
    throw CocoaError(.fileReadUnknown)
}

private func socketTestEcho(_ connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, _, _, error in
        guard let data, error == nil else { connection.cancel(); return }
        connection.send(content: data, completion: .contentProcessed { error in
            if error == nil { socketTestEcho(connection) } else { connection.cancel() }
        })
    }
}

private func socketTestExchange(_ connection: NWConnection, byte: UInt8) async throws {
    let timeout = DispatchWorkItem { connection.cancel() }
    DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeout)
    defer { timeout.cancel() }
    connection.send(content: Data([byte]), completion: .idempotent)
    let data: Data? = await withCheckedContinuation { continuation in
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, _, _, _ in
            continuation.resume(returning: data)
        }
    }
    #expect(data == Data([byte]))
}

@MainActor
@Suite(.serializedGlobally)
struct UnixSocketServerTest {
    @Test(.timeLimit(.minutes(1))) func testDeletedSocketRebindsWithoutLosingExistingConnections() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("as-" + UUID().uuidString.prefix(16))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("ipc.sock").path
        let server = RecoveringUnixSocketServer(path: path) { connection in
            connection.start(queue: .global())
            socketTestEcho(connection)
        }
        try server.start()
        defer { server.stop(); try? FileManager.default.removeItem(at: directory) }
        let held = try await socketTestConnect(path)
        defer { held.cancel() }
        try await socketTestExchange(held, byte: 1)
        for round in 2 ... 5 {
            try FileManager.default.removeItem(atPath: path)
            for _ in 0 ..< 100 {
                if FileManager.default.fileExists(atPath: path) { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            let fresh = try await socketTestConnect(path)
            try await socketTestExchange(fresh, byte: UInt8(round))
            fresh.cancel()
            try await socketTestExchange(held, byte: UInt8(round + 10))
        }
        try FileManager.default.moveItem(atPath: path, toPath: path + ".moved")
        for _ in 0 ..< 100 {
            if FileManager.default.fileExists(atPath: path) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let renamed = try await socketTestConnect(path)
        try await socketTestExchange(renamed, byte: 20)
        renamed.cancel()
        try FileManager.default.removeItem(atPath: path)
        try Data("preserve".utf8).write(to: URL(fileURLWithPath: path))
        try await Task.sleep(for: .milliseconds(250))
        let preserved = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(preserved == Data("preserve".utf8))
        try FileManager.default.removeItem(atPath: path)
        try await Task.sleep(for: .milliseconds(250))
        let resumed = try await socketTestConnect(path)
        try await socketTestExchange(resumed, byte: 30)
        resumed.cancel()
        server.stop()
        try await Task.sleep(for: .milliseconds(200))
        #expect(!FileManager.default.fileExists(atPath: path))
    }
}
