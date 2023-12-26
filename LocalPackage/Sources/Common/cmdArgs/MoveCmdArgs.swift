public struct MoveCmdArgs: CmdArgs, RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .move,
        allowInConfig: true,
        help: """
              USAGE: move [-h|--help] \(CardinalDirection.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [ArgParser(\.direction, parseCardinalDirectionArg, argPlaceholderIfMandatory: CardinalDirection.unionLiteral)]
    )
    @Lateinit public var direction: CardinalDirection

    fileprivate init() {}

    public init(_ direction: CardinalDirection) {
        self.direction = direction
    }
}

public func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseRawCmdArgs(MoveCmdArgs(), args)
}
