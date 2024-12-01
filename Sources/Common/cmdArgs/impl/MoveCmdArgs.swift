public struct MoveCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .move,
        allowInConfig: true,
        help: move_help_generated,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": optionalWindowIdFlag(),
        ],
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var failIfNoop: Bool = false

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = .initialized(direction)
    }
}

public func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseSpecificCmdArgs(MoveCmdArgs(rawArgs: args), args)
}
