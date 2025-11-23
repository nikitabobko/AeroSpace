import Foundation

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ServerAnswer: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
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
public struct ClientRequest: Codable, Sendable {
    public var command: String? = nil // Unused. keep it for API compatibility with old servers for a couple of version

    public let args: [String]
    public let stdin: String
    public let windowId: UInt32?  // Please forward AEROSPACE_WINDOW_ID env variable here
    public let workspace: String? // Please forward AEROSPACE_WORKSPACE env variable here

    public init(
        args: [String],
        stdin: String,
        windowId: UInt32?,
        workspace: String?,
    ) {
        self.args = args
        self.stdin = stdin
        self.windowId = windowId
        self.workspace = workspace
    }

    public static func decodeJson(_ data: Data) -> Result<ClientRequest, String> {
        Result { try JSONDecoder().decode(Self.self, from: data) }.mapError { $0.localizedDescription }
    }
}
