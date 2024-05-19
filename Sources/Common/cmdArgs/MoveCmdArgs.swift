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
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )
    public var direction: Lateinit<CardinalDirection> = .uninitialized

    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = .initialized(direction)
    }
}

public func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseRawCmdArgs(MoveCmdArgs(rawArgs: args), args)
}
