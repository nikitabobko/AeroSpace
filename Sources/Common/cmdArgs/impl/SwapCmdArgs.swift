public struct SwapCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .swap,
        allowInConfig: true,
        help: swap_help_generated,
        options: [
            "--swap-focus": trueBoolFlag(\.swapFocus),
            "--wrap-around": trueBoolFlag(\.wrapAround),
            "--window-id": optionalWindowIdFlag(),
        ],
        arguments: [newArgParser(\.target, parseCardinalOrDfsDirection, mandatoryArgPlaceholder: CardinalOrDfsDirection.unionLiteral)],
    )

    public var target: Lateinit<CardinalOrDfsDirection> = .uninitialized
    public var swapFocus: Bool = false
    public var wrapAround: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], target: CardinalOrDfsDirection) {
        self.rawArgs = .init(rawArgs)
        self.target = .initialized(target)
    }
}

public func parseSwapCmdArgs(_ args: [String]) -> ParsedCmd<SwapCmdArgs> {
    return parseSpecificCmdArgs(SwapCmdArgs(rawArgs: args), args)
}
