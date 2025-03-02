import Foundation

public struct ServerAnswer: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let serverVersionAndHash: String

    public init(
        exitCode: Int32,
        stdout: String = "",
        stderr: String = "",
        serverVersionAndHash: String
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.serverVersionAndHash = serverVersionAndHash
    }
}

public struct ClientRequest: Codable, Sendable {
    public let command: String // Unused. keep it for API compatibility with old servers for a couple of version
    public let args: [String]
    public let stdin: String

    public init(
        args: [String],
        stdin: String
    ) {
        if args.contains(where: { $0.rangeOfCharacter(from: .whitespacesAndNewlines) != nil || $0.contains("\"") || $0.contains("\'") }) {
            self.command = "" // Old server won't understand it anyway
        } else {
            self.command = args.joined(separator: " ")
        }
        self.args = args
        self.stdin = stdin
    }
}
