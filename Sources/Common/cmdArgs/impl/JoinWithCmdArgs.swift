public struct JoinWithCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .joinWith,
        allowInConfig: true,
        help: """
            USAGE: join-with [-h|--help] \(CardinalDirection.unionLiteral)
            """,
        options: [:],
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = .initialized(direction)
    }
}

public func parseJoinWithCmdArgs(_ args: [String]) -> ParsedCmd<JoinWithCmdArgs> {
    parseSpecificCmdArgs(JoinWithCmdArgs(rawArgs: args), args)
}
