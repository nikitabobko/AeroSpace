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
        ],
        arguments: [newArgParser(\.target, parseFocusTargetArg, mandatoryArgPlaceholder: "(left|down|up|right|dfs-next|dfs-prev)")]
    )

    public var target: Lateinit<FocusTargetArg> = .uninitialized
    public var swapFocus: Bool = false
    public var wrapAround: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], target: FocusTargetArg) {
        self.rawArgs = .init(rawArgs)
        self.target = .initialized(target)
    }
}

public func parseSwapCmdArgs(_ args: [String]) -> ParsedCmd<SwapCmdArgs> {
    return parseSpecificCmdArgs(SwapCmdArgs(rawArgs: args), args)
}
