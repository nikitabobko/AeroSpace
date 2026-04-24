public struct DisableAutoRaiseCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .disableAutoRaise,
        allowInConfig: true,
        help: disable_auto_raise_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [],
    )
    public var failIfNoop: Bool = false
}
