public struct ListTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .listTree,
        allowInConfig: false,
        help: list_tree_help_generated,
        flags: [:],
        posArgs: [],
    )
}
