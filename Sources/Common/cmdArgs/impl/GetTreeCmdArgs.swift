public struct GetTreeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .getTree,
        help: get_tree_help_generated,
        flags: [:],
        posArgs: [],
    )
}
