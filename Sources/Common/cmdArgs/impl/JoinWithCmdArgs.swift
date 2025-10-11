public struct JoinWithCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
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
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], direction: CardinalDirection) {
        self.rawArgsForStrRepr = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

public func parseJoinWithCmdArgs(_ args: StrArrSlice) -> ParsedCmd<JoinWithCmdArgs> {
    parseSpecificCmdArgs(JoinWithCmdArgs(rawArgs: args), args)
}
