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
    public var command: String? // Unused. keep it for API compatibility with old servers for a couple of version
    public let args: [String]
    public let stdin: String

    public init(
        args: [String],
        stdin: String,
    ) {
        if args.contains(where: { $0.rangeOfCharacter(from: .whitespacesAndNewlines) != nil || $0.contains("\"") || $0.contains("\'") }) {
            self.command = "" // Old server won't understand it anyway
        } else {
            self.command = args.joined(separator: " ")
        }
        self.args = args
        self.stdin = stdin
    }

    public static func decodeJson(_ data: Data) -> Result<ClientRequest, String> {
        Result { try JSONDecoder().decode(Self.self, from: data) }.mapError { $0.localizedDescription }
    }
}
