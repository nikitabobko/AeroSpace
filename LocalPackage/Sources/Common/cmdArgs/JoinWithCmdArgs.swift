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
        arguments: [ArgParser(\.direction, parseCardinalDirectionArg, argPlaceholderIfMandatory: CardinalDirection.unionLiteral)]
    )
    @Lateinit public var direction: CardinalDirection

    fileprivate init() {}

    public init(direction: CardinalDirection) {
        self.direction = direction
    }
}

public func parseJoinWithCmdArgs(_ args: [String]) -> ParsedCmd<JoinWithCmdArgs> {
    parseRawCmdArgs(JoinWithCmdArgs(), args)
}
