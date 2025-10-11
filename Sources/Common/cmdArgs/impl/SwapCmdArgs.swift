public struct SwapCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .swap,
        allowInConfig: true,
        help: swap_help_generated,
        flags: [
            "--swap-focus": trueBoolFlag(\.swapFocus),
            "--wrap-around": trueBoolFlag(\.wrapAround),
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [newArgParser(\.target, parseCardinalOrDfsDirection, mandatoryArgPlaceholder: CardinalOrDfsDirection.unionLiteral)],
    )

    public var target: Lateinit<CardinalOrDfsDirection> = .uninitialized
    public var swapFocus: Bool = false
    public var wrapAround: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], target: CardinalOrDfsDirection) {
        self.rawArgsForStrRepr = .init(rawArgs.slice)
        self.target = .initialized(target)
    }
}

public func parseSwapCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SwapCmdArgs> {
    return parseSpecificCmdArgs(SwapCmdArgs(rawArgs: args), args)
}
