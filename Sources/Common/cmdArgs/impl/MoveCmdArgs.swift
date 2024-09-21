public struct MoveCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .move,
        allowInConfig: true,
        help: """
            USAGE: move [-h|--help] \(CardinalDirection.unionLiteral)

            OPTIONS:
              -h, --help   Print help
            """,
        options: [:],
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: String?

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = .initialized(direction)
    }
}

public func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseSpecificCmdArgs(MoveCmdArgs(rawArgs: args), args)
}
