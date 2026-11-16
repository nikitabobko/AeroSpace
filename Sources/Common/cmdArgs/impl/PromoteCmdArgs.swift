public struct PromoteCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .promote,
        help: promote_help_generated,
        flags: [
            "--workspace": workspaceSubArgParser(),
        ],
        posArgs: [],
    )
}
