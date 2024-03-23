public struct JoinWithCmdArgs: CmdArgs, RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .joinWith,
        allowInConfig: true,
        help: """
              USAGE: join-with [-h|--help] \(CardinalDirection.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )
    public var direction: Lateinit<CardinalDirection> = .uninitialized

    internal init() {}

    public init(direction: CardinalDirection) {
        self.direction = .initialized(direction)
    }
}

public func parseJoinWithCmdArgs(_ args: [String]) -> ParsedCmd<JoinWithCmdArgs> {
    parseRawCmdArgs(JoinWithCmdArgs(), args)
}
