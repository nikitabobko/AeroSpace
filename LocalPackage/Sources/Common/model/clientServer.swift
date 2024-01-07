import Foundation

public struct ServerAnswer: Codable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(
        exitCode: Int32,
        stdout: String = "",
        stderr: String = ""
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct ClientRequest: Codable {
    public let command: String
    public let stdin: String

    public init(
        command: String,
        stdin: String
    ) {
        self.command = command
        self.stdin = stdin
    }
}
