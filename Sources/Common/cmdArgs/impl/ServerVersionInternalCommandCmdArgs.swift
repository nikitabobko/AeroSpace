public struct ServerVersionInternalCommandCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .serverVersionInternalCommand,
        allowInConfig: false,
        help: """
            USAGE: server-version-internal-command [-h|--help]
            """,
        options: [:],
        arguments: []
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
