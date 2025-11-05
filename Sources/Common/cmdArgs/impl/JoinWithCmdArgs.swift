public struct JoinWithCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .joinWith,
        allowInConfig: true,
        help: join_with_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)],
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized

    public init(rawArgs: [String], direction: CardinalDirection) {
        self.commonState = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

public func parseJoinWithCmdArgs(_ args: StrArrSlice) -> ParsedCmd<JoinWithCmdArgs> {
    parseSpecificCmdArgs(JoinWithCmdArgs(rawArgs: args), args)
}
