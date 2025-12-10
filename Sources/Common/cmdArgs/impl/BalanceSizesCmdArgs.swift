public struct BalanceSizesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .balanceSizes,
        allowInConfig: true,
        help: balance_sizes_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )
}
