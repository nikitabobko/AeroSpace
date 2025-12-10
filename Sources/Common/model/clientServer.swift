import Foundation

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ServerAnswer: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public var stderr: String
    public let serverVersionAndHash: String

    public init(
        exitCode: Int32,
        stdout: String = "",
        stderr: String = "",
        serverVersionAndHash: String,
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.serverVersionAndHash = serverVersionAndHash
    }
}

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ClientRequest: Codable, Sendable, ConvenienceCopyable, Equatable {
    public var command: String? = nil // Unused. keep it for API compatibility with old servers for a couple of version

    public let args: [String]
    public let stdin: String

    // Double Optional to encode explicit null into JSON
    public var windowId: UInt32??  // Please forward AEROSPACE_WINDOW_ID env variable here
    public var workspace: String?? // Please forward AEROSPACE_WORKSPACE env variable here

    public init(
        args: [String],
        stdin: String,
        windowId: UInt32?,
        workspace: String?,
    ) {
        self.args = args
        self.stdin = stdin
        self.windowId = .some(windowId)
        self.workspace = .some(workspace)
    }

    public static func decodeJson(_ data: Data) -> Result<ClientRequest, String> {
        Result { try JSONDecoder().decode(Self.self, from: data) }.mapError { $0.localizedDescription }
    }

    enum CodingKeys: String, CodingKey {
        case args
        case stdin
        case windowId
        case workspace
    }

    public init(from decoder: any Decoder) throws {
        let data = try ClientRequestData.init(from: decoder)
        var raw = ClientRequest(
            args: data.args,
            stdin: data.stdin,
            windowId: data.windowId.flatMap { $0 },
            workspace: data.workspace.flatMap { $0 },
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if !container.contains(.windowId) { raw.windowId = nil }
        if !container.contains(.workspace) { raw.workspace = nil }
        self = raw
    }
}

private struct ClientRequestData: Codable, Sendable {
    public var args: [String]
    public var stdin: String
    public var windowId: UInt32??
    public var workspace: String??
}
